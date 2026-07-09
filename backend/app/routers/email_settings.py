from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional

from app import models
from app.database import get_db
from app.main import get_agency_id

router = APIRouter(prefix="/email-settings", tags=["Email Settings"])

# SCHEMAS
class EmailTemplateCreate(BaseModel):
    name: str
    subject: str
    body_html: str
    body_text: Optional[str] = None
    is_active: bool = True

class EmailTemplateUpdate(BaseModel):
    subject: Optional[str] = None
    body_html: Optional[str] = None
    body_text: Optional[str] = None
    is_active: Optional[bool] = None

class EmailCampaignCreate(BaseModel):
    name: str
    trigger_type: str
    days_offset: str
    template_id: int
    is_active: bool = True

class EmailCampaignUpdate(BaseModel):
    name: Optional[str] = None
    trigger_type: Optional[str] = None
    days_offset: Optional[str] = None
    template_id: Optional[int] = None
    is_active: Optional[bool] = None

class TestCampaignRequest(BaseModel):
    test_email: str

@router.get("/templates", response_model=List[dict])
def get_templates(agency_id: int = Depends(get_agency_id), db: Session = Depends(get_db)):
    templates = db.query(models.EmailTemplate).filter(models.EmailTemplate.agency_id == agency_id).all()
    return [{"id": t.id, "name": t.name, "subject": t.subject, "is_active": t.is_active} for t in templates]

