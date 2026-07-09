from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, date
from typing import Optional, List, Dict, Any
from app.models import Payout, Property, Landlord, Tenant, Tenancy, Maintenance, RentPaymentPlan, Agency

def get_landlord_invoice_single(
    db: Session,
    property_id: int,
    date_from: date,
    date_to: date,
    statuses: Optional[List[str]] = None
) -> Dict[str, Any]:
    # Fetch property details
    prop = db.query(Property).filter(Property.id == property_id).first()
    if not prop:
        raise ValueError("Property not found")
        
    landlord = prop.landlord
    
    # Fetch tenants
    tenants = db.query(Tenant).filter(Tenant.property_id == property_id).all()
    tenant_names = ", ".join([f"{t.first_name} {t.last_name}" for t in tenants])
    
    # Query Payouts for this property within date range
    query = db.query(Payout).filter(
        Payout.property_id == property_id,
        Payout.payment_type == 'landlord',
        func.date(Payout.created_at) >= date_from,
        func.date(Payout.created_at) <= date_to
    )
    if statuses:
        query = query.filter(Payout.status.in_(statuses))
        
    payouts = query.all()
    
    # Aggregate
    total_rent = sum([p.gross_amount for p in payouts])
    total_maintenance = sum([p.maintenance_cost for p in payouts])
    total_management_fee = sum([p.management_fee for p in payouts])
    total_net = sum([p.net_amount for p in payouts])
    
    agency = db.query(Agency).filter(Agency.id == prop.agency_id).first()
    
    # Get actual maintenance records for detailed breakdown (for internal use, or if needed on invoice)
    maintenance_records = db.query(Maintenance).filter(
        Maintenance.property_id == property_id,
        func.date(Maintenance.maintenance_date) >= date_from,
        func.date(Maintenance.maintenance_date) <= date_to
    ).all()
    
    maint_details = [
        {"provider": m.service_provider.company_name if m.service_provider else "Unknown", "type": m.maintenance_type, "cost": float(m.cost)}
        for m in maintenance_records
    ]

    return {
        "report_type": "landlord_invoice_single",
        "date_from": str(date_from),
        "date_to": str(date_to),
        "property": {
            "id": prop.id,
            "name": prop.address_line_1,
            "reference": prop.room_no or str(prop.id),
            "address": f"{prop.address_line_1}, {prop.city}, {prop.postcode}"
        },
        "landlord": {
            "name": f"{landlord.first_name} {landlord.last_name}",
            "address": f"{landlord.address_line_1 or ''}, {landlord.city or ''}, {landlord.postcode or ''}".strip(', '),
            "email": landlord.email,
            "mobile_number": landlord.phone,
            "contact": landlord.email or landlord.phone
        },
        "tenant": {
            "name": tenant_names,
            "tenancy_period": "Current" # Simplified for now
        },
        "financials": {
            "rent_collected": float(total_rent),
            "maintenance_fees": float(total_maintenance),
            "actual_maintenance_costs": maint_details,
            "management_fee_amount": float(total_management_fee),
            "management_fee_base": float(total_management_fee / (1 + (agency.default_vat_rate/100)) if (agency and getattr(agency, 'vat_enabled', False) and getattr(agency, 'vat_registered', False)) else total_management_fee),
            "management_fee_vat": float(total_management_fee - (total_management_fee / (1 + (agency.default_vat_rate/100)))) if (agency and getattr(agency, 'vat_enabled', False) and getattr(agency, 'vat_registered', False)) else 0.0,
            "net_amount_payable": float(total_net)
        },
        "totals": {
            "total_rent_received": float(total_rent),
            "total_deductions": float(total_maintenance + total_management_fee),
            "net_amount_payable": float(total_net)
        }
    }

