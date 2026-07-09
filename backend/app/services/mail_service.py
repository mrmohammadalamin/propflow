import asyncio
import smtplib
from email.message import EmailMessage
import imaplib
import email
from email.header import decode_header
from sqlalchemy.orm import Session
from datetime import datetime, timezone
import os
import re

from app import models

async def send_email_async(config: models.CommunicationConfig, message: models.CommunicationMessage, db: Session):
    def _send():
        msg = EmailMessage()
        msg['Subject'] = message.subject
        msg['From'] = f"{config.sender_name} <{config.sender_email}>" if config.sender_name else config.sender_email
        msg['To'] = message.recipient_address
        if config.reply_to:
            msg['Reply-To'] = config.reply_to
            
        msg.set_content(message.body_text or "")
        if message.body_html:
            body_html = message.body_html
            inline_attachments = []
            
            # Find all cid-local: prefixes and convert them to inline CID attachments
            if 'cid-local:' in body_html:
                import re
                import uuid
                backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
                
                def replace_cid(match):
                    local_path = match.group(1)
                    full_path = os.path.join(backend_dir, local_path.lstrip('/'))
                    if os.path.exists(full_path):
                        cid = str(uuid.uuid4())
                        inline_attachments.append({'path': full_path, 'cid': cid})
                        return f'cid:{cid}'
                    return ''
                    
                body_html = re.sub(r'cid-local:([^"\']+)', replace_cid, body_html)

            msg.add_alternative(body_html, subtype='html')
            
            # Add inline attachments to the html part
            for attach in inline_attachments:
                with open(attach['path'], 'rb') as f:
                    file_data = f.read()
                # add_related makes it an inline attachment tied to the HTML part
                msg.get_payload()[1].add_related(file_data, 'image', 'png', cid=f"<{attach['cid']}>")
            
            
        # Attachments
        for attachment in message.attachments:
            if os.path.exists(attachment.local_file_path):
                with open(attachment.local_file_path, 'rb') as f:
                    file_data = f.read()
                msg.add_attachment(file_data, maintype='application', subtype='octet-stream', filename=attachment.file_name)
                
        with smtplib.SMTP(config.smtp_server, config.smtp_port) as server:
            server.starttls()
            if config.smtp_username and config.smtp_password:
                server.login(config.smtp_username, config.smtp_password)
            server.send_message(msg)
            
    try:
        await asyncio.to_thread(_send)
        message.status = 'sent'
        message.sent_at = datetime.now(timezone.utc)
    except Exception as e:
        message.status = 'failed'
        print(f"Failed to send email: {e}")
    finally:
        db.commit()