@router.get("/templates/{template_id}")
def get_template(template_id: int, agency_id: int = Depends(get_agency_id), db: Session = Depends(get_db)):
    template = db.query(models.EmailTemplate).filter(models.EmailTemplate.id == template_id, models.EmailTemplate.agency_id == agency_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    return template

@router.post("/templates")
def create_template(data: EmailTemplateCreate, agency_id: int = Depends(get_agency_id), db: Session = Depends(get_db)):
    template = models.EmailTemplate(agency_id=agency_id, **data.dict())
    db.add(template)
    db.commit()
    db.refresh(template)
    return template

@router.put("/templates/{template_id}")
def update_template(template_id: int, data: EmailTemplateUpdate, agency_id: int = Depends(get_agency_id), db: Session = Depends(get_db)):
    template = db.query(models.EmailTemplate).filter(models.EmailTemplate.id == template_id, models.EmailTemplate.agency_id == agency_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    
    for key, value in data.dict(exclude_unset=True).items():
        setattr(template, key, value)
        
    db.commit()
    db.refresh(template)
    return template


# CAMPAIGNS

@router.get("/campaigns")
def get_campaigns(agency_id: int = Depends(get_agency_id), db: Session = Depends(get_db)):
    campaigns = db.query(models.EmailCampaign).filter(models.EmailCampaign.agency_id == agency_id).all()
    return campaigns

@router.post("/campaigns")
def create_campaign(data: EmailCampaignCreate, agency_id: int = Depends(get_agency_id), db: Session = Depends(get_db)):
    campaign = models.EmailCampaign(agency_id=agency_id, **data.dict())
    db.add(campaign)
    db.commit()
    db.refresh(campaign)
    return campaign

@router.put("/campaigns/{campaign_id}")
def update_campaign(campaign_id: int, data: EmailCampaignUpdate, agency_id: int = Depends(get_agency_id), db: Session = Depends(get_db)):
    campaign = db.query(models.EmailCampaign).filter(models.EmailCampaign.id == campaign_id, models.EmailCampaign.agency_id == agency_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
        
    for key, value in data.dict(exclude_unset=True).items():
        setattr(campaign, key, value)
        
    db.commit()
    db.refresh(campaign)
    return campaign

@router.post("/campaigns/trigger-scheduler")
async def trigger_scheduler(agency_id: int = Depends(get_agency_id)):
    from app.services.email_reminder_service import process_overdue_reminders
    try:
        await process_overdue_reminders()
        return {"status": "success", "message": "Email scheduler triggered successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/campaigns/{campaign_id}")
def delete_campaign(campaign_id: int, agency_id: int = Depends(get_agency_id), db: Session = Depends(get_db)):
    campaign = db.query(models.EmailCampaign).filter(models.EmailCampaign.id == campaign_id, models.EmailCampaign.agency_id == agency_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
    db.delete(campaign)
    db.commit()
    return {"status": "deleted"}

@router.post("/campaigns/{campaign_id}/test")
async def test_campaign(campaign_id: int, request: TestCampaignRequest, agency_id: int = Depends(get_agency_id), db: Session = Depends(get_db)):
    from app.services import mail_service
    
    campaign = db.query(models.EmailCampaign).filter(models.EmailCampaign.id == campaign_id, models.EmailCampaign.agency_id == agency_id).first()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
        
    template = db.query(models.EmailTemplate).filter(models.EmailTemplate.id == campaign.template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
        
    comm_config = db.query(models.CommunicationConfig).filter(models.CommunicationConfig.agency_id == agency_id).first()
    if not comm_config:
        raise HTTPException(status_code=400, detail="Communication config not found for this agency")
        
    plan = db.query(models.RentPaymentPlan).join(models.Tenancy).filter(models.Tenancy.agency_id == agency_id).order_by(models.RentPaymentPlan.id.desc()).first()
    if not plan:
        raise HTTPException(status_code=400, detail="No rent payment plans found to use as sample data")
        
    tenancy = plan.tenancy
    property = tenancy.property
    tenant = property.tenants[0] if property.tenants else None
    if not tenant:
        raise HTTPException(status_code=400, detail="No tenant found for sample data")
        
    outstanding_amount = float(plan.expected_amount) - float(plan.paid_amount)
    
    replacements = {
        '{{Tenant First Name}}': tenant.first_name or '',
        '{{Tenant Last Name}}': tenant.last_name or '',
        '{{Tenant Name}}': f"{tenant.first_name} {tenant.last_name}".strip(),
        '{{Tenant Email}}': tenant.email or '',
        '{{Tenant Phone}}': tenant.phone or '',
        '{{Property Room No}}': property.room_no or '',
        '{{Property Reference}}': property.room_no or '',
        '{{Property Address Line 1}}': property.address_line_1 or '',
        '{{Property Address}}': property.address_line_1 or '',
        '{{Property City}}': property.city or '',
        '{{Property Postcode}}': property.postcode or '',
        '{{Landlord First Name}}': property.landlord.first_name if property.landlord else '',
        '{{Landlord Last Name}}': property.landlord.last_name if property.landlord else '',
        '{{Landlord Name}}': f"{property.landlord.first_name} {property.landlord.last_name}".strip() if property.landlord else "Your Landlord",
        '{{Rent Due Date}}': str(plan.due_date),
        '{{Expected Amount}}': f"£{float(plan.expected_amount):.2f}",
        '{{Paid Amount}}': f"£{float(plan.paid_amount):.2f}",
        '{{Outstanding Amount}}': f"£{outstanding_amount:.2f}",
        '{{Days Offset}}': "0 (Test)",
    }

    import markdown
    body_html = markdown.markdown(template.body_html, extensions=['nl2br'])
    subject = template.subject
    
    for key, value in replacements.items():
        body_html = body_html.replace(key, value)
        subject = subject.replace(key, value)
        
    from app.services.email_reminder_service import wrap_with_agency_header
    agency = db.query(models.Agency).filter(models.Agency.id == agency_id).first()
    if agency:
        body_html = wrap_with_agency_header(body_html, agency)
        
    msg = models.CommunicationMessage(
        agency_id=agency_id,
        property_id=property.id,
        tenant_id=tenant.id,
        type='email',
        direction='outbound',
        status='pending',
        subject=f"[TEST] {subject}",
        body_html=body_html,
        recipient_address=request.test_email,
        sender_address=comm_config.sender_email or 'no-reply@rentcollections.com',
        contact_type=f"test_campaign_{campaign.id}"
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)
    
    try:
        await mail_service.send_email_async(comm_config, msg, db)
        return {"status": "success", "message": "Test email sent successfully!"}
    except Exception as e:
        msg.status = 'failed'
        msg.delivery_status = 'failed'
        db.commit()
        raise HTTPException(status_code=500, detail=f"Failed to send email: {str(e)}")
