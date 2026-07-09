import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication

def send_landlord_statement_email(to_email: str, subject: str, body: str, attachment_path: str = None):
    """
    Sends an email with an optional PDF attachment using SMTP.
    Requires SMTP settings in the environment variables.
    """
    smtp_server = os.getenv('SMTP_SERVER')
    smtp_port = os.getenv('SMTP_PORT')
    smtp_user = os.getenv('SMTP_USERNAME')
    smtp_pass = os.getenv('SMTP_PASSWORD')
    
    if not all([smtp_server, smtp_port, smtp_user, smtp_pass]):
        print("WARNING: SMTP credentials not fully configured in .env. Skipping email sending.")
        return False
        
    try:
        msg = MIMEMultipart()
        msg['From'] = smtp_user
        msg['To'] = to_email
        msg['Subject'] = subject
        
        msg.attach(MIMEText(body, 'plain'))
        
        if attachment_path and os.path.exists(attachment_path):
            with open(attachment_path, "rb") as f:
                part = MIMEApplication(f.read(), Name=os.path.basename(attachment_path))
            part['Content-Disposition'] = f'attachment; filename="{os.path.basename(attachment_path)}"'
            msg.attach(part)
            
        server = smtplib.SMTP(smtp_server, int(smtp_port))
        server.starttls()
        server.login(smtp_user, smtp_pass)
        server.send_message(msg)
        server.quit()
        
        print(f"Email sent successfully to {to_email}")
        return True
    except Exception as e:
        print(f"Failed to send email to {to_email}. Error: {e}")
        return False
