import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.database import engine
from sqlalchemy import text

commands = [
    # Property
    "ALTER TABLE properties ADD COLUMN room_no VARCHAR(50);",
    "ALTER TABLE properties ADD COLUMN county VARCHAR(100);",
    
    # Landlord
    "ALTER TABLE landlords ADD COLUMN co VARCHAR(100);",
    "ALTER TABLE landlords ADD COLUMN address_line_1 VARCHAR(255);",
    "ALTER TABLE landlords ADD COLUMN address_line_2 VARCHAR(255);",
    "ALTER TABLE landlords ADD COLUMN city VARCHAR(100);",
    "ALTER TABLE landlords ADD COLUMN county VARCHAR(100);",
    "ALTER TABLE landlords ADD COLUMN postcode VARCHAR(20);",
    
    # Tenant
    "ALTER TABLE tenants ADD COLUMN address_line_1 VARCHAR(255);",
    "ALTER TABLE tenants ADD COLUMN address_line_2 VARCHAR(255);",
    "ALTER TABLE tenants ADD COLUMN city VARCHAR(100);",
    "ALTER TABLE tenants ADD COLUMN county VARCHAR(100);",
    "ALTER TABLE tenants ADD COLUMN postcode VARCHAR(20);",
    "ALTER TABLE tenants ADD COLUMN proof_of_id_url VARCHAR(500);",
    "ALTER TABLE tenants ADD COLUMN id_verification_status VARCHAR(50) DEFAULT 'missing';",
    "ALTER TABLE tenants ADD COLUMN id_verification_notes TEXT;"
]

print("Applying Phase 9 Schema updates...")
with engine.begin() as conn:
    for cmd in commands:
        try:
            conn.execute(text(cmd))
            print(f"Success: {cmd.split('ADD COLUMN')[1].strip()}")
        except Exception as e:
            print(f"Skipped/Error on {cmd}: {e}")

print("Schema update complete!")
