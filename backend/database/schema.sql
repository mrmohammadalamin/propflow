-- Multi-Tenant PostgreSQL Schema for Agentic Rent Collections

-- 1. SaaS Layer: Agencies (Tenants)
CREATE TABLE agencies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    subdomain VARCHAR(100) UNIQUE,
    management_fee_percentage DECIMAL(5, 2) DEFAULT 10.00,
    bank_account_name VARCHAR(255),
    bank_account_number VARCHAR(50),
    bank_sort_code VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Users (Agency Staff / System Admins)
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER NOT NULL REFERENCES agencies(id),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('admin', 'agent', 'accountant')),
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Core Entities: Landlords
CREATE TABLE landlords (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER NOT NULL REFERENCES agencies(id),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    bank_account_name VARCHAR(255),
    bank_account_number VARCHAR(50),
    bank_sort_code VARCHAR(20),
    payout_preference VARCHAR(50) DEFAULT 'auto' CHECK (payout_preference IN ('auto', 'manual', 'hold')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Core Entities: Properties (The Unique Identity Hub)
CREATE TABLE properties (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER NOT NULL REFERENCES agencies(id),
    landlord_id INTEGER NOT NULL REFERENCES landlords(id),
    address_line_1 VARCHAR(255) NOT NULL,
    address_line_2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Core Entities: Tenants
CREATE TABLE tenants (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER NOT NULL REFERENCES agencies(id),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    credit_balance DECIMAL(12, 2) DEFAULT 0.00, -- Overpayments held here
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. Core Entities: Tenancies (Linking Property, Tenants, Landlord)
-- A property can have multiple tenants (joint tenancy).
CREATE TABLE tenancies (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER NOT NULL REFERENCES agencies(id),
    property_id INTEGER NOT NULL REFERENCES properties(id),
    rent_amount DECIMAL(10, 2) NOT NULL,
    payment_frequency VARCHAR(50) DEFAULT 'monthly' CHECK (payment_frequency IN ('weekly', 'monthly', 'quarterly', 'annually')),
    due_day INTEGER NOT NULL, -- e.g., 1 for 1st of month
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'closed', 'arrears')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Many-to-Many relationship between Tenants and Tenancies (Joint Tenancies)
CREATE TABLE tenancy_tenants (
    tenancy_id INTEGER NOT NULL REFERENCES tenancies(id),
    tenant_id INTEGER NOT NULL REFERENCES tenants(id),
    is_lead_tenant BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (tenancy_id, tenant_id)
);

-- 7. Invoices & Deductions
CREATE TABLE invoices (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER NOT NULL REFERENCES agencies(id),
    property_id INTEGER NOT NULL REFERENCES properties(id),
    type VARCHAR(50) NOT NULL CHECK (type IN ('contractor_repair', 'agency_fee', 'adjustment', 'advance_recovery')),
    amount DECIMAL(10, 2) NOT NULL,
    description TEXT,
    contractor_name VARCHAR(255),
    status VARCHAR(50) DEFAULT 'pending_deduction' CHECK (status IN ('created', 'pending_deduction', 'partially_deducted', 'applied', 'archived')),
    remaining_balance DECIMAL(10, 2) NOT NULL, -- To handle partial deductions
    document_url VARCHAR(500),
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. The Immutable Ledger: Transactions (Single Source of Truth)
CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    agency_id INTEGER NOT NULL REFERENCES agencies(id),
    property_id INTEGER REFERENCES properties(id),
    tenancy_id INTEGER REFERENCES tenancies(id),
    landlord_id INTEGER REFERENCES landlords(id),
    tenant_id INTEGER REFERENCES tenants(id),
    invoice_id INTEGER REFERENCES invoices(id), -- If transaction is paying an invoice
    
    transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN (
        'rent_received', 'credit_applied', 'credit_hold', 
        'deduction_repair', 'deduction_fee', 'advance_issued', 'advance_recovery', 
        'distribution_landlord', 'reversal'
    )),
    
    amount DECIMAL(12, 2) NOT NULL,
    direction VARCHAR(10) NOT NULL CHECK (direction IN ('in', 'out')),
    
    status VARCHAR(50) DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'held')),
    hold_reason VARCHAR(255),
    
    source VARCHAR(50) NOT NULL CHECK (source IN ('bank_feed', 'manual_entry', 'auto_engine', 'agentic_extraction')),
    reference VARCHAR(255), -- Bank reference or auto-generated
    
    reversed_by_transaction_id INTEGER REFERENCES transactions(id), -- For immutable corrections
    notes TEXT,
    
    created_by INTEGER REFERENCES users(id), -- Null if system/agentic
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance and multi-tenant isolation
CREATE INDEX idx_agencies_subdomain ON agencies(subdomain);
CREATE INDEX idx_users_agency ON users(agency_id);
CREATE INDEX idx_properties_agency ON properties(agency_id);
CREATE INDEX idx_transactions_agency_property ON transactions(agency_id, property_id);
CREATE INDEX idx_transactions_created_at ON transactions(created_at);
