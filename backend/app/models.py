from sqlalchemy import Boolean, Column, ForeignKey, Integer, String, Numeric, Date, DateTime, Text, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base
import enum

class Agency(Base):
    __tablename__ = "agencies"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    subdomain = Column(String(100), unique=True)
    bank_account_name = Column(String(255))
    bank_account_number = Column(String(50))
    bank_sort_code = Column(String(20))
    logo_url = Column(String(500))
    footer_logo_url = Column(String(500))
    address = Column(Text)
    contact_number = Column(String(50))
    email_address = Column(String(255))
    vat_enabled = Column(Boolean, default=False)
    default_vat_rate = Column(Numeric(5, 2), default=20.00)
    vat_registered = Column(Boolean, default=False)
    vat_registration_number = Column(String(100))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey("agencies.id"), nullable=False)
    name = Column(String(255), nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    role = Column(String(50), nullable=False)
    password_hash = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True)
    avatar_url = Column(String(500))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Landlord(Base):
    __tablename__ = "landlords"
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey("agencies.id"), nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    co = Column(String(100)) # Care Of
    address_line_1 = Column(String(255))
    address_line_2 = Column(String(255))
    city = Column(String(100))
    county = Column(String(100))
    postcode = Column(String(20))
    email = Column(String(255))
    phone = Column(String(50))
    communication_preference = Column(String(50), default='email_only') # email_only, sms_only, both, none
    payout_preference = Column(String(50), default="auto")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    properties = relationship("Property", back_populates="landlord")

class Property(Base):
    __tablename__ = "properties"
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey("agencies.id"), nullable=False)
    landlord_id = Column(Integer, ForeignKey("landlords.id"), nullable=False)
    room_no = Column(String(50))
    address_line_1 = Column(String(255), nullable=False)
    address_line_2 = Column(String(255))
    city = Column(String(100), nullable=False)
    county = Column(String(100))
    postcode = Column(String(20), nullable=False)
    status = Column(String(50), default="active")
    assigned_manager_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    landlord = relationship("Landlord", back_populates="properties")
    tenancies = relationship("Tenancy", back_populates="property")
    tenants = relationship("Tenant", back_populates="property")
    maintenance_records = relationship("Maintenance", back_populates="property")
    assigned_manager = relationship("User")

class AuditLog(Base):
    __tablename__ = "audit_logs"
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey("agencies.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    action = Column(String(255), nullable=False) # e.g. "CREATE_PROPERTY"
    resource_type = Column(String(100)) # e.g. "property"
    resource_id = Column(Integer)
    details = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User")

class Tenant(Base):
    __tablename__ = "tenants"
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey("agencies.id"), nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    address_line_1 = Column(String(255))
    address_line_2 = Column(String(255))
    city = Column(String(100))
    county = Column(String(100))
    postcode = Column(String(20))
    email = Column(String(255))
    phone = Column(String(50))
    communication_preference = Column(String(50), default='email_only') # email_only, sms_only, both, none
    proof_of_id_url = Column(String(500))
    id_verification_status = Column(String(50), default="missing") # missing, pending, verified, rejected
    id_verification_notes = Column(Text)
    credit_balance = Column(Numeric(12, 2), default=0.00)
    deposit_balance = Column(Numeric(12, 2), default=0.00)
    property_id = Column(Integer, ForeignKey("properties.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    property = relationship("Property", back_populates="tenants")

class Tenancy(Base):
    __tablename__ = "tenancies"
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey("agencies.id"), nullable=False)
    property_id = Column(Integer, ForeignKey("properties.id"), nullable=False)
    rent_amount = Column(Numeric(10, 2), nullable=False)
    payment_frequency = Column(String(50), default="monthly")
    due_day = Column(Integer, nullable=False)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date)
    status = Column(String(50), default="active")
    payment_plan_active = Column(Boolean, default=True)
    management_fee_percentage = Column(Numeric(5, 2), default=10.00)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    property = relationship("Property", back_populates="tenancies")

class Invoice(Base):
    __tablename__ = "invoices"
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey("agencies.id"), nullable=False)
    property_id = Column(Integer, ForeignKey("properties.id"), nullable=False)
    type = Column(String(50), nullable=False)
    amount = Column(Numeric(10, 2), nullable=False)
    description = Column(Text)
    contractor_name = Column(String(255))
    subtotal = Column(Numeric(10, 2), default=0.00)
    vat_rate = Column(Numeric(5, 2), default=0.00)
    vat_amount = Column(Numeric(10, 2), default=0.00)
    total_amount = Column(Numeric(10, 2), default=0.00)
    status = Column(String(50), default="pending_deduction")
    remaining_balance = Column(Numeric(10, 2), nullable=False)
    document_url = Column(String(500))
    created_by = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    lines = relationship("InvoiceLine", back_populates="invoice", cascade="all, delete-orphan")