def get_landlord_invoice_multi(
    db: Session,
    landlord_id: int,
    date_from: date,
    date_to: date,
    statuses: Optional[List[str]] = None
) -> Dict[str, Any]:
    landlord = db.query(Landlord).filter(Landlord.id == landlord_id).first()
    if not landlord:
        raise ValueError("Landlord not found")
        
    properties = db.query(Property).filter(Property.landlord_id == landlord_id).all()
    
    breakdown = []
    total_rent_all = 0.0
    total_maint_all = 0.0
    total_agent_all = 0.0
    total_net_all = 0.0
    
    for prop in properties:
        query = db.query(Payout).filter(
            Payout.property_id == prop.id,
            Payout.payment_type == 'landlord',
            func.date(Payout.created_at) >= date_from,
            func.date(Payout.created_at) <= date_to
        )
        if statuses:
            query = query.filter(Payout.status.in_(statuses))
            
        payouts = query.all()
        
        prop_rent = float(sum([p.gross_amount for p in payouts]))
        prop_maint = float(sum([p.maintenance_cost for p in payouts]))
        prop_agent = float(sum([p.management_fee for p in payouts]))
        prop_net = float(sum([p.net_amount for p in payouts]))
        
        if prop_rent > 0 or prop_maint > 0 or prop_agent > 0 or prop_net > 0:
            agency = db.query(Agency).filter(Agency.id == prop.agency_id).first()
            breakdown.append({
                "property_id": prop.id,
                "property_name": prop.address_line_1,
                "rent_collected": prop_rent,
                "maintenance_fees": prop_maint,
                "agent_fees": prop_agent,
                "agent_fees_base": float(prop_agent / (1 + (agency.default_vat_rate/100)) if (agency and getattr(agency, 'vat_enabled', False) and getattr(agency, 'vat_registered', False)) else prop_agent),
                "agent_fees_vat": float(prop_agent - (prop_agent / (1 + (agency.default_vat_rate/100)))) if (agency and getattr(agency, 'vat_enabled', False) and getattr(agency, 'vat_registered', False)) else 0.0,
                "landlord_payment": prop_net
            })
            
            total_rent_all += prop_rent
            total_maint_all += prop_maint
            total_agent_all += prop_agent
            total_net_all += prop_net
            
    return {
        "report_type": "landlord_invoice_multi",
        "date_from": str(date_from),
        "date_to": str(date_to),
        "landlord": {
            "name": f"{landlord.first_name} {landlord.last_name}",
            "address": f"{landlord.address_line_1 or ''}, {landlord.city or ''}, {landlord.postcode or ''}".strip(', '),
            "email": landlord.email,
            "mobile_number": landlord.phone,
            "contact": landlord.email or landlord.phone
        },
        "properties_breakdown": breakdown,
        "totals": {
            "total_rent_collected": total_rent_all,
            "total_maintenance_fees": total_maint_all,
            "total_agent_fees": total_agent_all,
            "total_landlord_payments": total_net_all
        }
    }

def get_agency_summary(
    db: Session,
    agency_id: int,
    date_from: date,
    date_to: date,
    property_id: Optional[int] = None,
    statuses: Optional[List[str]] = None
) -> Dict[str, Any]:
    
    total_rent_collected = 0.0
    total_maintenance_fees = 0.0
    total_agent_fees = 0.0
    total_landlord_payments = 0.0
    total_service_provider_payments = 0.0
    total_outstanding_distributions = 0.0
    total_completed_distributions = 0.0
    
    property_details = {}

    def get_pd(p_id):
        if p_id not in property_details:
            prop = db.query(Property).filter(Property.id == p_id).first()
            if not prop: return None
            landlord = prop.landlord
            tenants = db.query(Tenant).filter(Tenant.property_id == prop.id).all()
            t_names = ", ".join([f"{t.first_name} {t.last_name}" for t in tenants])
            property_details[p_id] = {
                "property_name": prop.address_line_1,
                "property_address": f"{prop.address_line_1}, {prop.city}",
                "property_reference": prop.room_no or str(prop.id),
                "landlord_name": f"{landlord.first_name} {landlord.last_name}" if landlord else "N/A",
                "tenant_name": t_names,
                "rent_payments_received": 0.0,
                "maintenance_fees": 0.0,
                "management_fee_amount": 0.0,
                "landlord_payments_made": 0.0,
                "service_provider_payments_made": 0.0
            }
        return property_details[p_id]

    # Base query for payouts within date range
    query = db.query(Payout).join(Property).filter(
        Property.agency_id == agency_id,
        func.date(Payout.created_at) >= date_from,
        func.date(Payout.created_at) <= date_to
    )
    
    if property_id:
        query = query.filter(Payout.property_id == property_id)
        
    if statuses:
        query = query.filter(Payout.status.in_(statuses))
        
    payouts = query.all()
    
    from app.models import Transaction
    t_query = db.query(Transaction).join(Property).filter(
        Property.agency_id == agency_id,
        Transaction.transaction_type == 'rent',
        func.date(Transaction.created_at) >= date_from,
        func.date(Transaction.created_at) <= date_to
    )
    if property_id:
        t_query = t_query.filter(Property.id == property_id)
    if statuses:
        t_query = t_query.filter(Transaction.status.in_(statuses))
        
    for tx in t_query.all():
        if tx.property_id:
            pd = get_pd(tx.property_id)
            if pd:
                pd["rent_payments_received"] += float(tx.amount)
                total_rent_collected += float(tx.amount)
    
    for p in payouts:
        pd = get_pd(p.property_id)
        if not pd: continue
        
        # Determine amounts based on payment_type
        if p.payment_type == 'landlord':
            total_maintenance_fees += float(p.maintenance_cost)
            total_agent_fees += float(p.management_fee)
            total_landlord_payments += float(p.net_amount)
            
            pd["maintenance_fees"] += float(p.maintenance_cost)
            pd["management_fee_amount"] += float(p.management_fee)
            pd["landlord_payments_made"] += float(p.net_amount)
            
        elif p.payment_type == 'service_provider':
            total_service_provider_payments += float(p.net_amount)
            pd["service_provider_payments_made"] += float(p.net_amount)
            
        if p.status == 'pending':
            total_outstanding_distributions += float(p.net_amount)
        elif p.status == 'paid':
            total_completed_distributions += float(p.net_amount)

    # Actual Maintenance costs (from Maintenance table)
    m_query = db.query(Maintenance).filter(
        Maintenance.agency_id == agency_id,
        func.date(Maintenance.maintenance_date) >= date_from,
        func.date(Maintenance.maintenance_date) <= date_to
    )
    if property_id:
        m_query = m_query.filter(Maintenance.property_id == property_id)
        
    actual_maintenance = 0.0
    for m in m_query.all():
        pd = get_pd(m.property_id)
        if pd:
            actual_maintenance += float(m.cost)

    return {
        "report_type": "agency_summary",
        "date_from": str(date_from),
        "date_to": str(date_to),
        "details": list(property_details.values()),
        "totals": {
            "total_rent_collected": total_rent_collected,
            "total_maintenance_fees": total_maintenance_fees,
            "total_actual_maintenance_costs": actual_maintenance,
            "total_agent_fees": total_agent_fees,
            "total_landlord_payments": total_landlord_payments,
            "total_service_provider_payments": total_service_provider_payments,
            "total_outstanding_distributions": total_outstanding_distributions,
            "total_completed_distributions": total_completed_distributions
        }
    }


