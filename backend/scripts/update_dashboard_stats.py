import os

file_path = r"c:\Users\mrmoh\Desktop\rentcollections\backend\app\main.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# We need to add stats below pending_payouts_total
old_pending_payouts = """    # Pending Payouts (all types)
    pending_payouts_total = db.query(func.sum(models.Payout.net_amount)).join(
        models.Property
    ).filter(
        models.Property.agency_id == agency_id,
        models.Payout.status == "pending"
    ).scalar() or 0.0"""

new_stats = """    # Pending Payouts (all types)
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
    ).scalar() or 0.0"""

if old_pending_payouts in content:
    content = content.replace(old_pending_payouts, new_stats)
    print("Injected new dashboard stats logic.")
else:
    print("ERROR: old_pending_payouts not found!")

# Update return dict
old_return = """    return {
        "total_properties": total_properties,
        "total_tenants": total_tenants,
        "total_landlords": total_landlords,
        "rent_expected_today": float(rent_expected_today),
        "rent_overdue": float(rent_overdue),
        "rent_collected_total": float(rent_collected_total),
        "payments_on_hold": float(payments_on_hold),
        "pending_payouts": float(pending_payouts_total),
        "due_properties": due_properties
    }"""

new_return = """    return {
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
    }"""

if old_return in content:
    content = content.replace(old_return, new_return)
    print("Updated return statement.")
else:
    print("ERROR: old_return not found!")

# Now, we need to update GET /finance/payouts/ to ensure Tenant and Landlord data is included.
# Payout response already includes `property`, which includes `landlord` (due to `joinedload` perhaps?).
# Let's check `get_all_payouts` in main.py
with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