class InvoiceLine(Base):
    __tablename__ = "invoice_lines"
    id = Column(Integer, primary_key=True, index=True)
    invoice_id = Column(Integer, ForeignKey("invoices.id"), nullable=False)
    description = Column(String(255), nullable=False)
    unit_price = Column(Numeric(10, 2), nullable=False)
    vat_rate = Column(Numeric(5, 2), default=0.00)
    vat_amount = Column(Numeric(10, 2), default=0.00)
    line_total = Column(Numeric(10, 2), nullable=False)
    
    invoice = relationship("Invoice", back_populates="lines")

class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey("agencies.id"), nullable=False)
    property_id = Column(Integer, ForeignKey("properties.id"))
    tenancy_id = Column(Integer, ForeignKey("tenancies.id"))
    landlord_id = Column(Integer, ForeignKey("landlords.id"))
    tenant_id = Column(Integer, ForeignKey("tenants.id"))
    invoice_id = Column(Integer, ForeignKey("invoices.id"))
    transaction_type = Column(String(50), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    direction = Column(String(10), nullable=False)
    status = Column(String(50), default="completed")
    hold_reason = Column(String(255))
    source = Column(String(50), nullable=False)
    reference = Column(String(255))
    reversed_by_transaction_id = Column(Integer, ForeignKey("transactions.id"))
    notes = Column(Text)
    created_by = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class ServiceProvider(Base):
    __tablename__ = "service_providers"
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey("agencies.id"), nullable=False)
    company_name = Column(String(255), nullable=False)
    director_name = Column(String(255))
    address = Column(Text)
    contact_number = Column(String(50))
    email = Column(String(255))
    vat_registered = Column(Boolean, default=False)
    vat_number = Column(String(100))
    default_vat_rate = Column(Numeric(5, 2), default=20.00)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Maintenance(Base):
    __tablename__ = "maintenance"
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey("agencies.id"), nullable=False)
    property_id = Column(Integer, ForeignKey("properties.id"), nullable=False)
    service_provider_id = Column(Integer, ForeignKey("service_providers.id"))
    maintenance_type = Column(String(100), nullable=False)
    details = Column(Text, nullable=False)
    cost = Column(Numeric(10, 2), nullable=False)
    base_cost = Column(Numeric(10, 2), default=0.00)
    vat_rate = Column(Numeric(5, 2), default=0.00)
    vat_amount = Column(Numeric(10, 2), default=0.00)
    actual_cost = Column(Numeric(10, 2), default=0.00)
    deducted_amount = Column(Numeric(10, 2), default=0.00)
    maintenance_date = Column(DateTime(timezone=True), nullable=False)
    invoice_url = Column(String(500))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    property = relationship("Property", back_populates="maintenance_records")
    service_provider = relationship("ServiceProvider")

