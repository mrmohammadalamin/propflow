from sqlalchemy.orm import Session
from datetime import datetime
from .. import models

class LedgerEngine:
    def __init__(self, db: Session, agency_id: int):
        self.db = db
        self.agency_id = agency_id

    def log_contractor_invoice(self, property_id: int, amount: float, contractor_name: str, description: str, user_id: int = None, vat_rate: float = 0.0, vat_amount: float = 0.0) -> models.Invoice:
        """
        Creates a pending invoice. This does not immediately deduct funds, 
        it creates a liability that will be deducted when rent arrives.
        """
        total_amount = amount + vat_amount
        invoice = models.Invoice(
            agency_id=self.agency_id,
            property_id=property_id,
            type="contractor_repair",
            amount=total_amount,
            subtotal=amount,
            vat_rate=vat_rate,
            vat_amount=vat_amount,
            total_amount=total_amount,
            remaining_balance=total_amount,
            description=description,
            contractor_name=contractor_name,
            status="pending_deduction",
            created_by=user_id
        )
        self.db.add(invoice)
        self.db.commit()
        self.db.refresh(invoice)
        
        # Create InvoiceLine
        line = models.InvoiceLine(
            invoice_id=invoice.id,
            description=description,
            unit_price=amount,
            vat_rate=vat_rate,
            vat_amount=vat_amount,
            line_total=total_amount
        )
        self.db.add(line)
        self.db.commit()
        return invoice

    def record_rent_payment(self, property_id: int, tenancy_id: int, tenant_id: int, landlord_id: int, amount: float, source: str = "manual_entry") -> models.Transaction:
        """
        Records rent received. This is the start of the flow that triggers deductions.
        """
        # 1. Create the base 'IN' transaction
        transaction = models.Transaction(
            agency_id=self.agency_id,
            property_id=property_id,
            tenancy_id=tenancy_id,
            tenant_id=tenant_id,
            landlord_id=landlord_id,
            transaction_type="rent_received",
            amount=amount,
            direction="in",
            status="completed",
            source=source
        )
        self.db.add(transaction)
        self.db.commit()
        self.db.refresh(transaction)
        
        # In a full system, calling this function would then trigger the DeductionEngine
        # to calculate fees and pay off pending invoices.
        return transaction
