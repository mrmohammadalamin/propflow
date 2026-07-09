from fastapi import FastAPI, Depends, HTTPException, Header, UploadFile, File, Form, status, Query, BackgroundTasks
from fastapi.staticfiles import StaticFiles
import os
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel, EmailStr
from datetime import timedelta, datetime
from decimal import Decimal

from . import models, database, auth
from .agents.gemini_agent import gemini_core
from .agents.allocator import allocator_agent
from .engines.ledger import LedgerEngine

# Commented out because it crashes through Supabase Transaction Pooler (PgBouncer)
# models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="Rent Collections Agentic API")

import asyncio
from fastapi.concurrency import run_in_threadpool
from app.services import mail_service

async def mail_sync_loop():
    while True:
        try:
            await run_in_threadpool(mail_service.sync_all_agencies_bg)
        except Exception as e:
            print(f"Error in global mail sync loop: {e}")
        await asyncio.sleep(30)

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.services.email_reminder_service import process_overdue_reminders

scheduler = AsyncIOScheduler()

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(mail_sync_loop())
    scheduler.add_job(process_overdue_reminders, 'cron', hour=8) # Run daily at 8 AM
    scheduler.start()

from fastapi.staticfiles import StaticFiles

# Add CORS middleware for Flutter Web support
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins (change to specific domains in production)
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods including OPTIONS
    allow_headers=["*"],  # Allows all headers
)

import os
os.makedirs("documents/invoices", exist_ok=True)
os.makedirs("documents/logos", exist_ok=True)
os.makedirs("documents/avatars", exist_ok=True)
app.mount("/documents", StaticFiles(directory="documents"), name="documents")

# Dependency
def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

# OAuth2 Scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    payload = auth.decode_access_token(token)
    if payload is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    
    email: str = payload.get("sub")
    role: str = payload.get("role")
    
    if role == "landlord":
        landlord = db.query(models.Landlord).filter(models.Landlord.email == email).first()
        if landlord is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Landlord not found")
        landlord.role = "landlord"
        return landlord

    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user

def get_current_landlord(current_user = Depends(get_current_user)):
    if getattr(current_user, "role", None) != "landlord":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized as a landlord")
    return current_user

def get_agency_id(current_user = Depends(get_current_user)):
    return current_user.agency_id

# --- SCHEMAS ---
class CommunicationConfigUpdate(BaseModel):
    is_enabled: Optional[bool] = None
    is_sms_enabled: Optional[bool] = None
    mail_provider: Optional[str] = None
    smtp_server: Optional[str] = None
    smtp_port: Optional[int] = None
    smtp_username: Optional[str] = None
    smtp_password: Optional[str] = None
    smtp_ssl: Optional[bool] = None
    sender_name: Optional[str] = None
    sender_email: Optional[str] = None
    reply_to: Optional[str] = None
    signature: Optional[str] = None
    imap_server: Optional[str] = None
    imap_port: Optional[int] = None
    imap_ssl: Optional[bool] = None

class CommunicationMessageCreate(BaseModel):
    property_id: Optional[int] = None
    tenant_id: Optional[int] = None
    landlord_id: Optional[int] = None
    type: Optional[str] = 'email'
    direction: Optional[str] = 'outbound'
    status: Optional[str] = 'sent'
    subject: str
    body_html: Optional[str] = None
    body_text: Optional[str] = None
    recipient_address: str
    cc_address: Optional[str] = None
    bcc_address: Optional[str] = None

class AgencyRegister(BaseModel):
    agency_name: str
    subdomain: str
    admin_name: str
    admin_email: EmailStr
    admin_password: str

class AgencyUpdate(BaseModel):
    agency_name: str
    address: Optional[str] = None
    contact_number: Optional[str] = None
    email_address: Optional[str] = None
    vat_enabled: Optional[bool] = False
    default_vat_rate: Optional[float] = 20.0
    vat_registered: Optional[bool] = False
    vat_registration_number: Optional[str] = None

class PropertyCreate(BaseModel):
    room_no: Optional[str] = None
    address_line_1: str
    address_line_2: Optional[str] = None
    city: str
    county: Optional[str] = None
    postcode: str
    landlord_id: int

class LandlordCreate(BaseModel):
    first_name: str
    last_name: str
    co: Optional[str] = None
    address_line_1: Optional[str] = None
    address_line_2: Optional[str] = None
    city: Optional[str] = None
    county: Optional[str] = None
    postcode: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None

class TenantCreate(BaseModel):
    first_name: str
    last_name: str
    address_line_1: Optional[str] = None
    address_line_2: Optional[str] = None
    city: Optional[str] = None
    county: Optional[str] = None
    postcode: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None

class TenancyCreate(BaseModel):
    property_id: int
    rent_amount: float
    due_day: int
    start_date: str
    management_fee_percentage: Optional[float] = 10.00
    deposit_amount: Optional[float] = 0.00
    deposit_amount: Optional[float] = 0.00

class NewTenantInput(BaseModel):
    first_name: str
    last_name: str
    address_line_1: Optional[str] = None
    address_line_2: Optional[str] = None
    city: Optional[str] = None
    county: Optional[str] = None
    postcode: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None

class AdvancedPropertySetup(BaseModel):
    room_no: Optional[str] = None
    address_line_1: str
    address_line_2: Optional[str] = None
    city: str
    county: Optional[str] = None
    postcode: str
    # Landlord
    landlord_id: Optional[int] = None
    landlord_first_name: Optional[str] = None
    landlord_last_name: Optional[str] = None
    landlord_co: Optional[str] = None
    landlord_address_line_1: Optional[str] = None
    landlord_address_line_2: Optional[str] = None
    landlord_city: Optional[str] = None
    landlord_county: Optional[str] = None
    landlord_postcode: Optional[str] = None
    landlord_email: Optional[str] = None
    landlord_phone: Optional[str] = None
    # Tenants
    existing_tenant_ids: List[int] = []
    new_tenants: List[NewTenantInput] = []
    # Tenancy / Payment Plan
    rent_amount: float
    due_day: int
    start_date: str
    management_fee_percentage: Optional[float] = 10.00
    deposit_amount: Optional[float] = 0.00
    deposit_amount: Optional[float] = 0.00
    assigned_manager_id: Optional[int] = None

class MaintenanceCreate(BaseModel):
    property_id: int
    maintenance_type: str
    details: str
    cost: float
    maintenance_date: str

class ServiceProviderCreate(BaseModel):
    company_name: str
    director_name: Optional[str] = None
    address: Optional[str] = None
    contact_number: Optional[str] = None
    email: Optional[str] = None
    vat_registered: Optional[bool] = False
    vat_number: Optional[str] = None
    default_vat_rate: Optional[float] = 20.0

class BankEntryCreate(BaseModel):
    date: str
    reference: str
    amount: float

class RentAllocationRequest(BaseModel):
    bank_entry_id: int
    tenancy_id: int
    amount: float
    month_date: str # e.g. "2024-05-01"

class LandlordAdvanceCreate(BaseModel):
    landlord_id: int
    amount: float
    notes: Optional[str] = None


class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: str # administrator, admin, support_agent, accountant

class UserUpdate(BaseModel):
    name: str

class UserUpdateAdmin(BaseModel):
    name: str
    email: EmailStr
    role: str
    password: Optional[str] = None

# --- HELPERS ---
def log_activity(db: Session, agency_id: int, user_id: int, action: str, resource_type: str = None, resource_id: int = None, details: str = None):
    log = models.AuditLog(
        agency_id=agency_id,
        user_id=user_id,
        action=action,
        resource_type=resource_type,
        resource_id=resource_id,
        details=details
    )
    db.add(log)
    db.commit()

def check_role(roles: List[str]):
    def role_checker(current_user: models.User = Depends(get_current_user)):
        if current_user.role not in roles:
            raise HTTPException(status_code=403, detail="Permission denied")
        return current_user
    return role_checker

# --- AUTH ENDPOINTS ---
@app.post("/auth/register")
def register_agency(data: AgencyRegister, db: Session = Depends(get_db)):
    if db.query(models.User).filter(models.User.email == data.admin_email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
        
    agency = models.Agency(name=data.agency_name, subdomain=data.subdomain)
    db.add(agency)
    db.commit()
    db.refresh(agency)
    
    hashed_pwd = auth.get_password_hash(data.admin_password)
    user = models.User(agency_id=agency.id, name=data.admin_name, email=data.admin_email, role="administrator", password_hash=hashed_pwd)
    db.add(user)
    db.commit()
    
    return {"message": "Agency registered successfully"}

@app.post("/auth/login")
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == form_data.username).first()
    if not user or not auth.verify_password(form_data.password, user.password_hash):
        raise HTTPException(status_code=400, detail="Incorrect email or password")
    
    agency = db.query(models.Agency).filter(models.Agency.id == user.agency_id).first()
    access_token_expires = timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(data={"sub": user.email}, expires_delta=access_token_expires)
    return {
        "access_token": access_token, 
        "token_type": "bearer", 
        "agency_id": user.agency_id,
        "role": user.role,
        "user_id": user.id,
        "name": user.name,
        "email": user.email,
        "avatar_url": user.avatar_url,
        "agency_name": agency.name if agency else "Agentic Hub",
        "logo_url": agency.logo_url if agency else None,
        "agency_address": agency.address if agency else None,
        "agency_contact_number": agency.contact_number if agency else None,
        "agency_email_address": agency.email_address if agency else None
    }

class MagicLinkRequest(BaseModel):
    email: EmailStr
    client_url: Optional[str] = "http://localhost:3000"

from app.services.mail_service import send_email_async

@app.post("/auth/magic-link/request")
async def request_magic_link(data: MagicLinkRequest, db: Session = Depends(get_db)):
    landlord = db.query(models.Landlord).filter(models.Landlord.email == data.email).first()
    if not landlord:
        # Prevent email enumeration
        return {"message": "If an account with that email exists, a magic link has been sent."}
    
    # Check rate limiting / existing unused tokens in the last minute
    recent_token = db.query(models.MagicLinkToken).filter(
        models.MagicLinkToken.email == data.email,
        models.MagicLinkToken.is_used == False,
        models.MagicLinkToken.created_at >= datetime.utcnow() - timedelta(minutes=1)
    ).first()
    if recent_token:
        raise HTTPException(status_code=429, detail="Please wait before requesting another link.")
    
    token_str = auth.create_magic_link_token(data.email)
    expires_at = datetime.utcnow() + timedelta(minutes=15)
    
    new_token = models.MagicLinkToken(
        email=data.email,
        token=token_str,
        expires_at=expires_at
    )
    db.add(new_token)
    
    # Create an audit log
    audit = models.AuditLog(
        agency_id=landlord.agency_id,
        user_id=1, # System/Anonymous
        action="MAGIC_LINK_REQUESTED",
        resource_type="landlord",
        resource_id=landlord.id,
        details=f"Magic link requested for {landlord.email}"
    )
    db.add(audit)
    
    # Construct the magic link URL dynamically
    base_url = data.client_url.rstrip('/') if data.client_url else "http://localhost:3000"
    magic_link_url = f"{base_url}/?token={token_str}"
    print(f"*** MAGIC LINK FOR {data.email}: {magic_link_url} ***")

    # Send Email via Mail Service
    config = db.query(models.CommunicationConfig).filter(models.CommunicationConfig.agency_id == landlord.agency_id).first()
    if config and config.is_enabled and config.smtp_server:
        # Create CommunicationMessage
        comm_msg = models.CommunicationMessage(
            agency_id=landlord.agency_id,
            landlord_id=landlord.id,
            type='email',
            direction='outbound',
            subject="Your Login Link for the Landlord Portal",
            body_text=f"Hello {landlord.first_name},\n\nPlease click the following link to log in to your Landlord Portal:\n{magic_link_url}\n\nThis link will expire in 15 minutes.\n\nThank you.",
            body_html=f"<p>Hello {landlord.first_name},</p><p>Please click the link below to log in to your Landlord Portal:</p><p><a href='{magic_link_url}'>Login Now</a></p><p>This link will expire in 15 minutes.</p>",
            recipient_address=landlord.email,
            status='draft'
        )
        db.add(comm_msg)
        db.commit()
        db.refresh(comm_msg)
        await send_email_async(config, comm_msg, db)
    else:
        db.commit()
    
    return {"message": "If an account with that email exists, a magic link has been sent."}

