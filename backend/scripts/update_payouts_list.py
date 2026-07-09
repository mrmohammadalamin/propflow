import os

file_path = r"c:\Users\mrmoh\Desktop\rentcollections\backend\app\main.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

old_list = """@app.get("/finance/payouts/")
def list_all_payouts(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency_id = current_user.agency_id
    payouts = db.query(models.Payout).options(
        joinedload(models.Payout.property), 
        joinedload(models.Payout.landlord),
        joinedload(models.Payout.service_provider)
    ).join(models.Property).filter(models.Property.agency_id == agency_id).order_by(models.Payout.created_at.desc()).all()
    
    return payouts"""

new_list = """@app.get("/finance/payouts/")
def list_all_payouts(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    agency_id = current_user.agency_id
    payouts = db.query(models.Payout).options(
        joinedload(models.Payout.property).joinedload(models.Property.tenants),
        joinedload(models.Payout.property).joinedload(models.Property.landlord),
        joinedload(models.Payout.landlord),
        joinedload(models.Payout.service_provider)
    ).join(models.Property).filter(models.Property.agency_id == agency_id).order_by(models.Payout.created_at.desc()).all()
    
    return payouts"""

if old_list in content:
    content = content.replace(old_list, new_list)
    print("Updated list_all_payouts.")
else:
    print("ERROR: old_list not found!")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