def sync_inbound_emails_bg(agency_id: int):
    print(f"[MAIL SYNC] Starting sync for agency {agency_id}")
    from app.database import SessionLocal
    local_db = SessionLocal()
    try:
        config = local_db.query(models.CommunicationConfig).filter(models.CommunicationConfig.agency_id == agency_id).first()
        if not config or not config.is_enabled or not config.imap_server:
            print(f"[MAIL SYNC] Missing config or not enabled for agency {agency_id}")
            return
            
        print(f"[MAIL SYNC] Connecting to IMAP server {config.imap_server}")
        mail = imaplib.IMAP4_SSL(config.imap_server, config.imap_port)
        mail.login(config.smtp_username, config.smtp_password)
        mail.select("inbox")
        
        status, messages = mail.search(None, 'ALL')
        print(f"[MAIL SYNC] Search status: {status}, Total messages found: {len(messages[0].split())}")
        if status != "OK": return
            
        # Get the last 10 messages to ensure we don't process the entire inbox, and process even if they are marked read
        message_ids = messages[0].split()[-10:]
        
        for num in message_ids:
            res, msg_data = mail.fetch(num, '(RFC822)')
            if res != "OK": continue
            
            for response_part in msg_data:
                if isinstance(response_part, tuple):
                    msg = email.message_from_bytes(response_part[1])
                    subject, encoding = decode_header(msg["Subject"])[0]
                    if isinstance(subject, bytes):
                        subject = subject.decode(encoding if encoding else 'utf-8')
                        
                    sender = msg.get("From")
                    msg_id = msg.get("Message-ID")
                    
                    if local_db.query(models.CommunicationMessage).filter(models.CommunicationMessage.message_id_header == msg_id).first():
                        continue
                        
                    body_text = ""
                    body_html = ""
                    if msg.is_multipart():
                        for part in msg.walk():
                            content_type = part.get_content_type()
                            if content_type == "text/plain":
                                body_text += part.get_payload(decode=True).decode(errors='ignore')
                            elif content_type == "text/html":
                                body_html += part.get_payload(decode=True).decode(errors='ignore')
                    else:
                        body_text = msg.get_payload(decode=True).decode(errors='ignore')
                        
                    from email.utils import parseaddr
                    _, sender_email = parseaddr(sender)
                    in_reply_to = msg.get("In-Reply-To")
                    references = msg.get("References")
                    
                    property_id = None
                    contact_type = "Other"
                    
                    is_system_email = False

                    # 1. Thread Matching (Reply-To)
                    parent_msg = None
                    if in_reply_to:
                        parent_msg = local_db.query(models.CommunicationMessage).filter(
                            models.CommunicationMessage.message_id_header == in_reply_to,
                            models.CommunicationMessage.agency_id == agency_id
                        ).first()
                        if parent_msg:
                            is_system_email = True
                            if parent_msg.property_id:
                                property_id = parent_msg.property_id
                                
                            contact_type = parent_msg.contact_type if parent_msg.contact_type else "Other"
                    
                    # 2. Primary Matching (Property Reference in Subject)
                    if not property_id and subject:
                        match = re.search(r'PR-(\d+)', subject)
                        if match:
                            property_id = int(match.group(1))
                            is_system_email = True
                        else:
                            props = local_db.query(models.Property.id, models.Property.address_line_1, models.Property.postcode).filter(
                                models.Property.agency_id == agency_id
                            ).all()
                            for p in props:
                                addr = p.address_line_1 or ""
                                post = p.postcode or ""
                                if addr and addr.lower() in subject.lower() and post and post.lower() in subject.lower():
                                    property_id = p.id
                                    is_system_email = True
                                    break
                                    
                    # 3. Secondary Matching (Sender Email)
                    if sender_email:
                        tenant = local_db.query(models.Tenant).filter(models.Tenant.email == sender_email).first()
                        if tenant:
                            is_system_email = True
                            if contact_type == "Other": contact_type = "Tenant"
                            if not property_id and tenant.property_id:
                                property_id = tenant.property_id
                        else:
                            landlord = local_db.query(models.Landlord).filter(models.Landlord.email == sender_email).first()
                            if landlord:
                                is_system_email = True
                                if contact_type == "Other": contact_type = "Landlord"
                                if not property_id:
                                    props = local_db.query(models.Property).filter(models.Property.landlord_id == landlord.id).all()
                                    if len(props) == 1:
                                        property_id = props[0].id
                            else:
                                sp = local_db.query(models.ServiceProvider).filter(models.ServiceProvider.email == sender_email).first()
                                if sp:
                                    is_system_email = True
                                    if contact_type == "Other": contact_type = "Maintenance Provider"

                    if not is_system_email:
                        continue
                                    
                    new_msg = models.CommunicationMessage(
                        agency_id=agency_id,
                        property_id=property_id,
                        direction='inbound',
                        status='received',
                        subject=subject,
                        body_text=body_text,
                        body_html=body_html,
                        sender_address=sender,
                        recipient_address=config.sender_email,
                        message_id_header=msg_id,
                        sent_at=datetime.now(timezone.utc),
                        is_read=False,
                        contact_type=contact_type
                    )
                    local_db.add(new_msg)
                    local_db.commit()
    except Exception as e:
        print(f"IMAP Sync error: {e}")
    finally:
        local_db.close()

def sync_all_agencies_bg():
    from app.database import SessionLocal
    local_db = SessionLocal()
    try:
        configs = local_db.query(models.CommunicationConfig).filter(
            models.CommunicationConfig.is_enabled == True,
            models.CommunicationConfig.imap_server != None
        ).all()
        agency_ids = [c.agency_id for c in configs]
    except Exception as e:
        print(f"Failed to fetch agency configs for sync: {e}")
        agency_ids = []
    finally:
        local_db.close()
        
    for agency_id in agency_ids:
        sync_inbound_emails_bg(agency_id)