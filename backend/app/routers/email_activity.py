from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime, date

from app import models, auth
from app.database import get_db
from app.main import get_agency_id, get_current_user

router = APIRouter(prefix="/email-activity", tags=["Email Activity"])

@router.get("/summary")
def get_email_activity_summary(
    agency_id: int = Depends(get_agency_id),
    db: Session = Depends(get_db)
):
    today = date.today()
    
    base_query = db.query(models.CommunicationMessage).filter(
        models.CommunicationMessage.agency_id == agency_id,
        models.CommunicationMessage.type == 'email',
        models.CommunicationMessage.direction == 'outbound',
        func.date(models.CommunicationMessage.created_at) == today
    )

    total_sent = base_query.count()
    total_opened = base_query.filter(models.CommunicationMessage.opened_at.isnot(None)).count()
    total_unopened = total_sent - total_opened
    total_auto_reminders = base_query.filter(models.CommunicationMessage.contact_type.like('campaign_%')).count()
    total_failed = base_query.filter(models.CommunicationMessage.delivery_status == 'failed').count()

    return {
        "total_sent_today": total_sent,
        "total_opened": total_opened,
        "total_unopened": total_unopened,
        "total_auto_reminders": total_auto_reminders,
        "total_failed": total_failed
    }

@router.get("/logs")
def get_email_logs(
    agency_id: int = Depends(get_agency_id),
    property_id: Optional[int] = None,
    tenant_id: Optional[int] = None,
    status: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    db: Session = Depends(get_db)
):
    query = db.query(models.CommunicationMessage).filter(
        models.CommunicationMessage.agency_id == agency_id,
        models.CommunicationMessage.type == 'email',
        models.CommunicationMessage.direction == 'outbound'
    )
    
    if property_id:
        query = query.filter(models.CommunicationMessage.property_id == property_id)
    if tenant_id:
        query = query.filter(models.CommunicationMessage.tenant_id == tenant_id)
        
    if status and status != 'All':
        if status.lower() == 'opened':
            query = query.filter(models.CommunicationMessage.opened_at.isnot(None))
        elif status.lower() == 'unopened':
            query = query.filter(models.CommunicationMessage.opened_at.is_(None))
        elif status.lower() in ['sent', 'delivered']:
            query = query.filter(models.CommunicationMessage.delivery_status.in_(['sent', 'delivered']))
        elif status.lower() in ['failed', 'bounced']:
            query = query.filter(models.CommunicationMessage.delivery_status.in_(['failed', 'bounced']))
        elif status.lower() == 'pending':
            query = query.filter(models.CommunicationMessage.delivery_status == 'pending')
        
    query = query.order_by(models.CommunicationMessage.created_at.desc())
    
    total = query.count()
    logs = query.offset(offset).limit(limit).all()
    
    result = []
    for log in logs:
        property_ref = log.property.room_no if log.property else "N/A"
        property_addr = log.property.address_line_1 if log.property else "N/A"
        tenant_name = f"{log.tenant.first_name} {log.tenant.last_name}" if log.tenant else "N/A"
        
        result.append({
            "id": log.id,
            "property_reference": property_ref,
            "property_address": property_addr,
            "tenant_name": tenant_name,
            "recipient_email": log.recipient_address,
            "subject": log.subject,
            "email_type": "Campaign Reminder" if log.contact_type and log.contact_type.startswith('campaign_') else "Manual Email",
            "date_sent": log.created_at,
            "delivery_status": log.delivery_status or log.status,
            "open_status": "Opened" if log.opened_at else "Not Opened",
            "date_opened": log.opened_at,
            "sent_by": "System" if log.contact_type and log.contact_type.startswith('campaign_') else "Estate Agent"
        })
        
    return {"total": total, "logs": result}

@router.get("/track/{message_id}.gif")
def track_email_open(message_id: int, db: Session = Depends(get_db)):
    # Tracking pixel endpoint
    msg = db.query(models.CommunicationMessage).filter(models.CommunicationMessage.id == message_id).first()
    if msg and not msg.opened_at:
        msg.opened_at = datetime.utcnow()
        msg.is_read = True
        db.commit()
        
    # Return a 1x1 transparent GIF
    pixel = b'\x47\x49\x46\x38\x39\x61\x01\x00\x01\x00\x80\x00\x00\xff\xff\xff\x00\x00\x00\x21\xf9\x04\x01\x00\x00\x00\x00\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02\x44\x01\x00\x3b'
    return Response(content=pixel, media_type="image/gif")
