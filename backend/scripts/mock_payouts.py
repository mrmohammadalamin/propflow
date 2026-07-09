from sqlalchemy.orm import Session
from app.database import SessionLocal
from app import models
from app.main import recalculate_pending_payouts_for_property
from decimal import Decimal

def convert_old_payouts():
    db = SessionLocal()
    try:
        # Find all pending payouts (which are all landlord type)
        pending_payouts = db.query(models.Payout).filter(
            models.Payout.status == "pending",
            models.Payout.payment_type == "landlord"
        ).all()
        
        properties_to_recalc = set()
        
        for p in pending_payouts:
            # Check if there is an agent fee to create
            if p.management_fee and p.management_fee > 0:
                # Check if we already created an agent fee payout for this rent allocation
                existing = db.query(models.Payout).filter(
                    models.Payout.rent_allocation_id == p.rent_allocation_id,
                    models.Payout.payment_type == "agent_fee"
                ).first()
                if not existing:
                    # Agency name lookup
                    agency = db.query(models.Agency).join(models.Property).filter(models.Property.id == p.property_id).first()
                    agency_name = agency.name if agency else "Agency"
                    
                    payout_agent = models.Payout(
                        payment_type="agent_fee",
                        recipient_name=f"Agent Fee - {agency_name}",
                        property_id=p.property_id,
                        rent_allocation_id=p.rent_allocation_id,
                        payment_plan_id=p.payment_plan_id,
                        gross_amount=p.management_fee,
                        net_amount=p.management_fee,
                        status="pending"
                    )
                    db.add(payout_agent)
            
            properties_to_recalc.add(p.property_id)
            
        db.commit()
        
        # Now recalculate to generate Service Provider payouts
        for prop_id in properties_to_recalc:
            recalculate_pending_payouts_for_property(prop_id, db)
            
        db.commit()
        print(f"Successfully converted payouts and generated agent/service fees for {len(properties_to_recalc)} properties.")
        
    finally:
        db.close()

if __name__ == "__main__":
    convert_old_payouts()
