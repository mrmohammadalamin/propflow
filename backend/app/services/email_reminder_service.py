import os
import sys
from datetime import date, timedelta
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app import models
from app.services import mail_service

def wrap_with_agency_header(body_html: str, agency) -> str:
    logo_src = agency.logo_url
    if logo_src and logo_src.startswith('/'):
        # Pass the local path to mail_service via a special src prefix
        logo_src = f"cid-local:{logo_src}"
        
    logo_html = f'<img src="{logo_src}" alt="{agency.name} Logo" style="max-height: 60px; max-width: 200px;"/>' if logo_src else f'<h2 style="margin:0; color:#333;">{agency.name}</h2>'
    
    address = agency.address or ''
    phone = agency.contact_number or ''
    email = agency.email_address or ''
    
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
    </head>
    <body style="margin: 0; padding: 0; background-color: #f9f9f9;">
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 20px auto; color: #333; border: 1px solid #e0e0e0; padding: 30px; border-radius: 8px; background-color: #ffffff;">
            <table width="100%" cellpadding="0" cellspacing="0" border="0" style="border-bottom: 2px solid #f0f0f0; margin-bottom: 20px; padding-bottom: 20px;">
                <tr>
                    <td style="vertical-align: top; padding-right: 20px; width: 50%;">
                        {logo_html}
                    </td>
                    <td style="vertical-align: top; text-align: right; font-size: 12px; color: #666; line-height: 1.5; width: 50%;">
                        {f'<strong style="font-size: 14px;">{agency.name}</strong><br/>' if agency.name else ''}
                        {f'{address}<br/>' if address else ''}
                        {f'Phone: {phone}<br/>' if phone else ''}
                        {f'Email: <a href="mailto:{email}" style="color: #666; text-decoration: none;">{email}</a>' if email else ''}
                    </td>
                </tr>
            </table>
            
            <div style="font-size: 14px; line-height: 1.6;">
                {body_html}
            </div>
        </div>
    </body>
    </html>
    """

async def process_overdue_reminders():
    # Maintain the function name to avoid breaking main.py, but process all campaigns here
    db = SessionLocal()
    try:
        today = date.today()
        # Find active campaigns
        campaigns = db.query(models.EmailCampaign).filter(models.EmailCampaign.is_active == True).all()
        
        for campaign in campaigns:
            agency_id = campaign.agency_id
            
            # Get the agency's comm config
            comm_config = db.query(models.CommunicationConfig).filter(
                models.CommunicationConfig.agency_id == agency_id,
                models.CommunicationConfig.is_enabled == True
            ).first()
            if not comm_config:
                continue

            # Get the template
            template = db.query(models.EmailTemplate).filter(
                models.EmailTemplate.id == campaign.template_id,
                models.EmailTemplate.is_active == True
            ).first()
            if not template:
                continue

            # Parse schedule (e.g. "1,3,7")
            schedule_days = [int(d.strip()) for d in campaign.days_offset.split(',') if d.strip().isdigit()]
            if not schedule_days:
                # If no specific days provided, assume 0 (due date)
                schedule_days = [0]

            for target_days in schedule_days:
                if campaign.trigger_type == 'rent_overdue':
                    target_due_date = today - timedelta(days=target_days)
                elif campaign.trigger_type == 'rent_upcoming':
                    target_due_date = today + timedelta(days=target_days)
                elif campaign.trigger_type == 'rent_due':
                    target_due_date = today
                else:
                    continue # unknown trigger
                
                # Query matching plans
                plans = db.query(models.RentPaymentPlan).join(
                    models.Tenancy
                ).filter(
                    models.RentPaymentPlan.status != 'paid',
                    models.RentPaymentPlan.due_date == target_due_date,
                    models.Tenancy.agency_id == agency_id,
                    models.Tenancy.status == 'active'
                ).all()

                for plan in plans:
                    tenancy = plan.tenancy
                    property = tenancy.property
                    
                    for tenant in property.tenants:
                        if not tenant.email:
                            continue
                            
                        # Avoid duplicates: track contact_type by campaign ID
                        existing_msg = db.query(models.CommunicationMessage).filter(
                            models.CommunicationMessage.property_id == property.id,
                            models.CommunicationMessage.tenant_id == tenant.id,
                            models.CommunicationMessage.contact_type == f"campaign_{campaign.id}_{target_days}",
                            models.CommunicationMessage.created_at >= str(today)
                        ).first()
                        
                        if existing_msg:
                            continue

                        # Gather dynamic data
                        outstanding_amount = float(plan.expected_amount) - float(plan.paid_amount)
                        
                        replacements = {
                            # Tenant
                            '{{Tenant First Name}}': tenant.first_name or '',
                            '{{Tenant Last Name}}': tenant.last_name or '',
                            '{{Tenant Name}}': f"{tenant.first_name} {tenant.last_name}".strip(),
                            '{{Tenant Email}}': tenant.email or '',
                            '{{Tenant Phone}}': tenant.phone or '',
                            
                            # Property
                            '{{Property Room No}}': property.room_no or '',
                            '{{Property Reference}}': property.room_no or '',
                            '{{Property Address Line 1}}': property.address_line_1 or '',
                            '{{Property Address}}': property.address_line_1 or '',
                            '{{Property City}}': property.city or '',
                            '{{Property Postcode}}': property.postcode or '',
                            
                            # Landlord
                            '{{Landlord First Name}}': property.landlord.first_name if property.landlord else '',
                            '{{Landlord Last Name}}': property.landlord.last_name if property.landlord else '',
                            '{{Landlord Name}}': f"{property.landlord.first_name} {property.landlord.last_name}".strip() if property.landlord else "Your Landlord",
                            
                            # Rent
                            '{{Rent Due Date}}': str(plan.due_date),
                            '{{Expected Amount}}': f"£{float(plan.expected_amount):.2f}",
                            '{{Paid Amount}}': f"£{float(plan.paid_amount):.2f}",
                            '{{Outstanding Amount}}': f"£{outstanding_amount:.2f}",
                            '{{Days Offset}}': str(target_days),
                        }
                        import markdown
                        
                        body_html = markdown.markdown(template.body_html, extensions=['nl2br'])
                        subject = template.subject
                        
                        # Apply all replacements to both subject and body
                        for key, value in replacements.items():
                            body_html = body_html.replace(key, value)
                            subject = subject.replace(key, value)
                            
                        # Wrap with agency header
                        agency = db.query(models.Agency).filter(models.Agency.id == agency_id).first()
                        if agency:
                            body_html = wrap_with_agency_header(body_html, agency)

                        # Create msg
                        msg = models.CommunicationMessage(
                            agency_id=agency_id,
                            property_id=property.id,
                            tenant_id=tenant.id,
                            type='email',
                            direction='outbound',
                            status='pending',
                            subject=subject,
                            body_html=body_html,
                            recipient_address=tenant.email,
                            sender_address=comm_config.sender_email or 'no-reply@rentcollections.com',
                            contact_type=f"campaign_{campaign.id}_{target_days}"
                        )
                        db.add(msg)
                        db.commit()
                        db.refresh(msg)
                        
                        # Send email
                        try:
                            await mail_service.send_email_async(comm_config, msg, db)
                        except Exception as e:
                            print(f"Failed to send email: {e}")
                            msg.status = 'failed'
                            msg.delivery_status = 'failed'
                            db.commit()

    except Exception as e:
        print(f"Error in process_overdue_reminders: {e}")
    finally:
        db.close()
