from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app import models
from app.main import get_db, get_current_landlord

router = APIRouter(
    prefix="/landlord",
    tags=["landlord"],
    dependencies=[Depends(get_current_landlord)]
)

@router.get("/properties")
def get_properties(db: Session = Depends(get_db), current_landlord: models.Landlord = Depends(get_current_landlord)):
    properties = db.query(models.Property).filter(models.Property.landlord_id == current_landlord.id).all()
    # Eagerly load tenancies and tenants if needed, or return basic details
    result = []
    for p in properties:
        active_tenancy = next((t for t in p.tenancies if t.status == 'active'), None)
        result.append({
            "id": p.id,
            "address_line_1": p.address_line_1,
            "address_line_2": p.address_line_2,
            "city": p.city,
            "postcode": p.postcode,
            "status": p.status,
            "room_no": p.room_no,
            "rent_amount": active_tenancy.rent_amount if active_tenancy else 0,
            "payment_frequency": active_tenancy.payment_frequency if active_tenancy else "N/A"
        })
    return result

@router.get("/invoices")
def get_invoices(db: Session = Depends(get_db), current_landlord: models.Landlord = Depends(get_current_landlord)):
    property_ids = [p.id for p in db.query(models.Property).filter(models.Property.landlord_id == current_landlord.id).all()]
    invoices = db.query(models.Invoice).filter(models.Invoice.property_id.in_(property_ids)).all()
    return invoices

@router.get("/communications")
def get_communications(db: Session = Depends(get_db), current_landlord: models.Landlord = Depends(get_current_landlord)):
    messages = db.query(models.CommunicationMessage).filter(
        models.CommunicationMessage.landlord_id == current_landlord.id
    ).order_by(models.CommunicationMessage.created_at.desc()).all()
    return messages

@router.post("/audit")
def create_audit(action: str, resource_type: str = "document", resource_id: int = None, details: str = "", db: Session = Depends(get_db), current_landlord: models.Landlord = Depends(get_current_landlord)):
    audit = models.AuditLog(
        agency_id=current_landlord.agency_id,
        user_id=1, # System/Anonymous or we need to allow landlord_id in audit
        action=action,
        resource_type=resource_type,
        resource_id=resource_id,
        details=f"Landlord {current_landlord.email}: {details}"
    )
    db.add(audit)
    db.commit()
    return {"status": "recorded"}
