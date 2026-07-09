import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.database import engine
from sqlalchemy import text

print("Applying ALTER TABLE commands to database...")
with engine.begin() as conn:
    try:
        conn.execute(text("ALTER TABLE tenants ADD COLUMN property_id INTEGER REFERENCES properties(id);"))
        print("Added property_id to tenants")
    except Exception as e:
        print(f"Skipping property_id: {e}")
        
    try:
        conn.execute(text("ALTER TABLE tenancies ADD COLUMN payment_plan_active BOOLEAN DEFAULT TRUE;"))
        print("Added payment_plan_active to tenancies")
    except Exception as e:
        print(f"Skipping payment_plan_active: {e}")

print("Schema update complete!")