def get_tenant_invoice(
    db: Session,
    tenant_id: int,
    date_from: date,
    date_to: date,
    statuses: Optional[List[str]] = None
) -> Dict[str, Any]:
    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise ValueError("Tenant not found")
        
    tenancy = db.query(Tenancy).filter(Tenancy.property_id == tenant.property_id).first()
    if not tenancy:
        raise ValueError("No active tenancy found for this tenant")
        
    prop = tenancy.property
    
    # Get expected rent payments
    rent_plans = db.query(RentPaymentPlan).filter(
        RentPaymentPlan.tenancy_id == tenancy.id,
        RentPaymentPlan.due_date >= date_from,
        RentPaymentPlan.due_date <= date_to
    ).order_by(RentPaymentPlan.due_date).all()
    
    # Get actual transactions
    from app.models import Transaction
    transactions = db.query(Transaction).filter(
        Transaction.tenant_id == tenant_id,
        Transaction.transaction_type == 'rent',
        func.date(Transaction.created_at) >= date_from,
        func.date(Transaction.created_at) <= date_to
    ).order_by(Transaction.created_at).all()
    
    total_expected = sum([float(rp.expected_amount) for rp in rent_plans if rp.expected_amount is not None])
    total_paid = sum([float(rp.paid_amount) for rp in rent_plans if rp.paid_amount is not None])
    balance_due = total_expected - total_paid
    
    rent_details = []
    for rp in rent_plans:
        rent_details.append({
            "due_date": str(rp.due_date),
            "expected_amount": float(rp.expected_amount) if rp.expected_amount is not None else 0.0,
            "paid_amount": float(rp.paid_amount) if rp.paid_amount is not None else 0.0,
            "status": rp.status or ""
        })
        
    transaction_details = []
    for tx in transactions:
        transaction_details.append({
            "date": str(tx.created_at.date()),
            "amount": float(tx.amount) if tx.amount is not None else 0.0,
            "reference": tx.reference or "Rent Payment",
            "status": tx.status or ""
        })
        
    return {
        "report_type": "tenant_invoice",
        "date_from": str(date_from),
        "date_to": str(date_to),
        "tenant": {
            "id": tenant.id,
            "name": f"{tenant.first_name} {tenant.last_name}",
            "email": tenant.email,
            "phone": tenant.phone
        },
        "property": {
            "id": prop.id,
            "name": prop.address_line_1
        },
        "totals": {
            "total_rent_due": total_expected,
            "total_rent_paid": total_paid,
            "outstanding_balance": balance_due
        },
        "rent_schedule": rent_details,
        "transactions": transaction_details
    }
