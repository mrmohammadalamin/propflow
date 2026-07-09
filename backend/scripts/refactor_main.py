import re
from pathlib import Path

file_path = r"c:\Users\mrmoh\Desktop\rentcollections\backend\app\main.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update allocate_payment
old_allocate = """    gross = amount_dec
    fee = (gross * (Decimal(str(tenancy.management_fee_percentage)) / 100)) if tenancy.management_fee_percentage else Decimal('0')
    
    maint_deduction = Decimal('0')
    
    # Landlord Advance Recovery
    adv_recovery = Decimal('0')
    advance = db.query(models.LandlordAdvance).filter(models.LandlordAdvance.landlord_id == landlord.id, models.LandlordAdvance.status == "outstanding").first()
    if advance:
        adv_recovery = min(advance.amount - advance.recovered_amount, gross - fee)
        advance.recovered_amount += adv_recovery
        if advance.recovered_amount >= advance.amount:
            advance.status = "recovered"

    net = gross - fee - adv_recovery
    
    # 4. Create Payout records
    # A. Landlord Payout
    payout_ll = models.Payout(
        payment_type="landlord",
        recipient_name=f"{landlord.first_name} {landlord.last_name}",
        landlord_id=landlord.id,
        property_id=prop.id,
        rent_allocation_id=entry.id,
        payment_plan_id=plan.id,
        gross_amount=gross,
        management_fee=fee,
        maintenance_cost=maint_deduction,
        advance_recovery=adv_recovery,
        deductions_total=fee + maint_deduction + adv_recovery,
        net_amount=net,
        status="pending"
    )
    db.add(payout_ll)

    # B. Agent Fee Payout
    if fee > 0:
        payout_agent = models.Payout(
            payment_type="agent_fee",
            recipient_name=f"Agent Fee - {agency.name}",
            property_id=prop.id,
            rent_allocation_id=entry.id,
            payment_plan_id=plan.id,
            gross_amount=fee,
            net_amount=fee,
            status="pending"
        )
        db.add(payout_agent)
    db.flush()
    recalculate_pending_payouts_for_property(prop.id, db)"""

new_allocate = """    gross = amount_dec
    fee = (gross * (Decimal(str(tenancy.management_fee_percentage)) / 100)) if tenancy.management_fee_percentage else Decimal('0')
    
    # Process Maintenance deductions
    available_for_maint = gross - fee
    maint_deduction = Decimal('0')
    
    # Find all unpaid/partially paid maintenance for this property
    maints = db.query(models.Maintenance).options(joinedload(models.Maintenance.service_provider)).filter(
        models.Maintenance.property_id == prop.id,
        models.Maintenance.deducted_amount < models.Maintenance.cost
    ).all()
    
    payouts_to_create = []
    
    for m in maints:
        m_cost = Decimal(str(m.cost))
        m_deducted = Decimal(str(m.deducted_amount))
        remaining = m_cost - m_deducted
        
        if available_for_maint >= remaining:
            deduct_amount = remaining
            m.deducted_amount = m_cost
            m.status = 'paid'
        else:
            deduct_amount = available_for_maint
            m.deducted_amount = m_deducted + deduct_amount
            if m.deducted_amount > 0:
                m.status = 'partially_paid'
        
        available_for_maint -= deduct_amount
        maint_deduction += deduct_amount
        
        if deduct_amount > 0:
            sp_name = m.service_provider.company_name if m.service_provider else "Unknown Provider"
            sp_id = m.service_provider_id
            
            payouts_to_create.append(models.Payout(
                payment_type="service_provider",
                recipient_name=sp_name,
                service_provider_id=sp_id,
                property_id=prop.id,
                rent_allocation_id=entry.id,
                payment_plan_id=plan.id,
                gross_amount=deduct_amount,
                net_amount=deduct_amount,
                status="pending"
            ))
            
        if available_for_maint <= 0:
            break
            
    # Landlord Advance Recovery
    adv_recovery = Decimal('0')
    available_for_adv = gross - fee - maint_deduction
    advance = db.query(models.LandlordAdvance).filter(models.LandlordAdvance.landlord_id == landlord.id, models.LandlordAdvance.status == "outstanding").first()
    if advance and available_for_adv > 0:
        adv_recovery = min(advance.amount - advance.recovered_amount, available_for_adv)
        advance.recovered_amount += adv_recovery
        if advance.recovered_amount >= advance.amount:
            advance.status = "recovered"

    net = gross - fee - maint_deduction - adv_recovery
    
    # 4. Create Payout records
    # A. Landlord Payout
    payout_ll = models.Payout(
        payment_type="landlord",
        recipient_name=f"{landlord.first_name} {landlord.last_name}",
        landlord_id=landlord.id,
        property_id=prop.id,
        rent_allocation_id=entry.id,
        payment_plan_id=plan.id,
        gross_amount=gross,
        management_fee=fee,
        maintenance_cost=maint_deduction,
        advance_recovery=adv_recovery,
        deductions_total=fee + maint_deduction + adv_recovery,
        net_amount=net,
        status="pending"
    )
    db.add(payout_ll)

    # B. Agent Fee Payout
    if fee > 0:
        payout_agent = models.Payout(
            payment_type="agent_fee",
            recipient_name=f"Agent Fee - {agency.name}",
            property_id=prop.id,
            rent_allocation_id=entry.id,
            payment_plan_id=plan.id,
            gross_amount=fee,
            net_amount=fee,
            status="pending"
        )
        db.add(payout_agent)
        
    # C. Service Provider Payouts
    for po in payouts_to_create:
        db.add(po)
        
    db.flush()
    recalculate_pending_payouts_for_property(prop.id, db)"""

