import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.orm import Session
from faker import Faker
import random
from datetime import timedelta, date

from app.database import engine, Base, SessionLocal
from app import models

fake = Faker('en_GB')

def seed_data(db: Session):
    print("Checking for existing agency...")
    agency = db.query(models.Agency).first()
    
    if not agency:
        print("No agency found. Please register an agency via the Flutter app first!")
        return

    print(f"Seeding Data for Agency: {agency.name} (ID: {agency.id})...")

    print("Seeding Landlords...")
    landlords = []
    for _ in range(10):
        landlord = models.Landlord(
            agency_id=agency.id,
            first_name=fake.first_name(),
            last_name=fake.last_name(),
            email=fake.email(),
            phone=fake.phone_number()
        )
        db.add(landlord)
        landlords.append(landlord)
    db.commit()

    print("Seeding Properties...")
    properties = []
    for _ in range(15):
        # Pick a random landlord, but heavily weight a few to create "portfolio landlords"
        if random.random() > 0.8:
            landlord = random.choice(landlords[:10]) # Portfolio landlord
        else:
            landlord = random.choice(landlords)
            
        prop = models.Property(
            agency_id=landlord.agency_id, # Must match landlord's agency
            landlord_id=landlord.id,
            address_line_1=fake.street_address(),
            city=fake.city(),
            postcode=fake.postcode(),
            status="active"
        )
        db.add(prop)
        properties.append(prop)
    db.commit()

    print("Seeding Tenants and Tenancies...")
    for prop in properties:
        # Create 1-3 tenants per property
        num_tenants = random.randint(1, 3)
        tenants = []
        for _ in range(num_tenants):
            tenant = models.Tenant(
                agency_id=prop.agency_id,
                first_name=fake.first_name(),
                last_name=fake.last_name(),
                email=fake.email(),
                phone=fake.phone_number()
            )
            db.add(tenant)
            tenants.append(tenant)
        db.commit() # Need ids

        # Create Tenancy
        start_date = fake.date_between(start_date='-2y', end_date='-1m')
        tenancy = models.Tenancy(
            agency_id=prop.agency_id,
            property_id=prop.id,
            rent_amount=round(random.uniform(600, 2500), 2),
            payment_frequency="monthly",
            due_day=random.randint(1, 28),
            start_date=start_date
        )
        db.add(tenancy)
        db.commit()

        # Link tenants to tenancy (simulating tenancy_tenants table which isn't explicitly defined in models yet, but we'll need it or just map it). 
        # For MVP seeding, we'll skip the M:M and just assume the tenancies exist.

    print("Database seeded successfully!")

if __name__ == "__main__":
    db = SessionLocal()
    seed_data(db)
    db.close()