class BankEntry(Base):
    __tablename__ = "bank_entries"
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey("agencies.id"), nullable=False)
    date = Column(Date, nullable=False)
    reference = Column(String(255))
    amount = Column(Numeric(12, 2), nullable=False)
    allocated_amount = Column(Numeric(12, 2), default=0.00)
    status = Column(String(50), default="pending") # pending, allocated, partially_allocated
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class RentPaymentPlan(Base):
    __tablename__ = "rent_payment_plans"
    id = Column(Integer, primary_key=True, index=True)
    tenancy_id = Column(Integer, ForeignKey("tenancies.id"), nullable=False)
    due_date = Column(Date, nullable=False)
    expected_amount = Column(Numeric(10, 2), nullable=False)
    paid_amount = Column(Numeric(10, 2), default=0.00)
    status = Column(String(50), default="unpaid") # unpaid, partially_paid, paid
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    tenancy = relationship("Tenancy")
    payouts = relationship("Payout", back_populates="payment_plan")

class LandlordAdvance(Base):
    __tablename__ = "landlord_advances"
    id = Column(Integer, primary_key=True, index=True)
    landlord_id = Column(Integer, ForeignKey("landlords.id"), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    recovered_amount = Column(Numeric(12, 2), default=0.00)
    status = Column(String(50), default="outstanding") # outstanding, partially_recovered, recovered
    notes = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Payout(Base):
    __tablename__ = "payouts"
    id = Column(Integer, primary_key=True, index=True)
    
    # New Fields for Multiple Payout Types
    payment_type = Column(String(50), default="landlord") # 'landlord', 'service_provider', 'agent_fee'
    recipient_name = Column(String(255))
    service_provider_id = Column(Integer, ForeignKey("service_providers.id"), nullable=True)
    reference_number = Column(String(255), nullable=True)
    
    landlord_id = Column(Integer, ForeignKey("landlords.id"), nullable=True) # Now nullable
    property_id = Column(Integer, ForeignKey("properties.id"), nullable=False)
    rent_allocation_id = Column(Integer) # Link to the transaction (BankEntry)
    payment_plan_id = Column(Integer, ForeignKey("rent_payment_plans.id")) # Link to the specific month
    
    gross_amount = Column(Numeric(12, 2), nullable=False)
    management_fee = Column(Numeric(12, 2), default=0.00)
    maintenance_cost = Column(Numeric(12, 2), default=0.00)
    advance_recovery = Column(Numeric(12, 2), default=0.00)
    deductions_total = Column(Numeric(12, 2), default=0.00)
    net_amount = Column(Numeric(12, 2), nullable=False)
    
    status = Column(String(50), default="pending") # pending, processing, paid, partially_paid, cancelled, failed
    hold_reason = Column(String(255))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    payment_plan = relationship("RentPaymentPlan", back_populates="payouts")
    property = relationship("Property")
    landlord = relationship("Landlord")
    service_provider = relationship("ServiceProvider")

class LLMConfig(Base):
    __tablename__ = "llm_configs"
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey("agencies.id"), nullable=False)
    provider = Column(String(50), default="gemini") # gemini, openai, ollama
    api_key = Column(String(255))
    model_name = Column(String(100), default="gemini-1.5-pro")
    base_url = Column(String(255)) 
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class UserPermission(Base):
    __tablename__ = "user_permissions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    resource = Column(String(50)) # e.g., 'properties', 'ledgers'
    action = Column(String(50))   # e.g., 'create', 'read', 'update', 'delete'

class CommunicationConfig(Base):
    __tablename__ = 'communication_configs'
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey('agencies.id'), nullable=False, unique=True)
    is_enabled = Column(Boolean, default=False)
    mail_provider = Column(String(50), default='smtp') # smtp, gmail_api, ms_graph
    
    # SMTP Settings (also used as IMAP fallback if gmail_api/ms_graph not used)
    smtp_server = Column(String(255))
    smtp_port = Column(Integer)
    smtp_username = Column(String(255))
    smtp_password = Column(String(255))
    imap_server = Column(String(255))
    imap_port = Column(Integer)
    
    # Common Sender Details
    sender_name = Column(String(255))
    sender_email = Column(String(255))
    reply_to = Column(String(255))
    
    # OAuth Tokens for Google/Microsoft
    oauth_access_token = Column(Text)
    oauth_refresh_token = Column(Text)
    oauth_expires_at = Column(DateTime(timezone=True))
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    agency = relationship('Agency')