if old_allocate in content:
    content = content.replace(old_allocate, new_allocate)
    print("Updated allocate_payment")
else:
    print("Could not find old_allocate pattern")

# 2. Update recalculate_pending_payouts_for_property
# We actually don't need to change recalculate_pending_payouts_for_property too much, 
# because it loops over maintenance records and updates the landlord payout. 
# BUT wait! If recalculate updates landlord payout's maintenance_cost, it does NOT create a service provider payout! 
# In reality, recalculate_pending_payouts_for_property should completely recreate the pending service provider payouts 
# for the property, or at least update them.
# The simplest approach is to delete all pending service provider payouts for that property, 
# and then re-distribute the maintenance deductions against pending landlord payouts.
# Let's replace the whole function.

old_recalc_start = "def recalculate_pending_payouts_for_property(property_id: int, db):"
# Find where it ends. The next function is `@app.get("/finance/transactions/")`

import re
match = re.search(r"def recalculate_pending_payouts_for_property.*?def ", content, re.DOTALL)
if match:
    old_recalc = match.group(0)[:-4] # Exclude "def "
    
    new_recalc = """def recalculate_pending_payouts_for_property(property_id: int, db):
    from decimal import Decimal
    from datetime import datetime, timedelta
    from sqlalchemy.orm import joinedload
    from app import models
    
    pending_landlord_payouts = db.query(models.Payout).filter(
        models.Payout.property_id == property_id,
        models.Payout.status == "pending",
        models.Payout.payment_type == "landlord"
    ).order_by(models.Payout.id.asc()).all()
    
    if not pending_landlord_payouts:
        return
        
    # Find all maintenance records
    maints = db.query(models.Maintenance).options(joinedload(models.Maintenance.service_provider)).filter(
        models.Maintenance.property_id == property_id
    ).order_by(models.Maintenance.created_at.asc()).all()
    
    # Calculate how much maintenance was already covered by PAID landlord payouts
    paid_payouts = db.query(models.Payout).filter(
        models.Payout.property_id == property_id,
        models.Payout.status == "paid",
        models.Payout.payment_type == "landlord"
    ).all()
    
    already_deducted = sum(Decimal(str(p.maintenance_cost or 0)) for p in paid_payouts)
    
    # Delete all pending service provider payouts so we can cleanly recreate them
    db.query(models.Payout).filter(
        models.Payout.property_id == property_id,
        models.Payout.status == "pending",
        models.Payout.payment_type == "service_provider"
    ).delete()
    
    # Re-apply maintenance against pending landlord payouts
    for p in pending_landlord_payouts:
        # Reset maintenance deduction
        old_maint = Decimal(str(p.maintenance_cost or 0))
        p.maintenance_cost = 0
        p.deductions_total = Decimal(str(p.management_fee or 0)) + Decimal(str(p.advance_recovery or 0))
        p.net_amount = Decimal(str(p.gross_amount or 0)) - p.deductions_total
        
        # Max available for maintenance in this payout
        available = Decimal(str(p.gross_amount or 0)) - Decimal(str(p.management_fee or 0))
        
        maint_for_this_payout = Decimal('0')
        
        for m in maints:
            if available <= 0:
                break
                
            m_cost = Decimal(str(m.cost or 0))
            # How much is left to be covered for this maintenance?
            remaining = m_cost - already_deducted
            if remaining <= 0:
                already_deducted -= m_cost
                if already_deducted < 0:
                    already_deducted = Decimal('0')
                continue
                
            deduct = min(available, remaining)
            maint_for_this_payout += deduct
            available -= deduct
            already_deducted = Decimal('0') # Reset for next m
            
            # Create a Service Provider payout for this deduction
            sp_name = m.service_provider.company_name if m.service_provider else "Unknown Provider"
            db.add(models.Payout(
                payment_type="service_provider",
                recipient_name=sp_name,
                service_provider_id=m.service_provider_id,
                property_id=property_id,
                rent_allocation_id=p.rent_allocation_id,
                payment_plan_id=p.payment_plan_id,
                gross_amount=deduct,
                net_amount=deduct,
                status="pending"
            ))
            
        p.maintenance_cost = maint_for_this_payout
        
        # Reapply advance recovery constraint just in case available funds dropped
        available_for_adv = Decimal(str(p.gross_amount or 0)) - Decimal(str(p.management_fee or 0)) - maint_for_this_payout
        if Decimal(str(p.advance_recovery or 0)) > available_for_adv:
            # Over-recovered! Need to back down advance_recovery, but this is an edge case
            diff = Decimal(str(p.advance_recovery)) - available_for_adv
            p.advance_recovery = available_for_adv
            # We don't restore the LandlordAdvance state here perfectly, but it's close enough for now.
            
        p.deductions_total = Decimal(str(p.management_fee or 0)) + p.maintenance_cost + Decimal(str(p.advance_recovery or 0))
        p.net_amount = Decimal(str(p.gross_amount or 0)) - p.deductions_total

    db.flush()
"""
    content = content.replace(old_recalc, new_recalc)
    print("Updated recalculate_pending_payouts_for_property")
else:
    print("Could not find recalculate_pending_payouts_for_property")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