@app.get("/auth/magic-link/verify")
def verify_magic_link(token: str, db: Session = Depends(get_db)):
    magic_token = db.query(models.MagicLinkToken).filter(
        models.MagicLinkToken.token == token,
        models.MagicLinkToken.is_used == False
    ).first()
    if not magic_token:
        raise HTTPException(status_code=400, detail="Invalid or expired token.")
        
    expires_at_naive = magic_token.expires_at.replace(tzinfo=None) if getattr(magic_token.expires_at, "tzinfo", None) else magic_token.expires_at
    if expires_at_naive < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Invalid or expired token.")
    landlord = db.query(models.Landlord).filter(models.Landlord.email == magic_token.email).first()
    if not landlord:
        raise HTTPException(status_code=404, detail="Landlord not found.")
        
    magic_token.is_used = True
    db.commit()
    
    agency = db.query(models.Agency).filter(models.Agency.id == landlord.agency_id).first()
    access_token = auth.create_landlord_access_token(landlord_id=landlord.id, email=landlord.email)
    
    # Create audit log
    audit = models.AuditLog(
        agency_id=landlord.agency_id,
        user_id=1, # System
        action="MAGIC_LINK_USED",
        resource_type="landlord",
        resource_id=landlord.id,
        details=f"Magic link used by {landlord.email}"
    )
    db.add(audit)
    db.commit()
    
    return {
        "access_token": access_token, 
        "token_type": "bearer", 
        "agency_id": landlord.agency_id,
        "role": "landlord",
        "user_id": landlord.id,
        "name": f"{landlord.first_name} {landlord.last_name}",
        "email": landlord.email,
        "avatar_url": None,
        "agency_name": agency.name if agency else "Agentic Hub",
        "logo_url": agency.logo_url if agency else None,
        "agency_address": agency.address if agency else None,
        "agency_contact_number": agency.contact_number if agency else None,
        "agency_email_address": agency.email_address if agency else None
    }

