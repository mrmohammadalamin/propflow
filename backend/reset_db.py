from app.database import SessionLocal, engine
from app import models

db = SessionLocal()

try:
    print('Deleting Payouts...')
    db.query(models.Payout).delete()
    print('Deleting Transactions...')
    db.query(models.Transaction).delete()
    print('Deleting Invoices...')
    db.query(models.Invoice).delete()
    print('Deleting Maintenance...')
    db.query(models.Maintenance).delete()
    print('Deleting BankEntries...')
    db.query(models.BankEntry).delete()
    print('Deleting AuditLogs...')
    db.query(models.AuditLog).delete()
    
    print('Deleting LandlordAdvances...')
    db.query(models.LandlordAdvance).delete()
    
    print('Deleting RentPaymentPlans...')
    db.query(models.RentPaymentPlan).delete()
    
    print('Deleting Tenancies...')
    db.query(models.Tenancy).delete()
    
    print('Deleting Tenants...')
    db.query(models.Tenant).delete()
    
    print('Deleting Properties...')
    db.query(models.Property).delete()
    
    print('Deleting ServiceProviders...')
    db.query(models.ServiceProvider).delete()
    
    print('Deleting Landlords...')
    db.query(models.Landlord).delete()
    
    db.commit()
    print('Successfully cleared testing data. Users and Agency info preserved.')
except Exception as e:
    db.rollback()
    print('Error clearing database:', e)
finally:
    db.close()