def get_agency_property_statement(
    db: Session,
    agency_id: int,
    property_id: int,
    date_from: date,
    date_to: date,
    statuses: Optional[List[str]] = None
) -> Dict[str, Any]:
    prop = db.query(Property).filter(Property.id == property_id, Property.agency_id == agency_id).first()
    if not prop:
        raise ValueError("Property not found")
    
    landlord = prop.landlord
    landlord_name = f"{landlord.first_name} {landlord.last_name}" if landlord else "N/A"
    
    # 1. Compute Opening Balance (before date_from)
    from app.models import Transaction, Payout, Maintenance
    
    past_rent_tx = db.query(func.sum(Transaction.amount)).filter(
        Transaction.property_id == property_id,
        Transaction.transaction_type == 'rent',
        func.date(Transaction.created_at) < date_from
    ).scalar() or 0.0
    
    past_payouts = db.query(Payout).filter(
        Payout.property_id == property_id,
        Payout.status == 'paid',
        func.date(Payout.created_at) < date_from
    ).all()
    
    past_payout_deductions = sum(float(p.net_amount or 0) + float(p.management_fee or 0) for p in past_payouts)
    
    past_maint = db.query(func.sum(Maintenance.cost)).filter(
        Maintenance.property_id == property_id,
        func.date(Maintenance.maintenance_date) < date_from
    ).scalar() or 0.0
    
    opening_balance = float(past_rent_tx) - past_payout_deductions - float(past_maint)
    
    # 2. Fetch records in date range
    rent_txs = db.query(Transaction).filter(
        Transaction.property_id == property_id,
        Transaction.transaction_type == 'rent',
        func.date(Transaction.created_at) >= date_from,
        func.date(Transaction.created_at) <= date_to
    ).all()
    
    payouts = db.query(Payout).filter(
        Payout.property_id == property_id,
        Payout.status == 'paid',
        func.date(Payout.created_at) >= date_from,
        func.date(Payout.created_at) <= date_to
    ).all()
    
    maints = db.query(Maintenance).filter(
        Maintenance.property_id == property_id,
        func.date(Maintenance.maintenance_date) >= date_from,
        func.date(Maintenance.maintenance_date) <= date_to
    ).all()
    
    # 3. Build Timeline
    ledger = []
    
    for tx in rent_txs:
        ledger.append({
            "date": tx.created_at,
            "description": "Rent Credit",
            "credit": float(tx.amount),
            "charge": 0.0
        })
        
    for p in payouts:
        if p.management_fee and float(p.management_fee) > 0:
            ledger.append({
                "date": p.created_at,
                "description": f"AG Fee",
                "credit": 0.0,
                "charge": float(p.management_fee)
            })
        if p.net_amount and float(p.net_amount) > 0:
            ledger.append({
                "date": p.created_at,
                "description": "Landlord Payment",
                "credit": 0.0,
                "charge": float(p.net_amount)
            })
            
    for m in maints:
        if m.cost and float(m.cost) > 0:
            ledger.append({
                "date": m.maintenance_date,
                "description": m.maintenance_type or "Maintenance/Repair",
                "credit": 0.0,
                "charge": float(m.cost)
            })
            
    # Sort chronologically
    ledger.sort(key=lambda x: x["date"])
    
    # Compute running balance
    running_balance = opening_balance
    formatted_ledger = []
    
    for entry in ledger:
        running_balance = running_balance + entry["credit"] - entry["charge"]
        formatted_ledger.append({
            "date": entry["date"].strftime("%d.%m.%Y"),
            "description": entry["description"],
            "credit": entry["credit"],
            "charge": entry["charge"],
            "balance": running_balance
        })
        
    # Calculate totals for summary boxes
    total_rental_income = sum(entry["credit"] for entry in formatted_ledger)
    net_landlord_payout = sum(entry["charge"] for entry in formatted_ledger if "Landlord Payment" in entry["description"])
    total_expenses = sum(entry["charge"] for entry in formatted_ledger if "Landlord Payment" not in entry["description"])
        
    return {
        "report_type": "agency_property_statement",
        "date_from": date_from.strftime("%d.%m.%Y"),
        "date_to": date_to.strftime("%d.%m.%Y"),
        "property": {
            "id": prop.id,
            "name": prop.address_line_1,
            "address": prop.address_line_1,
            "city": prop.city
        },
        "landlord_name": landlord_name,
        "opening_balance": opening_balance,
        "closing_balance": running_balance,
        "total_rental_income": total_rental_income,
        "total_expenses": total_expenses,
        "net_landlord_payout": net_landlord_payout,
        "ledger": formatted_ledger
    }