class CommunicationMessage(Base):
    __tablename__ = 'communication_messages'
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey('agencies.id'), nullable=False)
    property_id = Column(Integer, ForeignKey('properties.id'), nullable=True)
    tenant_id = Column(Integer, ForeignKey('tenants.id'), nullable=True)
    landlord_id = Column(Integer, ForeignKey('landlords.id'), nullable=True)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=True) # Sender (if outbound from app)
    
    type = Column(String(50), default='email') # email, sms
    direction = Column(String(50), default='outbound') # inbound, outbound
    status = Column(String(50), default='draft') # draft, sent, received, failed
    
    subject = Column(String(500))
    body_html = Column(Text)
    body_text = Column(Text)
    
    sender_address = Column(String(255))
    recipient_address = Column(Text) # comma separated
    cc_address = Column(Text)
    bcc_address = Column(Text)
    
    message_id_header = Column(String(255), unique=True, index=True) # Remote message ID to prevent duplicates
    
    is_read = Column(Boolean, default=False)
    opened_at = Column(DateTime(timezone=True), nullable=True)
    delivery_status = Column(String(50))
    contact_type = Column(String(50))
    
    sent_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    property = relationship('Property')
    tenant = relationship('Tenant')
    landlord = relationship('Landlord')
    attachments = relationship('CommunicationAttachment', back_populates='message', cascade='all, delete-orphan')

class CommunicationAttachment(Base):
    __tablename__ = 'communication_attachments'
    id = Column(Integer, primary_key=True, index=True)
    message_id = Column(Integer, ForeignKey('communication_messages.id'), nullable=False)
    
    file_name = Column(String(255), nullable=False)
    local_file_path = Column(String(1000), nullable=False) # e.g. /app/storage/mail_attachments/...
    file_size = Column(Integer) # in bytes
    content_type = Column(String(100)) # e.g. application/pdf
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    message = relationship('CommunicationMessage', back_populates='attachments')

class MagicLinkToken(Base):
    __tablename__ = 'magic_link_tokens'
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), index=True, nullable=False)
    token = Column(String(255), unique=True, index=True, nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    is_used = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class DocumentTemplate(Base):
    __tablename__ = 'document_templates'
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey('agencies.id'), nullable=False)
    name = Column(String(255), nullable=False)
    document_type = Column(String(100), nullable=False)
    is_default = Column(Boolean, default=False)
    
    paper_size = Column(String(50), default="A4")
    orientation = Column(String(50), default="Portrait")
    margin_top = Column(Numeric(10, 2), default=20.0)
    margin_bottom = Column(Numeric(10, 2), default=20.0)
    margin_left = Column(Numeric(10, 2), default=20.0)
    margin_right = Column(Numeric(10, 2), default=20.0)
    
    # Visual Editor Fields
    template_type = Column(String(50), default="visual") # 'visual', 'html', 'pdf_overlay'
    background_file_url = Column(String(500), nullable=True) # URL or path to uploaded PDF/Image background
    visual_config = Column(Text, nullable=True) # JSON storing the coordinates and placeholders
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    agency = relationship("Agency")

class EmailTemplate(Base):
    __tablename__ = 'email_templates'
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey('agencies.id'), nullable=False)
    name = Column(String(255), nullable=False)
    subject = Column(String(500), nullable=False)
    body_html = Column(Text, nullable=False)
    body_text = Column(Text)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    agency = relationship("Agency")

class EmailCampaign(Base):
    __tablename__ = 'email_campaigns'
    id = Column(Integer, primary_key=True, index=True)
    agency_id = Column(Integer, ForeignKey('agencies.id'), nullable=False)
    name = Column(String(255), nullable=False)
    trigger_type = Column(String(50), nullable=False) # e.g., rent_upcoming, rent_overdue, rent_due
    days_offset = Column(String(255), default="") # comma separated days (e.g. "1,3,7")
    template_id = Column(Integer, ForeignKey('email_templates.id'), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    agency = relationship("Agency")
    template = relationship("EmailTemplate")
