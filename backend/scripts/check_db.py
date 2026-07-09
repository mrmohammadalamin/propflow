import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.database import SessionLocal
from app import models

db = SessionLocal()

print("--- Agencies ---")
for a in db.query(models.Agency).all():
    print(f"ID: {a.id}, Name: {a.name}")

print("\n--- Users ---")
for u in db.query(models.User).all():
    print(f"ID: {u.id}, Agency ID: {u.agency_id}, Email: {u.email}")

print("\n--- Counts ---")
print(f"Landlords: {db.query(models.Landlord).count()}")
print(f"Properties: {db.query(models.Property).count()}")
print(f"Tenants: {db.query(models.Tenant).count()}")

print("\n--- First 3 Properties ---")
for p in db.query(models.Property).limit(3).all():
    print(f"Prop ID: {p.id}, Agency ID: {p.agency_id}, Address: {p.address_line_1}")

db.close()
