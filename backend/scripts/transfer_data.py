import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.database import SessionLocal
from app import models

db = SessionLocal()

target_agency_id = 4 # The user's agency

print(f"Transferring all data to Agency ID: {target_agency_id}...")

db.query(models.Landlord).update({"agency_id": target_agency_id})
db.query(models.Property).update({"agency_id": target_agency_id})
db.query(models.Tenant).update({"agency_id": target_agency_id})
db.query(models.Tenancy).update({"agency_id": target_agency_id})

db.commit()
db.close()
print("Data transfer complete!")