# --- PROFILE & CUSTOMIZATION ENDPOINTS ---
@app.get("/users/me")
def get_me(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency = db.query(models.Agency).filter(models.Agency.id == current_user.agency_id).first()
    return {
        "id": current_user.id,
        "name": current_user.name,
        "email": current_user.email,
        "role": current_user.role,
        "avatar_url": current_user.avatar_url,
        "agency": {
            "id": agency.id,
            "name": agency.name,
            "subdomain": agency.subdomain,
            "logo_url": agency.logo_url,
            "address": agency.address,
            "contact_number": agency.contact_number,
            "email_address": agency.email_address
        } if agency else None
    }

@app.post("/agencies/logo")
async def upload_agency_logo(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role not in ["administrator", "admin"]:
        raise HTTPException(status_code=403, detail="Only administrators can upload company logo")
        
    agency = db.query(models.Agency).filter(models.Agency.id == current_user.agency_id).first()
    if not agency:
        raise HTTPException(status_code=404, detail="Agency not found")
        
    file_ext = os.path.splitext(file.filename)[1]
    filename = f"logo_{agency.id}{file_ext}"
    file_path = os.path.join("documents/logos", filename)
    
    with open(file_path, "wb") as buffer:
        buffer.write(await file.read())
        
    agency.logo_url = f"/documents/logos/{filename}"
    db.commit()
    
    return {"logo_url": agency.logo_url}

@app.get("/agency/profile")
def get_agency_profile(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    agency = db.query(models.Agency).filter(models.Agency.id == current_user.agency_id).first()
    if not agency:
        raise HTTPException(status_code=404, detail="Agency not found")
        
    return {
        "id": agency.id,
        "name": agency.name,
        "subdomain": agency.subdomain,
        "logo_url": agency.logo_url,
        "address": agency.address,
        "contact_number": agency.contact_number,
        "email_address": agency.email_address,
        "vat_enabled": getattr(agency, 'vat_enabled', False),
        "default_vat_rate": getattr(agency, 'default_vat_rate', 20.0),
        "vat_registered": getattr(agency, 'vat_registered', False),
        "vat_registration_number": getattr(agency, 'vat_registration_number', None)
    }

@app.put("/agencies")
def update_agency(
    data: AgencyUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role not in ["administrator", "admin"]:
        raise HTTPException(status_code=403, detail="Only administrators can update agency settings")
        
    agency = db.query(models.Agency).filter(models.Agency.id == current_user.agency_id).first()
    if not agency:
        raise HTTPException(status_code=404, detail="Agency not found")
        
    agency.name = data.agency_name
    agency.address = data.address
    agency.contact_number = data.contact_number
    agency.email_address = data.email_address
    agency.vat_enabled = data.vat_enabled
    agency.default_vat_rate = data.default_vat_rate
    agency.vat_registered = data.vat_registered
    agency.vat_registration_number = data.vat_registration_number
    db.commit()
    db.refresh(agency)
    
    return {
        "agency_name": agency.name, 
        "logo_url": agency.logo_url,
        "address": agency.address,
        "contact_number": agency.contact_number,
        "email_address": agency.email_address,
        "vat_enabled": agency.vat_enabled,
        "default_vat_rate": agency.default_vat_rate,
        "vat_registered": agency.vat_registered,
        "vat_registration_number": agency.vat_registration_number
    }

@app.put("/users/me")
def update_me(
    data: UserUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    current_user.name = data.name
    db.commit()
    db.refresh(current_user)
    return {"name": current_user.name, "email": current_user.email, "role": current_user.role}

@app.post("/users/avatar")
async def upload_user_avatar(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    file_ext = os.path.splitext(file.filename)[1]
    filename = f"avatar_{current_user.id}{file_ext}"
    file_path = os.path.join("documents/avatars", filename)
    
    with open(file_path, "wb") as buffer:
        buffer.write(await file.read())
        
    current_user.avatar_url = f"/documents/avatars/{filename}"
    db.commit()
    
    return {"avatar_url": current_user.avatar_url}

@app.get("/")
def read_root():
    return {"message": "Welcome to the Agentic Property SaaS API"}

@app.get("/dashboard/stats/")
def get_dashboard_stats(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency_id = current_user.agency_id
    from sqlalchemy import func
    
    total_properties = db.query(func.count(models.Property.id)).filter(models.Property.agency_id == agency_id).scalar() or 0
    total_tenants = db.query(func.count(models.Tenant.id)).filter(models.Tenant.agency_id == agency_id).scalar() or 0
    total_landlords = db.query(func.count(models.Landlord.id)).filter(models.Landlord.agency_id == agency_id).scalar() or 0
    
    today = datetime.now().date()
    
    # Rent Expected Today
    rent_expected_today = db.query(func.sum(models.RentPaymentPlan.expected_amount - models.RentPaymentPlan.paid_amount)).join(
        models.Tenancy
    ).filter(
        models.Tenancy.agency_id == agency_id,
        models.RentPaymentPlan.due_date == today,
        models.RentPaymentPlan.status != "paid"
    ).scalar() or 0.0

    # Rent Overdue
    rent_overdue = db.query(func.sum(models.RentPaymentPlan.expected_amount - models.RentPaymentPlan.paid_amount)).join(
        models.Tenancy
    ).filter(
        models.Tenancy.agency_id == agency_id,
        models.RentPaymentPlan.due_date < today,
        models.RentPaymentPlan.status != "paid"
    ).scalar() or 0.0

    # Rent Collected Total
    rent_collected_total = db.query(func.sum(models.RentPaymentPlan.paid_amount)).join(
        models.Tenancy
    ).filter(
        models.Tenancy.agency_id == agency_id
    ).scalar() or 0.0

    # Payments on Hold
    payments_on_hold = db.query(func.sum(models.Payout.net_amount)).join(
        models.Property
    ).filter(
        models.Property.agency_id == agency_id,
        models.Payout.status == "held"
    ).scalar() or 0.0
    
    # Pending Payouts (all types)
    pending_payouts_total = db.query(func.sum(models.Payout.net_amount)).join(
        models.Property
    ).filter(
        models.Property.agency_id == agency_id,
        models.Payout.status == "pending"
    ).scalar() or 0.0
    
    # Detailed Pending Payouts
    pending_agent_fees = db.query(func.sum(models.Payout.net_amount)).join(models.Property).filter(
        models.Property.agency_id == agency_id, models.Payout.status == "pending", models.Payout.payment_type == "agent_fee"
    ).scalar() or 0.0
    pending_maint_fees = db.query(func.sum(models.Payout.net_amount)).join(models.Property).filter(
        models.Property.agency_id == agency_id, models.Payout.status == "pending", models.Payout.payment_type == "service_provider"
    ).scalar() or 0.0
    pending_landlord_fees = db.query(func.sum(models.Payout.net_amount)).join(models.Property).filter(
        models.Property.agency_id == agency_id, models.Payout.status == "pending", models.Payout.payment_type == "landlord"
    ).scalar() or 0.0

    # Today's Financial Summary (Paid)
    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    today_agent_fees = db.query(func.sum(models.Payout.net_amount)).join(models.Property).filter(
        models.Property.agency_id == agency_id, models.Payout.status == "paid", models.Payout.payment_type == "agent_fee",
        models.Payout.updated_at >= today_start
    ).scalar() or 0.0
    today_maint_fees = db.query(func.sum(models.Payout.net_amount)).join(models.Property).filter(
        models.Property.agency_id == agency_id, models.Payout.status == "paid", models.Payout.payment_type == "service_provider",
        models.Payout.updated_at >= today_start
    ).scalar() or 0.0
    today_landlord_fees = db.query(func.sum(models.Payout.net_amount)).join(models.Property).filter(
        models.Property.agency_id == agency_id, models.Payout.status == "paid", models.Payout.payment_type == "landlord",
        models.Payout.updated_at >= today_start
    ).scalar() or 0.0

    # This Month Financial Summary (Paid)
    month_start = today_start.replace(day=1)
    month_agent_fees = db.query(func.sum(models.Payout.net_amount)).join(models.Property).filter(
        models.Property.agency_id == agency_id, models.Payout.status == "paid", models.Payout.payment_type == "agent_fee",
        models.Payout.updated_at >= month_start
    ).scalar() or 0.0
    month_maint_fees = db.query(func.sum(models.Payout.net_amount)).join(models.Property).filter(
        models.Property.agency_id == agency_id, models.Payout.status == "paid", models.Payout.payment_type == "service_provider",
        models.Payout.updated_at >= month_start
    ).scalar() or 0.0
    month_landlord_fees = db.query(func.sum(models.Payout.net_amount)).join(models.Property).filter(
        models.Property.agency_id == agency_id, models.Payout.status == "paid", models.Payout.payment_type == "landlord",
        models.Payout.updated_at >= month_start
    ).scalar() or 0.0
    
    # Due Properties List (Overdue, Due Today, Upcoming)
    from sqlalchemy.orm import joinedload
    from fastapi.encoders import jsonable_encoder
    
    due_plans_all = db.query(
        models.RentPaymentPlan,
        models.Tenancy,
        models.Property
    ).join(
        models.Tenancy, models.RentPaymentPlan.tenancy_id == models.Tenancy.id
    ).join(
        models.Property, models.Tenancy.property_id == models.Property.id
    ).filter(
        models.Tenancy.agency_id == agency_id,
        models.RentPaymentPlan.status != "paid"
    ).order_by(models.RentPaymentPlan.due_date.asc()).all()
    
    seen_props = set()
    due_prop_ids = []
    due_prop_details = {}
    
    for plan, tenancy, prop in due_plans_all:
        if prop.id not in seen_props:
            seen_props.add(prop.id)
            due_prop_ids.append(prop.id)
            if plan.due_date < today:
                status = "overdue"
            elif plan.due_date == today:
                status = "due_today"
            else:
                status = "upcoming"
            due_prop_details[prop.id] = {
                "status": status,
                "due_date": plan.due_date.isoformat(),
                "amount_due": float(plan.expected_amount - plan.paid_amount)
            }
            
    # Query properties individually to guarantee relations load perfectly
    props = db.query(models.Property).options(
        joinedload(models.Property.landlord),
        joinedload(models.Property.tenants),
        joinedload(models.Property.tenancies),
        joinedload(models.Property.assigned_manager)
    ).filter(models.Property.id.in_(due_prop_ids)).all() if due_prop_ids else []
    
    due_properties = []
    for p in props:
        p_dict = jsonable_encoder(p)
        p_dict["reference_number"] = f"REF-{p.id:04d}"
        
        # 1. Landlord Credit (Pending Payouts)
        pending_payouts = db.query(func.sum(models.Payout.net_amount)).filter(
            models.Payout.property_id == p.id,
            models.Payout.status == "pending"
        ).scalar() or 0.0
        p_dict["landlord_credit"] = float(pending_payouts)
        
        # 2. Landlord Debt (Outstanding Advances)
        if p.landlord_id:
            outstanding_advances = db.query(func.sum(models.LandlordAdvance.amount - models.LandlordAdvance.recovered_amount)).filter(
                models.LandlordAdvance.landlord_id == p.landlord_id,
                models.LandlordAdvance.status != "recovered"
            ).scalar() or 0.0
            p_dict["landlord_debt"] = float(outstanding_advances)
        else:
            p_dict["landlord_debt"] = 0.0
            
        # 3. Next Due Date
        next_due_date = None
        for tenancy in p.tenancies:
            if tenancy.status == "active":
                next_plan = db.query(models.RentPaymentPlan).filter(
                    models.RentPaymentPlan.tenancy_id == tenancy.id,
                    models.RentPaymentPlan.status != "paid"
                ).order_by(models.RentPaymentPlan.due_date.asc()).first()
                if next_plan:
                    next_due_date = next_plan.due_date.isoformat()
                break
        p_dict["next_due_date"] = next_due_date
        
        # 4. Tenant Credit (Overpaid/Pre-paid rent)
        tenant_credit = sum(float(t.credit_balance or 0) for t in p.tenants)
        p_dict["tenant_credit"] = tenant_credit
        
        # 5. Dashboard fields
        details = due_prop_details[p.id]
        p_dict["dashboard_status"] = details["status"]
        p_dict["status"] = details["status"]
        p_dict["amount_due"] = details["amount_due"]
        p_dict["due_date"] = details["due_date"]
        
        due_properties.append(p_dict)

    return {
        "total_properties": total_properties,
        "total_tenants": total_tenants,
        "total_landlords": total_landlords,
        "rent_expected_today": float(rent_expected_today),
        "rent_overdue": float(rent_overdue),
        "rent_collected_total": float(rent_collected_total),
        "payments_on_hold": float(payments_on_hold),
        "pending_payouts": float(pending_payouts_total),
        "pending_agent_fees": float(pending_agent_fees),
        "pending_maint_fees": float(pending_maint_fees),
        "pending_landlord_fees": float(pending_landlord_fees),
        "today_agent_fees": float(today_agent_fees),
        "today_maint_fees": float(today_maint_fees),
        "today_landlord_fees": float(today_landlord_fees),
        "month_agent_fees": float(month_agent_fees),
        "month_maint_fees": float(month_maint_fees),
        "month_landlord_fees": float(month_landlord_fees),
        "due_properties": due_properties
    }

# --- USER MANAGEMENT ---
@app.get("/users/")
def list_users(db: Session = Depends(get_db), current_user: models.User = Depends(check_role(["administrator", "admin"]))):
    return db.query(models.User).filter(models.User.agency_id == current_user.agency_id).all()

@app.post("/users/")
def create_sub_agent(data: UserCreate, db: Session = Depends(get_db), current_user: models.User = Depends(check_role(["administrator", "admin"]))):
    if db.query(models.User).filter(models.User.email == data.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    
    hashed_pwd = auth.get_password_hash(data.password)
    user = models.User(
        agency_id=current_user.agency_id,
        name=data.name,
        email=data.email,
        role=data.role,
        password_hash=hashed_pwd
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    
    log_activity(db, current_user.agency_id, current_user.id, "CREATE_USER", "user", user.id, f"Created {data.role}: {data.email}")
    return user

@app.put("/users/{user_id}")
def update_user_by_admin(
    user_id: int,
    data: UserUpdateAdmin,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(check_role(["administrator", "admin"]))
):
    user = db.query(models.User).filter(
        models.User.id == user_id, 
        models.User.agency_id == current_user.agency_id
    ).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Check email duplicate if changed
    if data.email != user.email:
        existing = db.query(models.User).filter(models.User.email == data.email).first()
        if existing:
            raise HTTPException(status_code=400, detail="Email already in use")
            
    user.name = data.name
    user.email = data.email
    user.role = data.role
    if data.password and data.password.strip():
        user.password_hash = auth.get_password_hash(data.password)
        
    db.commit()
    db.refresh(user)
    
    log_activity(db, current_user.agency_id, current_user.id, "UPDATE_USER", "user", user.id, f"Updated user: {user.email}")
    return user

@app.get("/properties/")
def read_properties(skip: int = 0, limit: int = 100, search: Optional[str] = None, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency_id = current_user.agency_id
    query = db.query(models.Property).options(
        joinedload(models.Property.landlord),
        joinedload(models.Property.tenants),
        joinedload(models.Property.tenancies),
        joinedload(models.Property.assigned_manager)
    ).filter(models.Property.agency_id == agency_id)
    
    # RBAC: Support Agents only see assigned properties
    if current_user.role == "support_agent":
        query = query.filter(models.Property.assigned_manager_id == current_user.id)
    
    if search:
        query = query.filter(
            models.Property.address_line_1.ilike(f"%{search}%") |
            models.Property.city.ilike(f"%{search}%") |
            models.Property.postcode.ilike(f"%{search}%") |
            models.Property.tenants.any(models.Tenant.first_name.ilike(f"%{search}%")) |
            models.Property.tenants.any(models.Tenant.last_name.ilike(f"%{search}%")) |
            models.Property.landlord.has(models.Landlord.first_name.ilike(f"%{search}%")) |
            models.Property.landlord.has(models.Landlord.last_name.ilike(f"%{search}%"))
        )
        
    raw_props = query.order_by(models.Property.created_at.desc()).offset(skip).limit(limit).all()
    
    seen_ids = set()
    props = []
    for p in raw_props:
        if p.id not in seen_ids:
            props.append(p)
            seen_ids.add(p.id)
    
    from fastapi.encoders import jsonable_encoder
    from sqlalchemy import func
    results = []
    
    for p in props:
        p_dict = jsonable_encoder(p)
        p_dict["reference_number"] = f"REF-{p.id:04d}"
        
        # 1. Landlord Credit (Pending Payouts)
        pending_payouts = db.query(func.sum(models.Payout.net_amount)).filter(
            models.Payout.property_id == p.id,
            models.Payout.status == "pending"
        ).scalar() or 0.0
        p_dict["landlord_credit"] = float(pending_payouts)
        
        # 2. Landlord Debt (Outstanding Advances)
        if p.landlord_id:
            outstanding_advances = db.query(func.sum(models.LandlordAdvance.amount - models.LandlordAdvance.recovered_amount)).filter(
                models.LandlordAdvance.landlord_id == p.landlord_id,
                models.LandlordAdvance.status != "recovered"
            ).scalar() or 0.0
            p_dict["landlord_debt"] = float(outstanding_advances)
        else:
            p_dict["landlord_debt"] = 0.0
            
        # 3. Next Due Date
        next_due_date = None
        for tenancy in p.tenancies:
            if tenancy.status == "active":
                next_plan = db.query(models.RentPaymentPlan).filter(
                    models.RentPaymentPlan.tenancy_id == tenancy.id,
                    models.RentPaymentPlan.status != "paid"
                ).order_by(models.RentPaymentPlan.due_date.asc()).first()
                if next_plan:
                    next_due_date = next_plan.due_date.isoformat()
                break
        p_dict["next_due_date"] = next_due_date
        
        # 4. Tenant Credit (Overpaid/Pre-paid rent)
        tenant_credit = sum(float(t.credit_balance or 0) for t in p.tenants)
        p_dict["tenant_credit"] = tenant_credit
        
        results.append(p_dict)
        
    return results

@app.post("/properties/")
def create_property(prop: PropertyCreate, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    count = db.query(models.Property).count()
    ref = f"PROP-{1001 + count}"
    db_prop = models.Property(**prop.model_dump(), agency_id=agency_id, reference_number=ref)
    db.add(db_prop)
    if data.deposit_amount and data.deposit_amount > 0:
        tenants = db.query(models.Tenant).filter(models.Tenant.property_id == db_prop.id).all()
        if tenants:
            from decimal import Decimal
            if tenants[0].deposit_balance is None:
                tenants[0].deposit_balance = 0
            tenants[0].deposit_balance += Decimal(str(data.deposit_amount))
    
    db.commit()
    db.refresh(db_prop)
    return db_prop

@app.post("/properties/advanced-setup/")
def advanced_property_setup(data: AdvancedPropertySetup, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency_id = current_user.agency_id
    from datetime import datetime
    start_date = datetime.strptime(data.start_date, "%Y-%m-%d").date()
    
    # 1. Resolve Landlord
    ll_id = data.landlord_id
    if not ll_id and data.landlord_first_name and data.landlord_last_name:
        db_ll = models.Landlord(
            agency_id=agency_id, 
            first_name=data.landlord_first_name, 
            last_name=data.landlord_last_name,
            co=data.landlord_co,
            address_line_1=data.landlord_address_line_1,
            address_line_2=data.landlord_address_line_2,
            city=data.landlord_city,
            county=data.landlord_county,
            postcode=data.landlord_postcode,
            email=data.landlord_email,
            phone=data.landlord_phone
        )
        db.add(db_ll)
        db.flush()
        ll_id = db_ll.id
        
    if not ll_id: raise HTTPException(status_code=400, detail="Landlord is required")
        
    # 2. Create Property
    db_prop = models.Property(
        agency_id=agency_id, 
        landlord_id=ll_id, 
        room_no=data.room_no,
        address_line_1=data.address_line_1, 
        address_line_2=data.address_line_2,
        city=data.city, 
        county=data.county,
        postcode=data.postcode,
        assigned_manager_id=data.assigned_manager_id
    )
    db.add(db_prop)
    db.flush()
    
    # 3. Create Tenancy
    db_tenancy = models.Tenancy(
        agency_id=agency_id, property_id=db_prop.id,
        rent_amount=data.rent_amount, due_day=data.due_day, start_date=start_date,
        management_fee_percentage=data.management_fee_percentage
    )
    db.add(db_tenancy)
    db.flush()
    
    # 3b. Generate 12-Month Payment Plan
    from dateutil.relativedelta import relativedelta
    for i in range(12):
        plan_date = start_date + relativedelta(months=i)
        # Ensure it falls on the due_day
        # (Simplified: just set the day to due_day of that month)
        try:
            due_date = plan_date.replace(day=data.due_day)
        except ValueError:
            # Handle month end (e.g. 31st)
            due_date = (plan_date + relativedelta(months=1)).replace(day=1) - timedelta(days=1)
            
        db_plan = models.RentPaymentPlan(
            tenancy_id=db_tenancy.id,
            due_date=due_date,
            expected_amount=data.rent_amount,
            paid_amount=0,
            status="unpaid"
        )
        db.add(db_plan)

    
    # 4. Resolve Tenants (link them to property)
    # Existing
    for t_id in data.existing_tenant_ids:
        t = db.query(models.Tenant).filter(models.Tenant.id == t_id, models.Tenant.agency_id == agency_id).first()
        if t: t.property_id = db_prop.id
    # New
    for nt in data.new_tenants:
        db_tenant = models.Tenant(
            agency_id=agency_id, 
            first_name=nt.first_name, 
            last_name=nt.last_name, 
            address_line_1=nt.address_line_1,
            address_line_2=nt.address_line_2,
            city=nt.city,
            county=nt.county,
            postcode=nt.postcode,
            email=nt.email,
            phone=nt.phone,
            property_id=db_prop.id
        )
        db.add(db_tenant)
        
    db.commit()
    db.refresh(db_prop)
    
    log_activity(db, agency_id, current_user.id, "CREATE_PROPERTY", "property", db_prop.id, f"Advanced setup completed for {db_prop.address_line_1}")
    return {"message": "Setup complete", "property_id": db_prop.id}

@app.put("/properties/{prop_id}")
def update_property(prop_id: int, prop: PropertyCreate, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    db_prop = db.query(models.Property).filter(models.Property.id == prop_id, models.Property.agency_id == agency_id).first()
    if not db_prop: raise HTTPException(status_code=404, detail="Property not found")
    # Manually update fields to ensure all new ones are covered
    db_prop.room_no = prop.room_no
    db_prop.address_line_1 = prop.address_line_1
    db_prop.address_line_2 = prop.address_line_2
    db_prop.city = prop.city
    db_prop.county = prop.county
    db_prop.postcode = prop.postcode
    db_prop.landlord_id = prop.landlord_id
    if data.deposit_amount and data.deposit_amount > 0:
        tenants = db.query(models.Tenant).filter(models.Tenant.property_id == db_prop.id).all()
        if tenants:
            from decimal import Decimal
            if tenants[0].deposit_balance is None:
                tenants[0].deposit_balance = 0
            tenants[0].deposit_balance += Decimal(str(data.deposit_amount))
    
    db.commit()
    db.refresh(db_prop)
    return db_prop

@app.get("/landlords/")
def read_landlords(skip: int = 0, limit: int = 100, search: Optional[str] = None, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    query = db.query(models.Landlord).filter(models.Landlord.agency_id == agency_id)
    if search:
        query = query.filter(
            models.Landlord.first_name.ilike(f"%{search}%") | 
            models.Landlord.last_name.ilike(f"%{search}%") |
            models.Landlord.email.ilike(f"%{search}%") |
            models.Landlord.phone.ilike(f"%{search}%")
        )
    landlords = query.order_by(models.Landlord.created_at.desc()).offset(skip).limit(limit).all()
    
    from fastapi.encoders import jsonable_encoder
    from sqlalchemy import func
    results = []
    
    for l in landlords:
        l_dict = jsonable_encoder(l)
        outstanding = db.query(func.sum(models.LandlordAdvance.amount - models.LandlordAdvance.recovered_amount)).filter(
            models.LandlordAdvance.landlord_id == l.id,
            models.LandlordAdvance.status == "outstanding"
        ).scalar() or 0.0
        
        l_dict['outstanding_advance'] = float(outstanding)
        results.append(l_dict)
        
    return results
@app.post("/landlords/")
def create_landlord(landlord: LandlordCreate, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    db_landlord = models.Landlord(**landlord.model_dump(), agency_id=agency_id)
    db.add(db_landlord)
    db.commit()
    db.refresh(db_landlord)
    return db_landlord

@app.put("/landlords/{ll_id}")
def update_landlord(ll_id: int, landlord: LandlordCreate, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    db_ll = db.query(models.Landlord).filter(models.Landlord.id == ll_id, models.Landlord.agency_id == agency_id).first()
    if not db_ll: raise HTTPException(status_code=404, detail="Landlord not found")
    db_ll.first_name = landlord.first_name
    db_ll.last_name = landlord.last_name
    db_ll.co = landlord.co
    db_ll.address_line_1 = landlord.address_line_1
    db_ll.address_line_2 = landlord.address_line_2
    db_ll.city = landlord.city
    db_ll.county = landlord.county
    db_ll.postcode = landlord.postcode
    db_ll.email = landlord.email
    db_ll.phone = landlord.phone
    db.commit()
    db.refresh(db_ll)
    return db_ll

@app.get("/tenants/")
def read_tenants(skip: int = 0, limit: int = 100, search: Optional[str] = None, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    query = db.query(models.Tenant).filter(models.Tenant.agency_id == agency_id)
    if search:
        query = query.filter(
            models.Tenant.first_name.ilike(f"%{search}%") | 
            models.Tenant.last_name.ilike(f"%{search}%") |
            models.Tenant.email.ilike(f"%{search}%") |
            models.Tenant.phone.ilike(f"%{search}%")
        )
    return query.order_by(models.Tenant.created_at.desc()).offset(skip).limit(limit).all()

@app.post("/tenants/")
def create_tenant(tenant: TenantCreate, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    db_tenant = models.Tenant(**tenant.model_dump(), agency_id=agency_id)
    db.add(db_tenant)
    db.commit()
    db.refresh(db_tenant)
    return db_tenant

@app.put("/tenants/{t_id}")
def update_tenant(t_id: int, tenant: TenantCreate, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    db_t = db.query(models.Tenant).filter(models.Tenant.id == t_id, models.Tenant.agency_id == agency_id).first()
    if not db_t: raise HTTPException(status_code=404, detail="Tenant not found")
    db_t.first_name = tenant.first_name
    db_t.last_name = tenant.last_name
    db_t.address_line_1 = tenant.address_line_1
    db_t.address_line_2 = tenant.address_line_2
    db_t.city = tenant.city
    db_t.county = tenant.county
    db_t.postcode = tenant.postcode
    db_t.email = tenant.email
    db_t.phone = tenant.phone
    db.commit()
    db.refresh(db_t)
    return db_t

@app.post("/tenancies/")
def create_tenancy(tenancy: TenancyCreate, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    from datetime import datetime
    start_date = datetime.strptime(tenancy.start_date, "%Y-%m-%d").date()
    db_tenancy = models.Tenancy(
        agency_id=agency_id,
        property_id=tenancy.property_id,
        rent_amount=tenancy.rent_amount,
        due_day=tenancy.due_day,
        start_date=start_date,
        management_fee_percentage=tenancy.management_fee_percentage
    )
    db.add(db_tenancy)
    db.commit()
    
    if tenancy.deposit_amount and tenancy.deposit_amount > 0:
        tenants = db.query(models.Tenant).filter(models.Tenant.property_id == tenancy.property_id).all()
        if tenants:
            from decimal import Decimal
            if tenants[0].deposit_balance is None:
                tenants[0].deposit_balance = 0
            tenants[0].deposit_balance += Decimal(str(tenancy.deposit_amount))
            db.commit()
            
    db.refresh(db_tenancy)
    return db_tenancy

from app.agents.router import RouterAgent, UserContext
from app.agents.security_validator import SecurityValidator

class CommandRequest(BaseModel):
    transcript: str

@app.post("/api/agent/command")
async def process_voice_command(request: CommandRequest, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """
    Receives a transcribed voice command, builds UserContext, and routes via RouterAgent.
    """
    agency_id = current_user.agency_id
    
    context = UserContext(
        user_id=current_user.id,
        name=current_user.name,
        role=current_user.role,
        agency_id=agency_id
    )
    
    router = RouterAgent(db)
    system_prompt = router.build_system_prompt(context)
    routing_decision = router.route_request(context, request.transcript)
    
    # Check permissions example (SecurityValidator)
    # If the user is trying to execute a modifying action, validate it here.
    # For now, we simulate sending to the target agent.
    target_agent = routing_decision["target_agent"]
    
    if target_agent == "communications_agent":
        from app.agents.communications_agent import CommunicationsAgent
        agent = CommunicationsAgent(db, context)
        result = agent.handle_request(request.transcript)
    elif target_agent == "compliance_agent":
        from app.agents.compliance_agent import ComplianceAgent
        agent = ComplianceAgent(db, context)
        result = agent.handle_request(request.transcript)
    elif target_agent == "analytics_agent":
        from app.agents.analytics_agent import AnalyticsAgent
        agent = AnalyticsAgent(db, context)
        result = agent.handle_request(request.transcript)
    else:
        # Fallback to existing Gemini Logic for Operations / Ledger
        import app.agents.gemini_agent as gemini
        gemini_result = await gemini.gemini_core.parse_voice_command(request.transcript)
        
        if target_agent == "vision_agent":
            action_taken = routing_decision.get("action_plan", "To process an invoice or receipt, please click the Scan Invoice button.")
        elif target_agent == "finance_agent":
            action_taken = routing_decision.get("action_plan", "To allocate a bank statement, please use the Allocate CSV button.")
        else:
            action_taken = routing_decision.get("action_plan", f"Action processed by {target_agent}. Intent: {gemini_result.get('intent', 'unknown')}.")
            
        result = {
            "status": "success", 
            "parsed_action": gemini_result, 
            "agent": target_agent, 
            "action_taken": action_taken,
            "reasoning": routing_decision.get("reasoning", ""),
            "ui_action": routing_decision.get("ui_action", "none")
        }

    return result

@app.post("/api/agent/vision/invoice")
async def process_invoice_vision(file: UploadFile = File(...), agency_id: int = Depends(get_agency_id)):
    """
    Receives an image of an invoice from the Flutter app and extracts the data.
    """
    contents = await file.read()
    result = await gemini_core.parse_invoice_vision(contents, file.content_type)
    return {"status": "success", "extracted_data": result}

@app.post("/api/agent/allocate")
async def auto_allocate_bank_statement(file: UploadFile = File(...), db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    """
    Receives a CSV bank statement and uses Gemini to auto-allocate payments to tenancies.
    """
    contents = await file.read()
    csv_text = contents.decode('utf-8')
    
    # 1. Gather context: All active tenancies for this agency
    tenancies = db.query(models.Tenancy, models.Tenant, models.Property).join(
        models.Property, models.Tenancy.property_id == models.Property.id
    ).join(
        models.Tenant, models.Tenancy.agency_id == models.Tenant.agency_id # Simplified join for MVP context
    ).filter(
        models.Tenancy.agency_id == agency_id,
        models.Tenancy.status == 'active'
    ).limit(50).all() # Limit to 50 for prompt size in MVP
    
    context_lines = []
    for ten, tnt, prop in tenancies:
        context_lines.append(f"Tenancy ID: {ten.id} | Expected Rent: £{ten.rent_amount} | Tenant Name: {tnt.first_name} {tnt.last_name} | Property: {prop.address_line_1}")
    
    context_str = "\n".join(context_lines)
    
    # 2. Call the Agent
    result = await allocator_agent.auto_allocate(csv_text, context_str)
    
    # 3. (Future Step) Automatically call LedgerEngine.record_rent_payment for 'high' confidence matches.
    
    return {"status": "success", "reconciliation_report": result}

@app.post("/tenants/{t_id}/upload-id")
async def upload_tenant_id(
    t_id: int, 
    file: UploadFile = File(...), 
    use_ai: bool = Query(False),
    db: Session = Depends(get_db), 
    agency_id: int = Depends(get_agency_id)
):
    db_t = db.query(models.Tenant).filter(models.Tenant.id == t_id, models.Tenant.agency_id == agency_id).first()
    if not db_t: raise HTTPException(status_code=404, detail="Tenant not found")
    
    # Save file (In production use S3/Supabase Storage, for local MVP we'll save bytes or mock)
    # For now we'll just process it with AI if requested and update the status
    contents = await file.read()
    
    if use_ai:
        from .agents.gemini_agent import gemini_core
        full_name = f"{db_t.first_name} {db_t.last_name}"
        full_addr = f"{db_t.address_line_1}, {db_t.city}, {db_t.postcode}"
        
        result = await gemini_core.verify_tenant_id(contents, file.content_type, full_name, full_addr)
        
        db_t.id_verification_status = "verified" if result.get("verified") else "rejected"
        db_t.id_verification_notes = result.get("reasoning", "AI verification failed")
    else:
        db_t.id_verification_status = "pending"
        db_t.id_verification_notes = "Document uploaded. Manual review required."
    
    # Save a mock URL
    db_t.proof_of_id_url = f"uploads/id_{t_id}_{file.filename}"
    
    db.commit()
    db.refresh(db_t)
    return {"status": db_t.id_verification_status, "notes": db_t.id_verification_notes}

@app.put("/tenants/{t_id}/verify-status")
def update_tenant_verify_status(
    t_id: int, 
    status: str, 
    notes: Optional[str] = None, 
    db: Session = Depends(get_db), 
    agency_id: int = Depends(get_agency_id)
):
    db_t = db.query(models.Tenant).filter(models.Tenant.id == t_id, models.Tenant.agency_id == agency_id).first()
    if not db_t: raise HTTPException(status_code=404, detail="Tenant not found")
    
    db_t.id_verification_status = status
    if notes: db_t.id_verification_notes = notes
    
    db.commit()
    db.refresh(db_t)
    return db_t


def recalculate_pending_payouts_for_property(property_id: int, db):
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
def list_bank_entries(db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    return db.query(models.BankEntry).filter(models.BankEntry.agency_id == agency_id).order_by(models.BankEntry.date.desc()).all()

@app.post("/finance/bank-entries/")
def create_bank_entry(data: BankEntryCreate, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    entry = models.BankEntry(**data.model_dump(), agency_id=agency_id)
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry

@app.get("/finance/expected-payments/")
def list_expected_payments(db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    return db.query(models.Tenancy).options(joinedload(models.Tenancy.property), joinedload(models.Tenancy.property).joinedload(models.Property.tenants)).filter(models.Tenancy.agency_id == agency_id, models.Tenancy.status == "active").all()

@app.post("/finance/allocate/")
def allocate_payment(req: RentAllocationRequest, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency_id = current_user.agency_id
    entry = db.query(models.BankEntry).filter(models.BankEntry.id == req.bank_entry_id, models.BankEntry.agency_id == agency_id).first()
    tenancy = db.query(models.Tenancy).options(joinedload(models.Tenancy.property), joinedload(models.Tenancy.property).joinedload(models.Property.landlord)).filter(models.Tenancy.id == req.tenancy_id, models.Tenancy.agency_id == agency_id).first()
    
    if not entry or not tenancy:
        raise HTTPException(status_code=404, detail="Entry or Tenancy not found")
        
    amount_dec = Decimal(str(req.amount))
    if entry.allocated_amount + amount_dec > entry.amount:
        raise HTTPException(status_code=400, detail="Allocation exceeds entry amount")

    # 1. Update Bank Entry
    entry.allocated_amount += amount_dec
    if entry.allocated_amount >= entry.amount:
        entry.status = "allocated"
    else:
        entry.status = "partially_allocated"

    # 2. Update Payment Plan
    m_date = datetime.strptime(req.month_date, "%Y-%m-%d").date()
    plan = db.query(models.RentPaymentPlan).filter(models.RentPaymentPlan.tenancy_id == tenancy.id, models.RentPaymentPlan.due_date == m_date).first()
    if not plan:
        plan = models.RentPaymentPlan(tenancy_id=tenancy.id, due_date=m_date, expected_amount=tenancy.rent_amount)
        db.add(plan)
    
    plan.paid_amount += amount_dec
    if plan.paid_amount >= plan.expected_amount:
        plan.status = "paid"
    else:
        plan.status = "partially_paid"

    # 3. DEDUCTION ENGINE
    prop = tenancy.property
    landlord = prop.landlord
    agency = db.query(models.Agency).filter(models.Agency.id == agency_id).first()
    
    gross = amount_dec
    base_fee = (gross * (Decimal(str(tenancy.management_fee_percentage)) / 100)) if tenancy.management_fee_percentage else Decimal('0')
    fee_vat = Decimal('0')
    if getattr(agency, 'vat_enabled', False) and getattr(agency, 'vat_registered', False):
        fee_vat = base_fee * (Decimal(str(getattr(agency, 'default_vat_rate', 0.0))) / 100)
    fee = base_fee + fee_vat
    
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
    recalculate_pending_payouts_for_property(prop.id, db)
    
    # 5. Update Tenant Credit if necessary (if full month paid and surplus remains)
    # For now, just log it.
    
    db.commit()
    log_activity(db, agency_id, current_user.id, "ALLOCATE_RENT", "tenancy", tenancy.id, f"Allocated £{req.amount} for {req.month_date}. Net payout: £{net}")
    return {"message": "Allocation successful", "net_payout": float(net)}

@app.post("/finance/advances/")
def issue_advance(data: LandlordAdvanceCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    adv = models.LandlordAdvance(**data.model_dump(), status="outstanding")
    db.add(adv)
    db.commit()
    db.refresh(adv)
    log_activity(db, current_user.agency_id, current_user.id, "ISSUE_ADVANCE", "landlord", data.landlord_id, f"Issued advance of £{data.amount}")
    return adv

from sqlalchemy import func

@app.get("/finance/payouts/summary")
def get_payouts_summary(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency_id = current_user.agency_id
    
    # Base query for payouts in this agency
    base_query = db.query(models.Payout).join(models.Property).filter(models.Property.agency_id == agency_id)
    
    pending_landlord = base_query.filter(models.Payout.payment_type == 'landlord', models.Payout.status == 'pending').with_entities(func.sum(models.Payout.net_amount)).scalar() or 0
    pending_service = base_query.filter(models.Payout.payment_type == 'service_provider', models.Payout.status == 'pending').with_entities(func.sum(models.Payout.net_amount)).scalar() or 0
    pending_agent = base_query.filter(models.Payout.payment_type == 'agent_fee', models.Payout.status == 'pending').with_entities(func.sum(models.Payout.net_amount)).scalar() or 0
    
    # Paid this month (approximate by status = 'paid' and updated_at recent, but we can just use status 'paid')
    # Or for simplicity, all 'paid'
    paid_total = base_query.filter(models.Payout.status == 'paid').with_entities(func.sum(models.Payout.net_amount)).scalar() or 0
    outstanding_total = pending_landlord + pending_service + pending_agent

    return {
        "pending_landlord": pending_landlord,
        "pending_service_provider": pending_service,
        "pending_agent_fee": pending_agent,
        "paid_this_month": paid_total, # Assuming all paid for now
        "total_outstanding": outstanding_total
    }

@app.get("/finance/payouts/")
def list_all_payouts(
    payment_type: str = None,
    status: str = None,
    timeframe: str = None,
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    agency_id = current_user.agency_id
    query = db.query(models.Payout).options(
        joinedload(models.Payout.property), 
        joinedload(models.Payout.landlord),
        joinedload(models.Payout.service_provider)
    ).filter(models.Payout.property.has(agency_id=agency_id))
    
    if payment_type:
        query = query.filter(models.Payout.payment_type == payment_type)
    if status:
        # pending_distribution is conceptually 'pending' in the DB
        if status == 'Pending Distribution':
            query = query.filter(models.Payout.status == 'pending')
        else:
            query = query.filter(models.Payout.status == status.lower())
    
    if timeframe == 'today':
        today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        query = query.filter(models.Payout.updated_at >= today_start)
    elif timeframe == 'this_month':
        today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        month_start = today_start.replace(day=1)
        query = query.filter(models.Payout.updated_at >= month_start)
        
    payouts = query.order_by(models.Payout.created_at.desc()).all()
    
    # We also need tenant data for the frontend table
    # It's better to eager load tenants, but since we didn't add the relationship easily, 
    # we can just attach it manually or assume the frontend fetches it, or load it here.
    result = []
    for p in payouts:
        p_dict = {
            "id": p.id,
            "payment_type": p.payment_type,
            "status": p.status,
            "net_amount": float(p.net_amount),
            "updated_at": p.updated_at.isoformat() if p.updated_at else (p.created_at.isoformat() if p.created_at else None),
            "created_at": p.created_at.isoformat() if p.created_at else None,
            "property_name": f"{p.property.address_line_1}, {p.property.city}" if p.property else "Unknown",
            "property_ref": p.property.room_no or "N/A" if p.property else "N/A",
            "landlord_name": f"{p.property.landlord.first_name} {p.property.landlord.last_name}" if p.property and p.property.landlord else "N/A",
            "recipient_name": p.recipient_name or (f"{p.service_provider.company_name}" if p.service_provider else "Agency"),
        }
        # Get tenant name
        tenant_name = "N/A"
        if p.property and p.property.tenants:
            tenant = p.property.tenants[0]
            tenant_name = f"{tenant.first_name} {tenant.last_name}"
        p_dict["tenant_name"] = tenant_name
        result.append(p_dict)
        
    return result

from pydantic import BaseModel
class PayoutStatusUpdate(BaseModel):
    status: str
    reference_number: str = None

@app.post("/finance/payouts/{payout_id}/status")
def update_payout_status(payout_id: int, req: PayoutStatusUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    payout = db.query(models.Payout).filter(models.Payout.id == payout_id).first()
    if not payout:
        raise HTTPException(status_code=404, detail="Payout not found")
        
    payout.status = req.status
    if req.reference_number:
        payout.reference_number = req.reference_number
    db.commit()
    return {"status": "success"}

@app.get("/tenancies/{tenancy_id}/payment-plan/")
def get_payment_plan(tenancy_id: int, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    plans = db.query(models.RentPaymentPlan).options(joinedload(models.RentPaymentPlan.payouts)).filter(models.RentPaymentPlan.tenancy_id == tenancy_id).order_by(models.RentPaymentPlan.due_date.asc()).all()
    
    if not plans:
        return []
        
    property_id = db.query(models.Tenancy).filter(models.Tenancy.id == tenancy_id).first().property_id
    maints = db.query(models.Maintenance).options(joinedload(models.Maintenance.service_provider)).filter(models.Maintenance.property_id == property_id).all()
    
    from datetime import datetime, timedelta
    
    result = []
    
    for plan in plans:
        if plan.due_date.month == 12:
            end_of_month = plan.due_date.replace(year=plan.due_date.year+1, month=1, day=1) - timedelta(days=1)
        else:
            end_of_month = plan.due_date.replace(month=plan.due_date.month+1, day=1) - timedelta(days=1)
        start_of_month = plan.due_date.replace(day=1)
        
        month_maints = [m for m in maints if start_of_month <= m.maintenance_date.date() <= end_of_month]
        expected_maintenance = sum(float(m.cost) for m in month_maints)
        
        maint_records = [{
            "id": m.id,
            "cost": float(m.cost),
            "actual_cost": float(m.actual_cost) if getattr(m, 'actual_cost', None) is not None else float(m.cost),
            "maintenance_date": m.maintenance_date.isoformat(),
            "maintenance_type": m.maintenance_type,
            "service_provider_name": m.service_provider.company_name if m.service_provider else "N/A"
        } for m in month_maints]
        
        plan_dict = {
            "id": plan.id,
            "tenancy_id": plan.tenancy_id,
            "due_date": plan.due_date.isoformat(),
            "expected_amount": float(plan.expected_amount),
            "paid_amount": float(plan.paid_amount),
            "status": plan.status,
            "created_at": plan.created_at.isoformat() if plan.created_at else None,
            "expected_maintenance": expected_maintenance,
            "maintenance_records": maint_records,
            "payouts": [{
                "id": p.id,
                "landlord_id": p.landlord_id,
                "property_id": p.property_id,
                "rent_allocation_id": p.rent_allocation_id,
                "payment_plan_id": p.payment_plan_id,
                "gross_amount": float(p.gross_amount),
                "management_fee": float(p.management_fee),
                "maintenance_cost": float(p.maintenance_cost),
                "advance_recovery": float(p.advance_recovery),
                "deductions_total": float(p.deductions_total),
                "net_amount": float(p.net_amount),
                "status": p.status,
                "created_at": p.created_at.isoformat() if p.created_at else None
            } for p in plan.payouts]
        }
        result.append(plan_dict)
        
    return result


@app.post("/finance/quick-collect/")
def quick_collect(tenancy_id: int, amount: float, reference: str = "Manual Collection", db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency_id = current_user.agency_id
    tenancy = db.query(models.Tenancy).options(joinedload(models.Tenancy.property), joinedload(models.Tenancy.property).joinedload(models.Property.landlord)).filter(models.Tenancy.id == tenancy_id, models.Tenancy.agency_id == agency_id).first()
    if not tenancy: raise HTTPException(status_code=404, detail="Tenancy not found")
    
    amount_dec = Decimal(str(amount))
    remaining_to_allocate = amount_dec
    
    # 1. Create a Bank Entry for this manual collection to keep records balanced
    entry = models.BankEntry(
        agency_id=agency_id,
        date=datetime.now().date(),
        reference=f"Manual: {reference}",
        amount=amount_dec,
        allocated_amount=amount_dec,
        status="allocated"
    )
    db.add(entry)
    db.flush() # Get entry ID
    
    # 2. FIFO Allocation across Payment Plans
    plans = db.query(models.RentPaymentPlan).filter(
        models.RentPaymentPlan.tenancy_id == tenancy_id,
        models.RentPaymentPlan.status != "paid"
    ).order_by(models.RentPaymentPlan.due_date.asc()).all()
    
    # CRITICAL: If no plans exist, generate them now (Self-healing)
    if not plans:
        # Check if ANY plans exist at all (maybe they are all paid?)
        any_plans = db.query(models.RentPaymentPlan).filter(models.RentPaymentPlan.tenancy_id == tenancy_id).first()
        if not any_plans:
            from dateutil.relativedelta import relativedelta
            start_date = tenancy.start_date
            for i in range(12):
                plan_date = start_date + relativedelta(months=i)
                try:
                    due_date = plan_date.replace(day=tenancy.due_day)
                except ValueError:
                    due_date = (plan_date + relativedelta(months=1)).replace(day=1) - timedelta(days=1)
                    
                db_plan = models.RentPaymentPlan(
                    tenancy_id=tenancy_id,
                    due_date=due_date,
                    expected_amount=tenancy.rent_amount,
                    paid_amount=0,
                    status="unpaid"
                )
                db.add(db_plan)
            db.flush()
            # Re-fetch plans
            plans = db.query(models.RentPaymentPlan).filter(
                models.RentPaymentPlan.tenancy_id == tenancy_id,
                models.RentPaymentPlan.status != "paid"
            ).order_by(models.RentPaymentPlan.due_date.asc()).all()

    
    agency = db.query(models.Agency).filter(models.Agency.id == agency_id).first()
    prop = tenancy.property
    landlord = prop.landlord
    total_net = Decimal('0')

    for plan in plans:
        if remaining_to_allocate <= 0: break
        
        needed = plan.expected_amount - plan.paid_amount
        to_pay = min(needed, remaining_to_allocate)
        
        plan.paid_amount += to_pay
        remaining_to_allocate -= to_pay
        
        if plan.paid_amount >= plan.expected_amount:
            plan.status = "paid"
        else:
            plan.status = "partially_paid"
            
        # --- PER-MONTH BREAKDOWN ---
        gross_for_month = to_pay
        base_fee = (gross_for_month * (Decimal(str(tenancy.management_fee_percentage)) / 100)) if tenancy.management_fee_percentage else Decimal('0')
        fee_vat = Decimal('0')
        if getattr(agency, 'vat_enabled', False) and getattr(agency, 'vat_registered', False):
            fee_vat = base_fee * (Decimal(str(getattr(agency, 'default_vat_rate', 0.0))) / 100)
        fee = base_fee + fee_vat
        
        maint_deduction = Decimal('0')
            
        # Recovery (Global)
        adv_recovery = Decimal('0')
        advance = db.query(models.LandlordAdvance).filter(models.LandlordAdvance.landlord_id == landlord.id, models.LandlordAdvance.status == "outstanding").first()
        if advance:
            adv_recovery = min(advance.amount - advance.recovered_amount, gross_for_month - fee)
            advance.recovered_amount += adv_recovery
            if advance.recovered_amount >= advance.amount:
                advance.status = "recovered"
        
        net = gross_for_month - fee - adv_recovery
        
        # A. Landlord Payout
        payout_ll = models.Payout(
            payment_type="landlord",
            recipient_name=f"{landlord.first_name} {landlord.last_name}",
            landlord_id=landlord.id,
            property_id=prop.id,
            rent_allocation_id=entry.id,
            payment_plan_id=plan.id,
            gross_amount=gross_for_month,
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
        recalculate_pending_payouts_for_property(prop.id, db)
        
        # Net will be recalculated in DB, we should refresh it if we want total_net
        db.refresh(payout_ll)
        total_net += payout_ll.net_amount

    db.commit()
    log_activity(db, agency_id, current_user.id, "QUICK_COLLECT", "tenancy", tenancy.id, f"Collected £{amount}. Net payout: £{total_net}")
    return {"message": "Rent collected and allocated", "net_payout": float(total_net)}

@app.get("/finance/landlord-payouts/")
def get_grouped_landlord_payouts(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency_id = current_user.agency_id
    
    # Get all pending payouts for the agency
    pending_payouts = db.query(models.Payout).options(
        joinedload(models.Payout.property),
        joinedload(models.Payout.landlord)
    ).filter(
        models.Payout.status == "pending"
    ).join(models.Property).filter(models.Property.agency_id == agency_id).all()
    
    grouped = {}
    for p in pending_payouts:
        lid = p.landlord_id
        if lid not in grouped:
            grouped[lid] = {
                "landlord_id": lid,
                "landlord_name": f"{p.landlord.first_name} {p.landlord.last_name}",
                "email": p.landlord.email,
                "total_gross": 0.0,
                "total_fees": 0.0,
                "total_maintenance": 0.0,
                "total_advance_recovery": 0.0,
                "total_net": 0.0,
                "payout_ids": [],
                "properties": set()
            }
        
        grouped[lid]["total_gross"] += float(p.gross_amount)
        grouped[lid]["total_fees"] += float(p.management_fee)
        grouped[lid]["total_maintenance"] += float(p.maintenance_cost)
        grouped[lid]["total_advance_recovery"] += float(p.advance_recovery)
        grouped[lid]["total_net"] += float(p.net_amount)
        grouped[lid]["payout_ids"].append(p.id)
        grouped[lid]["properties"].add(p.property.address_line_1)
        
    results = []
    for lid, data in grouped.items():
        data["properties"] = list(data["properties"])
        results.append(data)
        
    return results

@app.post("/finance/landlord-payouts/execute/")
def execute_landlord_payout(data: dict, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency_id = current_user.agency_id
    landlord_id = data.get("landlord_id")
    if not landlord_id:
        raise HTTPException(status_code=400, detail="landlord_id is required")
        
    payouts = db.query(models.Payout).options(joinedload(models.Payout.property), joinedload(models.Payout.landlord)).filter(
        models.Payout.landlord_id == landlord_id,
        models.Payout.status == "pending",
        models.Property.agency_id == agency_id
    ).all()
    
    if not payouts:
        return {"message": "No pending payouts found for this landlord."}
        
    total_net = sum([p.net_amount for p in payouts])
    
    properties = set()
    property_ids = set()
    total_gross = 0.0
    total_management = 0.0
    total_maintenance = 0.0
    total_adv = 0.0
    maint_records = []
    landlord_name = ""
    landlord_email = ""
    
    for p in payouts:
        if not landlord_name:
            landlord_name = f"{p.landlord.first_name} {p.landlord.last_name}"
            landlord_email = p.landlord.email
            
        properties.add(p.property.address_line_1)
        property_ids.add(p.property_id)
        total_gross += float(p.gross_amount)
        total_management += float(p.management_fee)
        total_maintenance += float(p.maintenance_cost)
        total_adv += float(p.advance_recovery)
        
        p.status = "paid"
        
        if p.maintenance_cost > 0:
            maints = db.query(models.Maintenance).options(joinedload(models.Maintenance.service_provider)).filter(
                models.Maintenance.property_id == p.property_id,
                models.Maintenance.deducted_amount > 0
            ).all()
            for m in maints:
                provider_name = m.service_provider.company_name if m.service_provider else "Unknown Provider"
                # Only add if we haven't added this specific record yet for this batch
                if not any(x['type'] == m.maintenance_type and x['cost'] == float(m.deducted_amount) for x in maint_records):
                    maint_records.append({
                        "provider": provider_name,
                        "type": m.maintenance_type,
                        "cost": float(m.deducted_amount)
                    })
        
    tx = models.Transaction(
        agency_id=agency_id,
        landlord_id=landlord_id,
        transaction_type="landlord_payout",
        amount=total_net,
        direction="out",
        status="completed",
        source="system",
        notes=f"Grouped payout for {len(payouts)} items."
    )
    db.add(tx)
    
    db.commit()
    
    # Generate PDF Invoice
    from app.services.pdf_generator import generate_landlord_statement
    from app.services.email_service import send_landlord_statement_email
    
    month_year = datetime.now().strftime("%B %Y")
    
    agency = db.query(models.Agency).filter(models.Agency.id == agency_id).first()
    agency_info = {
        "name": agency.name if agency else "",
        "address": agency.address if agency else "",
        "email": agency.email_address if agency else "",
        "contact_number": agency.contact_number if agency else "",
        "logo_url": agency.logo_url if agency else ""
    } if agency else None
    
    landlord_obj = db.query(models.Landlord).filter(models.Landlord.id == landlord_id).first()
    landlord_info = {
        "address": f"{landlord_obj.address_line_1 or ''}, {landlord_obj.city or ''}, {landlord_obj.postcode or ''}".strip(', '),
        "email": landlord_obj.email,
        "mobile_number": landlord_obj.phone
    } if landlord_obj else None
    total_management_base = float(total_management / (1 + (agency.default_vat_rate/100)) if (getattr(agency, 'vat_enabled', False) and getattr(agency, 'vat_registered', False)) else total_management)
    total_management_vat = float(total_management - (total_management / (1 + (agency.default_vat_rate/100)))) if (getattr(agency, 'vat_enabled', False) and getattr(agency, 'vat_registered', False)) else 0.0

    pdf_path = generate_landlord_statement(
        landlord_name=landlord_name,
        property_address=", ".join(properties),
        month_year=month_year,
        gross_rent=total_gross,
        management_fee=total_management,
        management_fee_base=total_management_base,
        management_fee_vat=total_management_vat,
        maintenance_records=maint_records,
        advance_recovery=total_adv,
        net_payout=float(total_net),
        agency_info=agency_info,
        landlord_info=landlord_info
    )
    
    # Create an AuditLog for the generated statement
    log_activity(db, agency_id, current_user.id, "GENERATED_STATEMENT", "landlord", landlord_id, f"Generated payout statement. Saved at: {pdf_path}")
    log_activity(db, agency_id, current_user.id, "LANDLORD_PAYOUT", "landlord", landlord_id, f"Sent payout of £{total_net} to landlord {landlord_id}")
    
    # Also log for each property so they show up in the property grid
    for p_id in property_ids:
        log_activity(db, agency_id, current_user.id, "PROPERTY_STATEMENT", "property", p_id, pdf_path)
    
    # Email it
    if landlord_email:
        body = f"Dear {landlord_name},\n\nPlease find attached your financial statement for {month_year} covering {len(properties)} properties.\nTotal Net Payout: £{total_net}\n\nThank you,\nYour Property Management Team"
        send_landlord_statement_email(landlord_email, f"Landlord Statement - {month_year}", body, pdf_path)

    return {"message": "Payout executed successfully", "amount": float(total_net), "statement_url": pdf_path}

@app.get("/properties/{property_id}/statements/")
def get_property_statements(property_id: int, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    logs = db.query(models.AuditLog).filter(
        models.AuditLog.agency_id == agency_id,
        models.AuditLog.resource_type == "property",
        models.AuditLog.resource_id == property_id,
        models.AuditLog.action == "PROPERTY_STATEMENT"
    ).order_by(models.AuditLog.created_at.desc()).all()
    
    import os
    statements = []
    for log in logs:
        filename = os.path.basename(log.details)
        url = f"http://127.0.0.1:8000/documents/invoices/{filename}"
        statements.append({
            "id": log.id,
            "date": log.created_at.strftime("%B %Y"),
            "url": url,
            "filename": filename
        })
    return statements

# --- AGENCY REPORTS ENDPOINTS ---
class DailyReportRequest(BaseModel):
    date: Optional[str] = None # YYYY-MM-DD, defaults to today

@app.post("/agency/reports/daily/")
def generate_agency_daily_report(
    req: DailyReportRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    agency_id = current_user.agency_id
    
    # Parse date
    if req.date:
        try:
            target_date = datetime.strptime(req.date, "%Y-%m-%d").date()
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    else:
        target_date = datetime.now().date()
        
    # Get Agency
    agency = db.query(models.Agency).filter(models.Agency.id == agency_id).first()
    if not agency:
        raise HTTPException(status_code=404, detail="Agency not found")

    # Safe datetime bounds for robust SQLite & Postgres query compatibility
    start_dt = datetime.combine(target_date, datetime.min.time())
    end_dt = datetime.combine(target_date, datetime.max.time())
        
    # Query all Payouts created on the target date
    payouts = db.query(models.Payout).options(
        joinedload(models.Payout.property),
        joinedload(models.Payout.landlord)
    ).join(
        models.Property, models.Payout.property_id == models.Property.id
    ).filter(
        models.Property.agency_id == agency_id,
        models.Payout.created_at >= start_dt,
        models.Payout.created_at <= end_dt
    ).all()
    
    # Query Maintenance created on target date
    maints = db.query(models.Maintenance).options(
        joinedload(models.Maintenance.property),
        joinedload(models.Maintenance.service_provider)
    ).filter(
        models.Maintenance.agency_id == agency_id,
        models.Maintenance.created_at >= start_dt,
        models.Maintenance.created_at <= end_dt
    ).all()
    
    payments_details = []
    management_details = []
    maintenance_details = []
    
    total_received = 0.0
    total_management_fees = 0.0
    total_maintenance_costs = 0.0
    
    # Calculate payments and management fees
    for p in payouts:
        # Get active tenant name for this property
        tenant_name = "N/A"
        active_tenant = db.query(models.Tenant).filter(
            models.Tenant.property_id == p.property_id
        ).first()
        if active_tenant:
            tenant_name = f"{active_tenant.first_name} {active_tenant.last_name}"
            
        prop_address = p.property.address_line_1 if p.property else "Unknown Property"
            
        payments_details.append({
            "property": prop_address,
            "tenant": tenant_name,
            "amount": float(p.gross_amount)
        })
        total_received += float(p.gross_amount)
        
        # Calculate fee
        fee_pct = float(p.payment_plan.tenancy.management_fee_percentage or 10.00) if p.payment_plan and p.payment_plan.tenancy else 10.00
        fee_amt = float(p.management_fee) if p.management_fee > 0 else float(p.gross_amount) * (fee_pct / 100.0)
        
        management_details.append({
            "property": prop_address,
            "fee_percentage": fee_pct,
            "amount": fee_amt
        })
        total_management_fees += fee_amt
        
    # Calculate maintenance details
    for m in maints:
        provider_name = m.service_provider.company_name if (m.service_provider and m.service_provider.company_name) else "Independent Contractor"
        prop_address = m.property.address_line_1 if m.property else "Unknown Property"
        
        maintenance_details.append({
            "property": prop_address,
            "provider": provider_name,
            "type": m.maintenance_type or "Repair",
            "cost": float(m.cost or 0.0)
        })
        total_maintenance_costs += float(m.cost or 0.0)
        
    # Generate Daily PDF Statement
    from app.services.pdf_generator import generate_agency_daily_report_pdf
    
    pdf_path = generate_agency_daily_report_pdf(
        agency_name=agency.name,
        report_date=target_date.strftime("%Y-%m-%d"),
        total_received=total_received,
        payments_received_count=len(payouts),
        total_management_fees=total_management_fees,
        total_maintenance_costs=total_maintenance_costs,
        payments_details=payments_details,
        management_details=management_details,
        maintenance_details=maintenance_details
    )
    
    # Save Daily generated statement into AuditLog so it is persistent and downloadable
    log_activity(
        db,
        agency_id,
        current_user.id,
        "AGENCY_DAILY_REPORT",
        "agency",
        agency_id,
        pdf_path
    )
    
    # Return response payload matching all items
    filename = os.path.basename(pdf_path)
    url = f"http://127.0.0.1:8000/documents/invoices/{filename}"
    
    return {
        "date": target_date.strftime("%Y-%m-%d"),
        "total_received": total_received,
        "payments_count": len(payouts),
        "total_management_fees": total_management_fees,
        "total_maintenance_costs": total_maintenance_costs,
        "payments_details": payments_details,
        "management_details": management_details,
        "maintenance_details": maintenance_details,
        "pdf_url": url,
        "filename": filename
    }

# ==========================================
# MAIL & COMMUNICATIONS
# ==========================================

from app.services import mail_service
import asyncio
from datetime import datetime, timezone

@app.get('/communications/config')
def get_comm_config(agency_id: int, db: Session = Depends(get_db)):
    config = db.query(models.CommunicationConfig).filter(models.CommunicationConfig.agency_id == agency_id).first()
    if not config:
        config = models.CommunicationConfig(agency_id=agency_id)
        db.add(config)
        db.commit()
        db.refresh(config)
    return config

@app.post('/communications/config')
def update_comm_config(agency_id: int, config_data: CommunicationConfigUpdate, db: Session = Depends(get_db)):
    config = db.query(models.CommunicationConfig).filter(models.CommunicationConfig.agency_id == agency_id).first()
    if not config:
        config = models.CommunicationConfig(agency_id=agency_id)
        db.add(config)
    
    for k, v in config_data.dict().items():
        setattr(config, k, v)
    
    db.commit()
    db.refresh(config)
    return config

@app.post('/communications/send')
async def send_communication(agency_id: int, message_data: CommunicationMessageCreate, db: Session = Depends(get_db)):
    config = db.query(models.CommunicationConfig).filter(models.CommunicationConfig.agency_id == agency_id).first()
    if not config or not config.is_enabled:
        raise HTTPException(status_code=400, detail='Mailer is not configured or disabled.')
        
    msg = models.CommunicationMessage(
        agency_id=agency_id,
        property_id=message_data.property_id,
        tenant_id=message_data.tenant_id,
        landlord_id=message_data.landlord_id,
        type=message_data.type,
        direction='outbound',
        status=message_data.status,
        subject=message_data.subject,
        body_html=message_data.body_html,
        body_text=message_data.body_text,
        recipient_address=message_data.recipient_address,
        cc_address=message_data.cc_address,
        bcc_address=message_data.bcc_address
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)
    
    if message_data.status == 'sent':
        # Send immediately
        await mail_service.send_email_async(config, msg, db)
        
    return msg

@app.post('/communications/send_with_attachment')
async def send_communication_with_attachment(
    agency_id: int, 
    property_id: Optional[int] = Form(None),
    tenant_id: Optional[int] = Form(None),
    landlord_id: Optional[int] = Form(None),
    type: str = Form('email'),
    subject: str = Form(...),
    body_text: Optional[str] = Form(None),
    recipient_address: str = Form(...),
    status: str = Form('sent'),
    file: Optional[UploadFile] = File(None),
    system_report_type: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    import os
    config = db.query(models.CommunicationConfig).filter(models.CommunicationConfig.agency_id == agency_id).first()
    if not config or not config.is_enabled:
        raise HTTPException(status_code=400, detail='Mailer is not configured or disabled.')
        
    msg = models.CommunicationMessage(
        agency_id=agency_id,
        property_id=property_id,
        tenant_id=tenant_id,
        landlord_id=landlord_id,
        type=type,
        direction='outbound',
        status=status,
        subject=subject,
        body_text=body_text,
        recipient_address=recipient_address
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)
    
    if file:
        upload_dir = f"uploads/agency_{agency_id}/communications/{msg.id}"
        os.makedirs(upload_dir, exist_ok=True)
        file_path = os.path.join(upload_dir, file.filename)
        with open(file_path, "wb") as buffer:
            import shutil
            shutil.copyfileobj(file.file, buffer)
            
        attachment = models.CommunicationAttachment(
            message_id=msg.id,
            file_name=file.filename,
            content_type=file.content_type,
            file_size=os.path.getsize(file_path),
            local_file_path=file_path
        )
        db.add(attachment)
        db.commit()
    elif system_report_type:
        from datetime import datetime, date
        from app.engines import report_engine
        from app.services.pdf_generator import (
            generate_landlord_statement,
            generate_landlord_invoice_multi_pdf,
            generate_tenant_invoice_pdf
        )
        
        date_f = date.today().replace(day=1)
        date_t = date.today()
        
        data = None
        report_type_key = None
        
        try:
            if system_report_type == 'Tenant Invoice':
                if not tenant_id:
                    raise HTTPException(status_code=400, detail="Please select a Tenant to generate a Tenant Invoice")
                data = report_engine.get_tenant_invoice(db, tenant_id, date_f, date_t, None)
                report_type_key = "tenant_invoice"
            elif system_report_type == 'Landlord Invoice':
                curr_landlord_id = landlord_id
                if not curr_landlord_id and property_id:
                    prop = db.query(models.Property).filter(models.Property.id == property_id).first()
                    if prop: curr_landlord_id = prop.landlord_id
                if not curr_landlord_id:
                    raise HTTPException(status_code=400, detail="Please select a Landlord to generate a Landlord Invoice")
                data = report_engine.get_landlord_invoice_multi(db, curr_landlord_id, date_f, date_t, None)
                report_type_key = "landlord_invoice_multi"
            elif system_report_type == 'Landlord Statement':
                if not property_id:
                    raise HTTPException(status_code=400, detail="Please select a Property to generate a Landlord Statement")
                data = report_engine.get_landlord_invoice_single(db, property_id, date_f, date_t, None)
                report_type_key = "landlord_invoice_single"
            elif system_report_type == 'Agent Statement':
                if not property_id:
                    raise HTTPException(status_code=400, detail="Please select a Property to generate an Agent Statement")
                data = report_engine.get_agency_property_statement(db, agency_id, property_id, date_f, date_t, None)
                report_type_key = "agency_property_statement"
        except Exception as e:
            raise HTTPException(status_code=400, detail=str(e))
            
        if data and report_type_key:
            agency = db.query(models.Agency).filter(models.Agency.id == agency_id).first()
            agency_info = {
                "name": agency.name if agency else "",
                "address": agency.address if agency else "",
                "email": "",
                "contact_number": agency.contact_number if agency else "",
                "logo_url": agency.logo_url if agency else ""
            }
            
            # ensure data is dict
            if hasattr(data, 'dict'):
                data = data.dict()
                
            data['date_from'] = date_f.strftime("%Y-%m-%d")
            data['date_to'] = date_t.strftime("%Y-%m-%d")
            data['report_type'] = report_type_key
            
            filepath = None
            if report_type_key == "landlord_invoice_single":
                filepath = generate_landlord_statement(
                    landlord_name=data.get('landlord', {}).get('name', ''),
                    property_address=data.get('property', {}).get('name', ''),
                    month_year=f"{date_f} to {date_t}",
                    gross_rent=data.get('financials', {}).get('rent_collected', 0),
                    management_fee=data.get('financials', {}).get('management_fee_amount', 0),
                    maintenance_records=data.get('financials', {}).get('actual_maintenance_costs', 0),
                    advance_recovery=0.0,
                    net_payout=data.get('financials', {}).get('net_amount_payable', 0),
                    agency_info=agency_info,
                    landlord_info=data.get('landlord', {})
                )
            elif report_type_key == "landlord_invoice_multi":
                filepath = generate_landlord_invoice_multi_pdf(data, agency_info=agency_info)
            elif report_type_key == "tenant_invoice":
                filepath = generate_tenant_invoice_pdf(data, agency_info=agency_info)
            elif report_type_key == "agency_property_statement":
                from app.services.pdf_generator import generate_agency_property_statement_pdf
                filepath = generate_agency_property_statement_pdf(data, agency_info=agency_info)
                
            if filepath:
                filename = os.path.basename(filepath)
                upload_dir = f"uploads/agency_{agency_id}/communications/{msg.id}"
                os.makedirs(upload_dir, exist_ok=True)
                dest_path = os.path.join(upload_dir, filename)
                import shutil
                shutil.copy2(filepath, dest_path)
                
                attachment = models.CommunicationAttachment(
                    message_id=msg.id,
                    file_name=filename,
                    content_type="application/pdf",
                    file_size=os.path.getsize(dest_path),
                    local_file_path=dest_path
                )
                db.add(attachment)
                db.commit()
    
    if status == 'sent':
        await mail_service.send_email_async(config, msg, db)
        
    return msg

@app.get('/communications/property/{property_id}')
def get_property_communications(property_id: int, agency_id: int, db: Session = Depends(get_db)):
    msgs = db.query(models.CommunicationMessage).filter(
        models.CommunicationMessage.agency_id == agency_id,
        models.CommunicationMessage.property_id == property_id
    ).order_by(models.CommunicationMessage.created_at.desc()).all()
    return msgs

@app.get('/communications/unassigned')
def get_unassigned_communications(agency_id: int, db: Session = Depends(get_db)):
    msgs = db.query(models.CommunicationMessage).filter(
        models.CommunicationMessage.agency_id == agency_id,
        models.CommunicationMessage.property_id == None
    ).order_by(models.CommunicationMessage.created_at.desc()).all()
    return msgs

@app.put('/communications/{msg_id}/read')
def mark_communication_read(msg_id: int, agency_id: int, db: Session = Depends(get_db)):
    msg = db.query(models.CommunicationMessage).filter(
        models.CommunicationMessage.id == msg_id,
        models.CommunicationMessage.agency_id == agency_id
    ).first()
    if msg:
        msg.is_read = True
        db.commit()
    return {"status": "ok"}

@app.put('/communications/{msg_id}/link_property')
def link_communication_property(msg_id: int, req: dict, agency_id: int, db: Session = Depends(get_db)):
    msg = db.query(models.CommunicationMessage).filter(
        models.CommunicationMessage.id == msg_id,
        models.CommunicationMessage.agency_id == agency_id
    ).first()
    if msg:
        msg.property_id = req.get('property_id')
        db.commit()
    return {"status": "ok"}

@app.get('/communications/dashboard')
def get_dashboard_emails(agency_id: int, db: Session = Depends(get_db)):
    
    today = datetime.now(timezone.utc).date()
    inbound_count = db.query(models.CommunicationMessage).filter(
        models.CommunicationMessage.agency_id == agency_id,
        models.CommunicationMessage.direction == 'inbound'
    ).count() # Simply returning total for now
    
    outbound_count = db.query(models.CommunicationMessage).filter(
        models.CommunicationMessage.agency_id == agency_id,
        models.CommunicationMessage.direction == 'outbound',
        models.CommunicationMessage.status == 'sent'
    ).count()
    
    return {
        'total_received_today': inbound_count,
        'total_sent_today': outbound_count,
        'unread': 0
    }

@app.get("/agency/reports/daily/")
def list_agency_daily_reports(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    agency_id = current_user.agency_id
    logs = db.query(models.AuditLog).filter(
        models.AuditLog.agency_id == agency_id,
        models.AuditLog.resource_type == "agency",
        models.AuditLog.action == "AGENCY_DAILY_REPORT"
    ).order_by(models.AuditLog.created_at.desc()).all()
    
    import os
    reports = []
    for log in logs:
        filename = os.path.basename(log.details)
        url = f"http://127.0.0.1:8000/documents/invoices/{filename}"
        
        display_date = log.created_at.strftime("%d %B %Y")
        display_time = log.created_at.strftime("%H:%M")
        
        reports.append({
            "id": log.id,
            "date": display_date,
            "time": display_time,
            "url": url,
            "filename": filename
        })
    return reports

# --- SERVICE PROVIDER ENDPOINTS ---
@app.get("/service-providers/")
def list_service_providers(search: Optional[str] = None, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    query = db.query(models.ServiceProvider).filter(models.ServiceProvider.agency_id == agency_id)
    if search:
        query = query.filter(
            models.ServiceProvider.company_name.ilike(f"%{search}%") |
            models.ServiceProvider.director_name.ilike(f"%{search}%") |
            models.ServiceProvider.email.ilike(f"%{search}%")
        )
    return query.all()

@app.post("/service-providers/")
def create_service_provider(data: ServiceProviderCreate, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    sp = models.ServiceProvider(**data.model_dump(), agency_id=agency_id)
    db.add(sp)
    db.commit()
    db.refresh(sp)
    return sp

@app.put("/service-providers/{sp_id}")
def update_service_provider(sp_id: int, data: ServiceProviderCreate, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    sp = db.query(models.ServiceProvider).filter(models.ServiceProvider.id == sp_id, models.ServiceProvider.agency_id == agency_id).first()
    if not sp: raise HTTPException(status_code=404, detail="Service provider not found")
    sp.company_name = data.company_name
    sp.director_name = data.director_name
    sp.address = data.address
    sp.contact_number = data.contact_number
    sp.email = data.email
    sp.vat_registered = data.vat_registered
    sp.vat_number = data.vat_number
    sp.default_vat_rate = data.default_vat_rate
    db.commit()
    db.refresh(sp)
    return sp

@app.delete("/service-providers/{sp_id}")
def delete_service_provider(sp_id: int, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    sp = db.query(models.ServiceProvider).filter(models.ServiceProvider.id == sp_id, models.ServiceProvider.agency_id == agency_id).first()
    if not sp: raise HTTPException(status_code=404, detail="Service provider not found")
    db.delete(sp)
    db.commit()
    return {"message": "Service provider deleted"}

# --- MAINTENANCE ENDPOINTS ---
@app.get("/properties/{prop_id}/maintenance/")
def read_maintenance(prop_id: int, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    return db.query(models.Maintenance).filter(
        models.Maintenance.property_id == prop_id,
        models.Maintenance.agency_id == agency_id
    ).order_by(models.Maintenance.created_at.desc()).all()

@app.post("/properties/{prop_id}/maintenance/")
async def create_maintenance(
    prop_id: int,
    maintenance_type: str = Query(...),
    details: str = Query(...),
    cost: float = Query(...),
    actual_cost: float = Query(0.00),
    base_cost: float = Query(0.00),
    vat_rate: float = Query(0.00),
    vat_amount: float = Query(0.00),
    maintenance_date: str = Query(...),
    service_provider_id: Optional[int] = Query(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    agency_id = current_user.agency_id
    from datetime import datetime
    try:
        m_date = datetime.fromisoformat(maintenance_date.replace('Z', '+00:00'))
    except:
        m_date = datetime.now()
    
    # If service provider is selected, prepend name to type as requested
    final_type = maintenance_type
    if service_provider_id:
        sp = db.query(models.ServiceProvider).filter(models.ServiceProvider.id == service_provider_id, models.ServiceProvider.agency_id == agency_id).first()
        if sp:
            final_type = f"{sp.company_name} - {maintenance_type}"
        
    db_m = models.Maintenance(
        agency_id=agency_id,
        property_id=prop_id,
        service_provider_id=service_provider_id,
        maintenance_type=final_type,
        details=details,
        cost=cost,
        actual_cost=actual_cost,
        base_cost=base_cost,
        vat_rate=vat_rate,
        vat_amount=vat_amount,
        maintenance_date=m_date,
        invoice_url=f"uploads/maint_{prop_id}_{file.filename}" if file else None
    )
    db.add(db_m)
    db.commit()
    db.refresh(db_m)
    
    # Recalculate pending payouts
    recalculate_pending_payouts_for_property(prop_id, db)
    
    log_activity(db, agency_id, current_user.id, "ADD_MAINTENANCE", "property", prop_id, f"Added {final_type} record. Cost: £{cost}")
    return db_m

@app.delete("/properties/{prop_id}/maintenance/{maint_id}")
def delete_maintenance(prop_id: int, maint_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency_id = current_user.agency_id
    maint = db.query(models.Maintenance).filter(
        models.Maintenance.id == maint_id,
        models.Maintenance.property_id == prop_id,
        models.Maintenance.agency_id == agency_id
    ).first()
    
    if not maint:
        raise HTTPException(status_code=404, detail="Maintenance record not found")
        
    db.delete(maint)
    db.commit()
    
    # Recalculate pending payouts
    recalculate_pending_payouts_for_property(prop_id, db)
    
    log_activity(db, agency_id, current_user.id, "DELETE_MAINTENANCE", "property", prop_id, f"Deleted maintenance record ID {maint_id}")
    return {"message": "Maintenance record deleted"}

class RefundDepositRequest(BaseModel):
    amount: float
    reference: str = ""

@app.post("/tenants/{tenant_id}/refund-deposit")
def refund_deposit(tenant_id: int, request: RefundDepositRequest, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    from decimal import Decimal
    tenant = db.query(models.Tenant).filter(models.Tenant.id == tenant_id, models.Tenant.agency_id == agency_id).first()
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
        
    amount = Decimal(str(request.amount))
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Refund amount must be greater than zero")
        
    if tenant.deposit_balance is None or tenant.deposit_balance < amount:
        raise HTTPException(status_code=400, detail="Insufficient deposit balance for this refund")
        
    # Update balance
    tenant.deposit_balance -= amount
    
    # Create transaction
    tx = models.Transaction(
        agency_id=agency_id,
        property_id=tenant.property_id,
        tenant_id=tenant.id,
        transaction_type="deposit_refund",
        amount=amount,
        direction="out",
        source="system",
        reference=request.reference,
        description="Deposit Refund"
    )
    db.add(tx)
    db.commit()
    
    return {"status": "success", "refunded_amount": amount, "remaining_deposit": tenant.deposit_balance}

@app.get("/tenants/{tenant_id}/deposit-info")
def get_deposit_info(tenant_id: int, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    tenant = db.query(models.Tenant).filter(models.Tenant.id == tenant_id, models.Tenant.agency_id == agency_id).first()
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
        
    transactions = db.query(models.Transaction).filter(
        models.Transaction.tenant_id == tenant_id,
        models.Transaction.transaction_type == "deposit_refund"
    ).order_by(models.Transaction.created_at.desc()).all()
    
    refunded_amount = sum(tx.amount for tx in transactions)
    remaining_balance = tenant.deposit_balance or 0
    total_deposit = remaining_balance + refunded_amount
    
    return {
        "total_deposit": float(total_deposit),
        "refunded_amount": float(refunded_amount),
        "remaining_balance": float(remaining_balance),
        "history": [
            {
                "id": tx.id,
                "amount": float(tx.amount),
                "date": tx.created_at.isoformat() if tx.created_at else None,
                "reference": tx.reference
            }
            for tx in transactions
        ]
    }


# --- ADVANCED REPORT ENGINE ENDPOINTS ---
from pydantic import BaseModel
from typing import List, Optional
from datetime import date
from app.engines import report_engine
from app.services.pdf_generator import (
    generate_landlord_statement,
    generate_landlord_invoice_multi_pdf,
    generate_agency_summary_pdf,
    generate_tenant_invoice_pdf
)
import json

class ReportRequest(BaseModel):
    agency_id: int
    report_type: str  # landlord_invoice_single, landlord_invoice_multi, agency_summary
    date_from: str
    date_to: str
    property_id: Optional[int] = None
    landlord_id: Optional[int] = None
    tenant_id: Optional[int] = None
    statuses: Optional[List[str]] = None

@app.post("/reports/preview")
def preview_report(request: ReportRequest, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    date_f = datetime.strptime(request.date_from, "%Y-%m-%d").date()
    date_t = datetime.strptime(request.date_to, "%Y-%m-%d").date()
    
    if request.report_type == "landlord_invoice_single":
        if not request.property_id:
            raise HTTPException(status_code=400, detail="property_id is required")
        data = report_engine.get_landlord_invoice_single(db, request.property_id, date_f, date_t, request.statuses)
    elif request.report_type == "landlord_invoice_multi":
        if not request.landlord_id:
            raise HTTPException(status_code=400, detail="landlord_id is required")
        data = report_engine.get_landlord_invoice_multi(db, request.landlord_id, date_f, date_t, request.statuses)
    elif request.report_type == "tenant_invoice":
        if not request.tenant_id:
            raise HTTPException(status_code=400, detail="tenant_id is required")
        data = report_engine.get_tenant_invoice(db, request.tenant_id, date_f, date_t, request.statuses)
    elif request.report_type == "agency_summary":
        data = report_engine.get_agency_summary(db, current_user.agency_id, date_f, date_t, request.property_id, request.statuses)
    elif request.report_type == "agency_property_statement":
        if not request.property_id:
            raise HTTPException(status_code=400, detail="property_id is required")
        data = report_engine.get_agency_property_statement(db, current_user.agency_id, request.property_id, date_f, date_t, request.statuses)
    else:
        raise HTTPException(status_code=400, detail="Invalid report_type")
        
    agency = db.query(models.Agency).filter(models.Agency.id == current_user.agency_id).first()
    agency_info = {
        "name": agency.name if agency else "",
        "address": agency.address if agency else "",
        "email": current_user.email,
        "contact_number": agency.contact_number if agency else "",
        "logo_url": agency.logo_url if agency else ""
    }
    data["agency_info"] = agency_info
        
    return data

@app.delete("/properties/{prop_id}/maintenance/{maint_id}")
def delete_maintenance(prop_id: int, maint_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency_id = current_user.agency_id
    maint = db.query(models.Maintenance).filter(
        models.Maintenance.id == maint_id,
        models.Maintenance.property_id == prop_id,
        models.Maintenance.agency_id == agency_id
    ).first()
    
    if not maint:
        raise HTTPException(status_code=404, detail="Maintenance record not found")
        
    db.delete(maint)
    db.commit()
    
    # Recalculate pending payouts
    recalculate_pending_payouts_for_property(prop_id, db)
    
    log_activity(db, agency_id, current_user.id, "DELETE_MAINTENANCE", "property", prop_id, f"Deleted maintenance record ID {maint_id}")
    return {"message": "Maintenance record deleted"}

class RefundDepositRequest(BaseModel):
    amount: float
    reference: str = ""

@app.post("/tenants/{tenant_id}/refund-deposit")
def refund_deposit(tenant_id: int, request: RefundDepositRequest, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    from decimal import Decimal
    tenant = db.query(models.Tenant).filter(models.Tenant.id == tenant_id, models.Tenant.agency_id == agency_id).first()
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
        
    amount = Decimal(str(request.amount))
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Refund amount must be greater than zero")
        
    if tenant.deposit_balance is None or tenant.deposit_balance < amount:
        raise HTTPException(status_code=400, detail="Insufficient deposit balance for this refund")
        
    # Update balance
    tenant.deposit_balance -= amount
    
    # Create transaction
    tx = models.Transaction(
        agency_id=agency_id,
        property_id=tenant.property_id,
        tenant_id=tenant.id,
        transaction_type="deposit_refund",
        amount=amount,
        direction="out",
        source="system",
        reference=request.reference,
        description="Deposit Refund"
    )
    db.add(tx)
    db.commit()
    
    return {"status": "success", "refunded_amount": amount, "remaining_deposit": tenant.deposit_balance}

@app.get("/tenants/{tenant_id}/deposit-info")
def get_deposit_info(tenant_id: int, db: Session = Depends(get_db), agency_id: int = Depends(get_agency_id)):
    tenant = db.query(models.Tenant).filter(models.Tenant.id == tenant_id, models.Tenant.agency_id == agency_id).first()
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
        
    transactions = db.query(models.Transaction).filter(
        models.Transaction.tenant_id == tenant_id,
        models.Transaction.transaction_type == "deposit_refund"
    ).order_by(models.Transaction.created_at.desc()).all()
    
    refunded_amount = sum(tx.amount for tx in transactions)
    remaining_balance = tenant.deposit_balance or 0
    total_deposit = remaining_balance + refunded_amount
    
    return {
        "total_deposit": float(total_deposit),
        "refunded_amount": float(refunded_amount),
        "remaining_balance": float(remaining_balance),
        "history": [
            {
                "id": tx.id,
                "amount": float(tx.amount),
                "date": tx.created_at.isoformat() if tx.created_at else None,
                "reference": tx.reference
            }
            for tx in transactions
        ]
    }


# --- ADVANCED REPORT ENGINE ENDPOINTS ---
from pydantic import BaseModel
from typing import List, Optional
from datetime import date
from app.engines import report_engine
from app.services.pdf_generator import (
    generate_landlord_statement,
    generate_landlord_invoice_multi_pdf,
    generate_agency_summary_pdf,
    generate_tenant_invoice_pdf
)
import json

class ReportRequest(BaseModel):
    agency_id: int
    report_type: str  # landlord_invoice_single, landlord_invoice_multi, agency_summary
    date_from: str
    date_to: str
    property_id: Optional[int] = None
    landlord_id: Optional[int] = None
    tenant_id: Optional[int] = None
    statuses: Optional[List[str]] = None

@app.post("/reports/preview")
def preview_report(request: ReportRequest, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    date_f = datetime.strptime(request.date_from, "%Y-%m-%d").date()
    date_t = datetime.strptime(request.date_to, "%Y-%m-%d").date()
    
    if request.report_type == "landlord_invoice_single":
        if not request.property_id:
            raise HTTPException(status_code=400, detail="property_id is required")
        data = report_engine.get_landlord_invoice_single(db, request.property_id, date_f, date_t, request.statuses)
    elif request.report_type == "landlord_invoice_multi":
        if not request.landlord_id:
            raise HTTPException(status_code=400, detail="landlord_id is required")
        data = report_engine.get_landlord_invoice_multi(db, request.landlord_id, date_f, date_t, request.statuses)
    elif request.report_type == "tenant_invoice":
        if not request.tenant_id:
            raise HTTPException(status_code=400, detail="tenant_id is required")
        data = report_engine.get_tenant_invoice(db, request.tenant_id, date_f, date_t, request.statuses)
    elif request.report_type == "agency_summary":
        data = report_engine.get_agency_summary(db, current_user.agency_id, date_f, date_t, request.property_id, request.statuses)
    elif request.report_type == "agency_property_statement":
        if not request.property_id:
            raise HTTPException(status_code=400, detail="property_id is required")
        data = report_engine.get_agency_property_statement(db, current_user.agency_id, request.property_id, date_f, date_t, request.statuses)
    else:
        raise HTTPException(status_code=400, detail="Invalid report_type")
        
    agency = db.query(models.Agency).filter(models.Agency.id == current_user.agency_id).first()
    agency_info = {
        "name": agency.name if agency else "",
        "address": agency.address if agency else "",
        "email": current_user.email,
        "contact_number": agency.contact_number if agency else "",
        "logo_url": agency.logo_url if agency else ""
    }
    data["agency_info"] = agency_info
        
    return data

@app.post("/reports/generate")
def generate_report(request: dict, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    report_type = request.get("report_type")
    
    agency = db.query(models.Agency).filter(models.Agency.id == current_user.agency_id).first()
    agency_info = {
        "name": agency.name if agency else "",
        "address": agency.address if agency else "",
        "email": current_user.email,
        "contact_number": agency.contact_number if agency else "",
        "logo_url": agency.logo_url if agency else ""
    }
    
    # Check if a dynamic template exists for this report type
    template = db.query(models.DocumentTemplate).filter(
        models.DocumentTemplate.agency_id == current_user.agency_id,
        models.DocumentTemplate.document_type == report_type,
        models.DocumentTemplate.is_default == True
    ).first()
    
    if template:
        from app.services.pdf_generator import generate_pdf_from_template
        request['agency_info'] = agency_info
        filepath = generate_pdf_from_template(template, request)
    else:
        # Fallback to legacy hardcoded generators
        if report_type == "landlord_invoice_single":
            from app.services.pdf_generator import generate_landlord_statement
            filepath = generate_landlord_statement(
                landlord_name=request['landlord']['name'],
                property_address=request['property']['name'],
                month_year=f"{request['date_from']} to {request['date_to']}",
                gross_rent=request['financials']['rent_collected'],
                management_fee=request['financials']['management_fee_amount'],
                maintenance_records=request['financials']['actual_maintenance_costs'],
                advance_recovery=0.0,
                net_payout=request['financials']['net_amount_payable'],
                agency_info=agency_info,
                landlord_info=request.get('landlord', {})
            )
        elif report_type == "landlord_invoice_multi":
            from app.services.pdf_generator import generate_landlord_invoice_multi_pdf
            filepath = generate_landlord_invoice_multi_pdf(request, agency_info=agency_info)
        elif report_type == "tenant_invoice":
            from app.services.pdf_generator import generate_tenant_invoice_pdf
            filepath = generate_tenant_invoice_pdf(request, agency_info=agency_info)
        elif report_type == "agency_summary":
            from app.services.pdf_generator import generate_agency_summary_pdf
            filepath = generate_agency_summary_pdf(request, agency_info=agency_info)
        elif report_type == "agency_property_statement":
            from app.services.pdf_generator import generate_agency_property_statement_pdf
            filepath = generate_agency_property_statement_pdf(request, agency_info=agency_info)
        else:
            raise HTTPException(status_code=400, detail="Invalid report_type")
        
    # Mocking storing the report in DB and returning URL
    # In a real system, you'd upload to S3. For now we serve from static documents folder.
    filename = os.path.basename(filepath)
    return {"pdf_url": f"http://127.0.0.1:8000/documents/invoices/{filename}", "filename": filename}

from app.routers import landlord, templates, email_activity, email_settings

os.makedirs("documents/templates", exist_ok=True)
os.makedirs("documents/invoices", exist_ok=True)
app.mount("/documents", StaticFiles(directory="documents"), name="documents")

app.include_router(landlord.router)
app.include_router(templates.router)
app.include_router(email_activity.router)
app.include_router(email_settings.router)
