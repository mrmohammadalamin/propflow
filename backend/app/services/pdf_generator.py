import os
from datetime import datetime
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle

def _build_header(title: str, agency_info: dict, styles: dict) -> Table:
    title_style = styles['Title']
    title_style.textColor = colors.HexColor("#3F51B5")
    title_style.alignment = 0 # Left align
    
    normal_style = styles['Normal']
    normal_style.alignment = 2 # Right align
    
    agency_text = ""
    logo_path = None
    
    if agency_info:
        agency_text = f"<b>{agency_info.get('name', '')}</b><br/>"
        agency_text += f"{(agency_info.get('address') or '').replace(chr(10), '<br/>')}<br/>"
        agency_text += f"Email: {agency_info.get('email', '')}<br/>"
        agency_text += f"Tel: {agency_info.get('contact_number', '')}"
        
        logo_url = agency_info.get('logo_url')
        if logo_url and logo_url.startswith('/documents/'):
            
            from reportlab.platypus import Image
            from reportlab.lib.units import inch
            local_path = logo_url.lstrip('/')
            if os.path.exists(local_path):
                logo_path = Image(local_path, width=1.5*inch, height=1.0*inch)
                
    if logo_path:
        right_column = [logo_path, Paragraph(agency_text, normal_style)]
    else:
        right_column = [Paragraph(agency_text, normal_style)]
        
    data = [
        [Paragraph(title, title_style), right_column]
    ]
    t = Table(data, colWidths=[300, 200])
    t.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('ALIGN', (1, 0), (1, 0), 'RIGHT'),
    ]))
    return t

def generate_landlord_statement(
    landlord_name: str,
    property_address: str,
    month_year: str,
    gross_rent: float,
    management_fee: float,
    maintenance_records: list,
    advance_recovery: float,
    net_payout: float,
    agency_info: dict = None,
    output_dir: str = "documents/invoices",
    landlord_info: dict = None,
    management_fee_base: float = None,
    management_fee_vat: float = None
) -> str:
    os.makedirs(output_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    filename = f"Statement_{landlord_name.replace(' ', '_')}_{timestamp}.pdf"
    filepath = os.path.join(output_dir, filename)
    
    doc = SimpleDocTemplate(filepath, pagesize=letter)
    styles = getSampleStyleSheet()
    normal_style = styles['Normal']
    
    elements = []
    
    # 3-column header
    ll_text = f"<b>{landlord_name}</b><br/>"
    if landlord_info:
        if landlord_info.get('address'):
            ll_text += f"{landlord_info.get('address', '').replace(chr(10), '<br/>')}<br/>"
        if landlord_info.get('email'):
            ll_text += f"Email: {landlord_info.get('email', '')}<br/>"
        if landlord_info.get('mobile_number'):
            ll_text += f"Tel: {landlord_info.get('mobile_number', '')}<br/>"

    title_style = ParagraphStyle(name='InvoiceTitle', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=24, textColor=colors.black, alignment=1)
    middle_col = [Paragraph("INVOICE", title_style)]

    agency_text = ""
    logo_path = None
    if agency_info:
        agency_text = f"<b>{agency_info.get('name', '')}</b><br/>"
        agency_text += f"{(agency_info.get('address') or '').replace(chr(10), '<br/>')}<br/>"
        agency_text += f"Email: {agency_info.get('email', '')}<br/>"
        agency_text += f"Tel: {agency_info.get('contact_number', '')}"
        logo_url = agency_info.get('logo_url')
        if logo_url and logo_url.startswith('/documents/'):
            local_path = logo_url.lstrip('/')
            
            if os.path.exists(local_path):
                from reportlab.platypus import Image
                from reportlab.lib.units import inch
                logo_path = Image(local_path, width=1.5*inch, height=1.0*inch)
    
    right_style = ParagraphStyle(name='RightAlign', parent=styles['Normal'], alignment=2)
    right_col = []
    if logo_path:
        right_col.append(logo_path)
    right_col.append(Paragraph(agency_text, right_style))

    normal_left = ParagraphStyle(name='NormalLeft', parent=styles['Normal'], alignment=0)
    header_table = Table([[Paragraph(ll_text, normal_left), middle_col, right_col]], colWidths=[200, 150, 150])
    header_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('ALIGN', (1, 0), (1, 0), 'CENTER'),
        ('ALIGN', (2, 0), (2, 0), 'RIGHT'),
    ]))
    elements.append(header_table)
    elements.append(Spacer(1, 24))

    invoice_number = f"INV-{timestamp}"
    elements.append(Paragraph(f"<b>Invoice Number:</b> {invoice_number}", normal_left))
    elements.append(Paragraph(f"<b>Invoice Date:</b> {datetime.now().strftime('%d %B %Y')}", normal_left))
    elements.append(Paragraph(f"<b>Property:</b> {property_address}", normal_left))
    elements.append(Paragraph(f"<b>Date Range:</b> {month_year}", normal_left))
    elements.append(Spacer(1, 24))
    
    data = [['Description', 'Amount (£)']]
    data.append(['Gross Rent Collected', f"{gross_rent:.2f}"])
    
    if management_fee_base is not None and management_fee_vat is not None and management_fee_vat > 0:
        data.append(['Management Fees (Base)', f"-{management_fee_base:.2f}"])
        data.append(['VAT on Management Fees', f"-{management_fee_vat:.2f}"])
    else:
        data.append(['Management Fees', f"-{management_fee:.2f}"])
        
    if advance_recovery > 0:
        data.append(['Advance Payment Recovery', f"-{advance_recovery:.2f}"])
    for record in maintenance_records:
        if isinstance(record, dict):
            desc = f"Maintenance: {record.get('type', '')} (by {record.get('provider', '')})"
            cost = float(record.get('cost', 0))
        else:
            desc = f"Maintenance: {record}"
            cost = 0 # Fallback
        data.append([desc, f"-{cost:.2f}"])
    data.append(['TOTAL NET PAYOUT', f"{net_payout:.2f}"])
    
    t = Table(data, colWidths=[400, 100])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#E8EAF6")),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.HexColor("#3F51B5")),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
        ('BACKGROUND', (0, -1), (-1, -1), colors.HexColor("#C8E6C9")),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('TEXTCOLOR', (0, -1), (-1, -1), colors.HexColor("#2E7D32")),
        ('GRID', (0, 0), (-1, -1), 1, colors.grey)
    ]))
    
    elements.append(t)
    elements.append(Spacer(1, 24))
    
    elements.append(Paragraph("Financial Breakdown", ParagraphStyle(name='Section', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=14, textColor=colors.HexColor("#3F51B5"))))
    elements.append(Spacer(1, 12))
    
    gross_total = net_payout
    net_total_val = gross_total / 1.2
    vat = gross_total - net_total_val
    
    financial_data = [
        ['Net Total', f"£{net_total_val:.2f}"],
        ['VAT (20%)', f"£{vat:.2f}"],
        ['Total Gross Amount', f"£{gross_total:.2f}"]
    ]
    t_fin = Table(financial_data, colWidths=[200, 150])
    t_fin.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F5F5F5")),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E0E0E0")),
    ]))
    elements.append(t_fin)
    elements.append(Spacer(1, 24))
    
    elements.append(Paragraph("Thank you for choosing our management services.", normal_left))
    
    doc.build(elements)
    return filepath

def generate_agency_daily_report_pdf(*args, **kwargs) -> str:
    # Kept for backward compatibility, unused
    pass

def generate_landlord_invoice_multi_pdf(data: dict, agency_info: dict = None, output_dir: str = "documents/invoices") -> str:
    os.makedirs(output_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    landlord_name = data['landlord']['name'].replace(' ', '_')
    filename = f"MultiPropertyStatement_{landlord_name}_{timestamp}.pdf"
    filepath = os.path.join(output_dir, filename)
    
    doc = SimpleDocTemplate(filepath, pagesize=letter)
    styles = getSampleStyleSheet()
    normal_style = ParagraphStyle(name='NormalLeft', parent=styles['Normal'], alignment=0)
    section_style = ParagraphStyle(name='Section', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=14, textColor=colors.HexColor("#3F51B5"))

    elements = []
    
    # 3-column header
    ll = data.get('landlord', {})
    ll_text = f"<b>{ll.get('name', '')}</b><br/>"
    if ll.get('address'):
        ll_text += f"{ll.get('address', '').replace(chr(10), '<br/>')}<br/>"
    if ll.get('email'):
        ll_text += f"Email: {ll.get('email', '')}<br/>"
    if ll.get('mobile_number'):
        ll_text += f"Tel: {ll.get('mobile_number', '')}<br/>"

    title_style = ParagraphStyle(name='InvoiceTitle', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=24, textColor=colors.black, alignment=1)
    middle_col = [Paragraph("INVOICE", title_style)]

    agency_text = ""
    logo_path = None
    if agency_info:
        agency_text = f"<b>{agency_info.get('name', '')}</b><br/>"
        agency_text += f"{(agency_info.get('address') or '').replace(chr(10), '<br/>')}<br/>"
        agency_text += f"Email: {agency_info.get('email', '')}<br/>"
        agency_text += f"Tel: {agency_info.get('contact_number', '')}"
        logo_url = agency_info.get('logo_url')
        if logo_url and logo_url.startswith('/documents/'):
            local_path = logo_url.lstrip('/')
            
            if os.path.exists(local_path):
                from reportlab.platypus import Image
                from reportlab.lib.units import inch
                logo_path = Image(local_path, width=1.5*inch, height=1.0*inch)
    
    right_style = ParagraphStyle(name='RightAlign', parent=styles['Normal'], alignment=2)
    right_col = []
    if logo_path:
        right_col.append(logo_path)
    right_col.append(Paragraph(agency_text, right_style))

    header_table = Table([[Paragraph(ll_text, normal_style), middle_col, right_col]], colWidths=[200, 150, 150])
    header_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('ALIGN', (1, 0), (1, 0), 'CENTER'),
        ('ALIGN', (2, 0), (2, 0), 'RIGHT'),
    ]))
    elements.append(header_table)
    elements.append(Spacer(1, 24))

    invoice_number = f"INV-{timestamp}"
    elements.append(Paragraph(f"<b>Invoice Number:</b> {invoice_number}", normal_style))
    elements.append(Paragraph(f"<b>Invoice Date:</b> {datetime.now().strftime('%d %B %Y')}", normal_style))
    elements.append(Paragraph(f"<b>Date Range:</b> {data['date_from']} to {data['date_to']}", normal_style))
    elements.append(Spacer(1, 24))
    
    elements.append(Paragraph("Property-by-Property Breakdown", section_style))
    elements.append(Spacer(1, 12))
    
    table_data = [['Property', 'Rent Collected', 'Maintenance', 'Agent Fees', 'Net Payout']]
    for prop in data['properties_breakdown']:
        table_data.append([
            prop['property_name'],
            f"£{prop['rent_collected']:.2f}",
            f"-£{prop['maintenance_fees']:.2f}",
            f"-£{prop['agent_fees']:.2f}",
            f"£{prop['landlord_payment']:.2f}"
        ])
    
    totals = data['totals']
    table_data.append([
        'TOTALS',
        f"£{totals['total_rent_collected']:.2f}",
        f"-£{totals['total_maintenance_fees']:.2f}",
        f"-£{totals['total_agent_fees']:.2f}",
        f"£{totals['total_landlord_payments']:.2f}"
    ])
    
    t = Table(table_data, colWidths=[200, 80, 80, 80, 80])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#E8EAF6")),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.HexColor("#3F51B5")),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (1, 0), (-1, -1), 'RIGHT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
        ('BACKGROUND', (0, -1), (-1, -1), colors.HexColor("#C8E6C9")),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('TEXTCOLOR', (0, -1), (-1, -1), colors.HexColor("#2E7D32")),
        ('GRID', (0, 0), (-1, -1), 1, colors.grey)
    ]))
    
    elements.append(t)
    elements.append(Spacer(1, 24))
    
    elements.append(Paragraph("Financial Breakdown", section_style))
    elements.append(Spacer(1, 12))
    
    gross_total = totals['total_landlord_payments']
    net_total = gross_total / 1.2
    vat = gross_total - net_total
    
    financial_data = [
        ['Net Total', f"£{net_total:.2f}"],
        ['VAT (20%)', f"£{vat:.2f}"],
        ['Total Gross Amount', f"£{gross_total:.2f}"]
    ]
    t_fin = Table(financial_data, colWidths=[200, 150])
    t_fin.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F5F5F5")),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E0E0E0")),
    ]))
    elements.append(t_fin)
    elements.append(Spacer(1, 24))
    
    elements.append(Paragraph("Thank you for choosing our management services.", normal_style))
    
    doc.build(elements)
    return filepath

def generate_agency_summary_pdf(data: dict, agency_info: dict = None, output_dir: str = "documents/invoices") -> str:
    os.makedirs(output_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    filename = f"AgencySummaryReport_{timestamp}.pdf"
    filepath = os.path.join(output_dir, filename)
    
    doc = SimpleDocTemplate(filepath, pagesize=letter)
    styles = getSampleStyleSheet()
    normal_style = ParagraphStyle(name='NormalLeft', parent=styles['Normal'], alignment=0)
    section_style = ParagraphStyle(name='Section', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=14, textColor=colors.HexColor("#3F51B5"))
    
    elements = []
    
    elements.append(_build_header("Estate Agent Summary Report", agency_info, styles))
    elements.append(Spacer(1, 24))
    
    elements.append(Paragraph(f"<b>Date Range:</b> {data['date_from']} to {data['date_to']}", normal_style))
    elements.append(Paragraph(f"<b>Generated:</b> {datetime.now().strftime('%d %B %Y at %H:%M')}", normal_style))
    elements.append(Spacer(1, 24))
    
    totals = data['totals']
    summary_data = [
        ['Metric', 'Total Value'],
        ['Total Rent Collected', f"£{totals['total_rent_collected']:.2f}"],
        ['Total Agent Fees', f"£{totals['total_agent_fees']:.2f}"],
        ['Total Maintenance Deductions', f"£{totals['total_maintenance_fees']:.2f}"],
        ['Total Actual Maintenance Costs', f"£{totals['total_actual_maintenance_costs']:.2f}"],
        ['Total Landlord Payments', f"£{totals['total_landlord_payments']:.2f}"],
        ['Total Service Provider Payments', f"£{totals['total_service_provider_payments']:.2f}"],
        ['Total Outstanding Distributions', f"£{totals['total_outstanding_distributions']:.2f}"],
        ['Total Completed Distributions', f"£{totals['total_completed_distributions']:.2f}"],
    ]
    
    summary_table = Table(summary_data, colWidths=[350, 150])
    summary_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#E8EAF6")),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.HexColor("#3F51B5")),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('GRID', (0, 0), (-1, -1), 1, colors.HexColor("#E0E0E0")),
    ]))
    
    elements.append(Paragraph("Global Financial Summary", section_style))
    elements.append(Spacer(1, 6))
    elements.append(summary_table)
    elements.append(Spacer(1, 24))
    
    elements.append(Paragraph("Property Details", section_style))
    elements.append(Spacer(1, 6))
    
    if data['details']:
        det_data = [['Property', 'Rent', 'Maint.', 'Agent Fee', 'Landlord Payout']]
        for d in data['details']:
            det_data.append([
                d['property_name'][:30],
                f"£{d['rent_payments_received']:.2f}",
                f"-£{d['maintenance_fees']:.2f}",
                f"-£{d['management_fee_amount']:.2f}",
                f"£{d['landlord_payments_made']:.2f}"
            ])
        det_table = Table(det_data, colWidths=[180, 80, 80, 80, 80])
        det_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#FFF3E0")),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.HexColor("#FB8C00")),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('ALIGN', (1, 0), (-1, -1), 'RIGHT'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E0E0E0")),
        ]))
        elements.append(det_table)
    else:
        elements.append(Paragraph("No property details found.", normal_style))
        
    doc.build(elements)
    return filepath

def generate_tenant_invoice_pdf(data: dict, agency_info: dict = None, output_dir: str = "documents/invoices") -> str:
    os.makedirs(output_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    tenant_name = data['tenant']['name'].replace(' ', '_')
    filename = f"TenantInvoice_{tenant_name}_{timestamp}.pdf"
    filepath = os.path.join(output_dir, filename)
    
    doc = SimpleDocTemplate(filepath, pagesize=letter)
    styles = getSampleStyleSheet()
    normal_style = ParagraphStyle(name='NormalLeft', parent=styles['Normal'], alignment=0)
    section_style = ParagraphStyle(name='Section', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=14, textColor=colors.HexColor("#3F51B5"))
    
    elements = []
    
    # 3-column header
    tenant = data.get('tenant', {})
    tenant_text = f"<b>{tenant.get('name', '')}</b><br/>"
    if tenant.get('email'):
        tenant_text += f"Email: {tenant.get('email', '')}<br/>"
    if tenant.get('phone'):
        tenant_text += f"Tel: {tenant.get('phone', '')}<br/>"

    title_style = ParagraphStyle(name='InvoiceTitle', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=24, textColor=colors.black, alignment=1)
    middle_col = [Paragraph("INVOICE", title_style)]

    agency_text = ""
    logo_path = None
    if agency_info:
        agency_text = f"<b>{agency_info.get('name', '')}</b><br/>"
        agency_text += f"{(agency_info.get('address') or '').replace(chr(10), '<br/>')}<br/>"
        agency_text += f"Email: {agency_info.get('email', '')}<br/>"
        agency_text += f"Tel: {agency_info.get('contact_number', '')}"
        logo_url = agency_info.get('logo_url')
        if logo_url and logo_url.startswith('/documents/'):
            local_path = logo_url.lstrip('/')
            
            if os.path.exists(local_path):
                from reportlab.platypus import Image
                from reportlab.lib.units import inch
                logo_path = Image(local_path, width=1.5*inch, height=1.0*inch)
    
    right_style = ParagraphStyle(name='RightAlign', parent=styles['Normal'], alignment=2)
    right_col = []
    if logo_path:
        right_col.append(logo_path)
    right_col.append(Paragraph(agency_text, right_style))

    header_table = Table([[Paragraph(tenant_text, normal_style), middle_col, right_col]], colWidths=[200, 150, 150])
    header_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('ALIGN', (1, 0), (1, 0), 'CENTER'),
        ('ALIGN', (2, 0), (2, 0), 'RIGHT'),
    ]))
    elements.append(header_table)
    elements.append(Spacer(1, 24))

    invoice_number = f"INV-{timestamp}"
    elements.append(Paragraph(f"<b>Invoice Number:</b> {invoice_number}", normal_style))
    elements.append(Paragraph(f"<b>Invoice Date:</b> {datetime.now().strftime('%d %B %Y')}", normal_style))
    elements.append(Paragraph(f"<b>Property:</b> {data['property']['name']}", normal_style))
    elements.append(Paragraph(f"<b>Date Range:</b> {data['date_from']} to {data['date_to']}", normal_style))
    elements.append(Spacer(1, 24))
    
    # Rent schedule breakdown
    elements.append(Paragraph("Rent Schedule Summary", section_style))
    elements.append(Spacer(1, 12))
    
    rent_data = [['Due Date', 'Expected (£)', 'Paid (£)', 'Status']]
    for rs in data['rent_schedule']:
        rent_data.append([
            rs['due_date'],
            f"{rs['expected_amount']:.2f}",
            f"{rs['paid_amount']:.2f}",
            rs['status'].capitalize()
        ])
    
    t_rent = Table(rent_data, colWidths=[150, 100, 100, 100])
    t_rent.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#E8EAF6")),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.HexColor("#3F51B5")),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (1, 0), (2, -1), 'RIGHT'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E0E0E0")),
    ]))
    elements.append(t_rent)
    elements.append(Spacer(1, 24))
    
    # Transactions breakdown
    if data['transactions']:
        elements.append(Paragraph("Payments Received", section_style))
        elements.append(Spacer(1, 12))
        
        tx_data = [['Payment Date', 'Reference', 'Amount (£)', 'Status']]
        for tx in data['transactions']:
            tx_data.append([
                tx['date'],
                tx['reference'],
                f"{tx['amount']:.2f}",
                tx['status'].capitalize()
            ])
            
        t_tx = Table(tx_data, colWidths=[150, 150, 100, 100])
        t_tx.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#FFF3E0")),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.HexColor("#FB8C00")),
            ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
            ('ALIGN', (2, 0), (2, -1), 'RIGHT'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E0E0E0")),
        ]))
        elements.append(t_tx)
        elements.append(Spacer(1, 24))
        
    # Totals
    totals = data['totals']
    tot_data = [
        ['TOTAL RENT DUE', f"£{totals['total_rent_due']:.2f}"],
        ['TOTAL RENT PAID', f"£{totals['total_rent_paid']:.2f}"],
        ['OUTSTANDING BALANCE', f"£{totals['outstanding_balance']:.2f}"],
    ]
    
    t_tot = Table(tot_data, colWidths=[350, 150])
    t_tot.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#FCE4EC")),
        ('TEXTCOLOR', (0, 0), (-1, -1), colors.HexColor("#D81B60")),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica-Bold'),
        ('GRID', (0, 0), (-1, -1), 1, colors.HexColor("#F48FB1")),
    ]))
    elements.append(t_tot)
    elements.append(Spacer(1, 24))
    
    elements.append(Paragraph("Financial Breakdown", section_style))
    elements.append(Spacer(1, 12))
    
    gross_total = totals['total_rent_due']
    net_total = gross_total / 1.2
    vat = gross_total - net_total
    
    financial_data = [
        ['Net Total', f"£{net_total:.2f}"],
        ['VAT (20%)', f"£{vat:.2f}"],
        ['Total Gross Amount', f"£{gross_total:.2f}"]
    ]
    t_fin = Table(financial_data, colWidths=[200, 150])
    t_fin.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F5F5F5")),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ('FONTNAME', (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor("#E0E0E0")),
    ]))
    elements.append(t_fin)
    elements.append(Spacer(1, 24))
    
    elements.append(Spacer(1, 32))
    elements.append(Paragraph("Thank you for your prompt payment.", normal_style))
    
    doc.build(elements)
    return filepath

def generate_agency_property_statement_pdf(data: dict, agency_info: dict = None, output_dir: str = "documents/invoices") -> str:
    os.makedirs(output_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    filename = f"PropertyStatement_{timestamp}.pdf"
    filepath = os.path.join(output_dir, filename)
    
    doc = SimpleDocTemplate(filepath, pagesize=letter)
    styles = getSampleStyleSheet()
    normal_style = styles['Normal']
    
    elements = []
    
    # Header: Name left, Logo right top, Address right bottom
    left_header = []
    right_header = []
    
    if agency_info:
        logo_url = agency_info.get('logo_url')
        logo_path = None
        if logo_url and logo_url.startswith('/documents/'):
            logo_path = os.path.join("documents", logo_url.replace('/documents/', ''))
        
        left_header.append(Paragraph(f"<b>{str(agency_info.get('name', '')).upper()}</b>", ParagraphStyle('Left1', parent=normal_style, fontSize=16, fontName='Helvetica-Bold')))
        left_header.append(Spacer(1, 4))
        left_header.append(Paragraph("BESPOKE PROPERTY MANAGEMENT", ParagraphStyle('Left2', parent=normal_style, fontSize=8, textColor=colors.grey)))
        
        if logo_path and os.path.exists(logo_path):
            from reportlab.platypus import Image
            img = Image(logo_path, width=100, height=33)
            img.hAlign = 'RIGHT'
            right_header.append(img)
            right_header.append(Spacer(1, 4))
            
        right_side = Paragraph(
            f"{(agency_info.get('address') or '').replace(chr(10), ', ')}<br/>"
            f"{agency_info.get('contact_number', '')}<br/>"
            f"{agency_info.get('email', '')}",
            ParagraphStyle('RightAlign', parent=styles['Normal'], alignment=2, fontSize=8, textColor=colors.grey)
        )
        right_header.append(right_side)
    
    header_table = Table([[left_header, right_header]], colWidths=[270, 270])
    header_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (0, 0), 'LEFT'),
        ('ALIGN', (1, 0), (1, 0), 'RIGHT'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    elements.append(header_table)
    elements.append(Spacer(1, 20))
    
    # Divider Line
    elements.append(Table([['']], colWidths=[540], style=[('LINEABOVE', (0,0), (-1,-1), 0.5, colors.lightgrey)]))
    elements.append(Spacer(1, 20))
    
    # Statement Details
    left_details = []
    left_details.append(Paragraph("Statement of Account", ParagraphStyle('Title', parent=normal_style, fontSize=16, fontName='Helvetica-Bold')))
    left_details.append(Spacer(1, 10))
    
    details_table_data = [
        [Paragraph("<b>LANDLORD</b>", ParagraphStyle('L1', fontSize=7, textColor=colors.grey)), Paragraph(f"<b>{data.get('landlord_name', '')}</b>", ParagraphStyle('L2', fontSize=9))],
        [Paragraph("<b>PROPERTY</b>", ParagraphStyle('L1', fontSize=7, textColor=colors.grey)), Paragraph(f"<b>{data.get('property', {}).get('address', '')}</b>", ParagraphStyle('L2', fontSize=9))],
        [Paragraph("<b>PERIOD</b>", ParagraphStyle('L1', fontSize=7, textColor=colors.grey)), Paragraph(f"<b>{data.get('date_from')} to {data.get('date_to')}</b>", ParagraphStyle('L2', fontSize=9))]
    ]
    details_table = Table(details_table_data, colWidths=[80, 220])
    details_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
    ]))
    left_details.append(details_table)
    
    right_details = []
    right_details.append(Paragraph("DATE OF ISSUE", ParagraphStyle('R1', parent=normal_style, alignment=2, fontSize=7, textColor=colors.grey)))
    right_details.append(Paragraph(f"<b>{datetime.now().strftime('%d %B %Y')}</b>", ParagraphStyle('R2', parent=normal_style, alignment=2, fontSize=9)))
    
    statement_table = Table([[left_details, right_details]], colWidths=[350, 190])
    statement_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (0, 0), 'LEFT'),
        ('ALIGN', (1, 0), (1, 0), 'RIGHT'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    elements.append(statement_table)
    elements.append(Spacer(1, 20))
    
    # 3 Summary Boxes
    box_width = 175
    income_val = data.get('total_rental_income', 0.0)
    exp_val = data.get('total_expenses', 0.0)
    payout_val = data.get('net_landlord_payout', 0.0)
    
    b1 = [
        Paragraph("TOTAL RENTAL INCOME", ParagraphStyle('B1', fontSize=6, textColor=colors.grey, alignment=1)),
        Spacer(1, 10),
        Paragraph(f"<b>£{income_val:,.2f}</b>", ParagraphStyle('B1v', fontSize=12, textColor=colors.black, alignment=1))
    ]
    b2 = [
        Paragraph("EXPENSES & FEES", ParagraphStyle('B2', fontSize=6, textColor=colors.grey, alignment=1)),
        Spacer(1, 10),
        Paragraph(f"<b>£{exp_val:,.2f}</b>", ParagraphStyle('B2v', fontSize=12, textColor=colors.red, alignment=1))
    ]
    b3 = [
        Paragraph("NET LANDLORD PAYOUT", ParagraphStyle('B3', fontSize=6, textColor=colors.white, alignment=1)),
        Spacer(1, 10),
        Paragraph(f"<b>£{payout_val:,.2f}</b>", ParagraphStyle('B3v', fontSize=12, textColor=colors.white, alignment=1))
    ]
    
    summary_table = Table([[b1, b2, b3]], colWidths=[box_width, box_width, box_width])
    summary_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('BOX', (0, 0), (0, 0), 0.5, colors.lightgrey),
        ('BOX', (1, 0), (1, 0), 0.5, colors.lightgrey),
        ('BOX', (2, 0), (2, 0), 0.5, colors.black),
        ('BACKGROUND', (2, 0), (2, 0), colors.HexColor('#1a1a1a')),
        ('TOPPADDING', (0, 0), (-1, -1), 15),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 15),
        ('LEFTPADDING', (0, 0), (-1, -1), 10),
        ('RIGHTPADDING', (0, 0), (-1, -1), 10),
    ]))
    elements.append(summary_table)
    elements.append(Spacer(1, 30))
    
    elements.append(Paragraph("<b>Financial Ledger</b>", ParagraphStyle('LedgerTitle', parent=normal_style, fontSize=12, fontName='Helvetica-Bold')))
    elements.append(Spacer(1, 10))
    
    # Ledger Table
    table_data = [
        [
            Paragraph("<b>DATE</b>", ParagraphStyle('TH', fontSize=6, textColor=colors.grey)),
            Paragraph("<b>DESCRIPTION</b>", ParagraphStyle('TH', fontSize=6, textColor=colors.grey)),
            Paragraph("<b>INCOME</b>", ParagraphStyle('TH', fontSize=6, textColor=colors.grey, alignment=2)),
            Paragraph("<b>EXPENSES</b>", ParagraphStyle('TH', fontSize=6, textColor=colors.grey, alignment=2)),
            Paragraph("<b>LANDLORD PAYOUT</b>", ParagraphStyle('TH', fontSize=6, textColor=colors.grey, alignment=2))
        ]
    ]
    
    for row in data.get('ledger', []):
        credit_str = Paragraph(f"£{row['credit']:,.2f}", ParagraphStyle('TDc', fontSize=7, textColor=colors.HexColor('#2E7D32'), alignment=2)) if row['credit'] > 0 else Paragraph("—", ParagraphStyle('TD', fontSize=7, textColor=colors.grey, alignment=2))
        
        is_payout = "Landlord Payment" in row['description']
        exp_str = Paragraph("—", ParagraphStyle('TD', fontSize=7, textColor=colors.grey, alignment=2))
        payout_str = Paragraph("—", ParagraphStyle('TD', fontSize=7, textColor=colors.grey, alignment=2))
        
        if row['charge'] > 0:
            if is_payout:
                payout_str = Paragraph(f"£{row['charge']:,.2f}", ParagraphStyle('TDp', fontSize=7, textColor=colors.HexColor('#1976D2'), alignment=2))
            else:
                exp_str = Paragraph(f"£{row['charge']:,.2f}", ParagraphStyle('TDe', fontSize=7, textColor=colors.red, alignment=2))
                
        table_data.append([
            Paragraph(row['date'], ParagraphStyle('TD', fontSize=7, textColor=colors.black)),
            Paragraph(row['description'], ParagraphStyle('TD', fontSize=7, textColor=colors.black)),
            credit_str,
            exp_str,
            payout_str
        ])
    
    # Totals Row
    table_data.append([
        Paragraph("<b>TOTALS</b>", ParagraphStyle('TF', fontSize=7, textColor=colors.black, fontName='Helvetica-Bold')),
        Paragraph("", ParagraphStyle('TF', fontSize=7)),
        Paragraph(f"<b>£{income_val:,.2f}</b>", ParagraphStyle('TFc', fontSize=7, textColor=colors.HexColor('#2E7D32'), alignment=2, fontName='Helvetica-Bold')),
        Paragraph(f"<b>£{exp_val:,.2f}</b>", ParagraphStyle('TFe', fontSize=7, textColor=colors.red, alignment=2, fontName='Helvetica-Bold')),
        Paragraph(f"<b>£{payout_val:,.2f}</b>", ParagraphStyle('TFp', fontSize=7, textColor=colors.HexColor('#1976D2'), alignment=2, fontName='Helvetica-Bold'))
    ])
    
    t = Table(table_data, colWidths=[65, 235, 75, 75, 90])
    t.setStyle(TableStyle([
        ('LINEBELOW', (0, 0), (-1, 0), 1, colors.black),
        ('LINEBELOW', (0, -2), (-1, -2), 1, colors.black),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    
    elements.append(t)
    
    def add_footer(canvas, doc):
        canvas.saveState()
        canvas.setFont('Helvetica', 6)
        canvas.setFillColor(colors.grey)
        # Footer text based on screenshot
        agency_name = agency_info.get('name', 'Allen Goldstein') if agency_info else 'Allen Goldstein'
        footer_text1 = f"Confidential Document © {datetime.now().year} {agency_name} Limited. All rights reserved."
        footer_text2 = "Registered in England & Wales. Authorized and Regulated by the Property Redress Scheme."
        
        canvas.drawCentredString(letter[0] / 2.0, 30, footer_text1)
        canvas.drawCentredString(letter[0] / 2.0, 20, footer_text2)
        canvas.restoreState()
        
    doc.build(elements, onFirstPage=add_footer, onLaterPages=add_footer)
    return filepath

from jinja2 import Template
from xhtml2pdf import pisa
import io

import json
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4, letter
from reportlab.lib.utils import ImageReader
from PyPDF2 import PdfReader, PdfWriter
import io

def generate_pdf_from_template(template, data: dict, output_dir: str = "documents/invoices") -> str:
    os.makedirs(output_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    filename_base = template.document_type.replace(" ", "_")
    filename = f"{filename_base}_{timestamp}.pdf"
    filepath = os.path.join(output_dir, filename)
    
    if template.template_type == "html":
        # Fallback to old HTML logic if needed
        header_tmpl = Template(getattr(template, 'header_html', ''))
        body_tmpl = Template(getattr(template, 'body_html', ''))
        footer_tmpl = Template(getattr(template, 'footer_html', ''))
        
        header_html = header_tmpl.render(**data)
        body_html = body_tmpl.render(**data)
        footer_html = footer_tmpl.render(**data)
        
        css = f"""
        @page {{
            size: {template.paper_size.lower() if template.paper_size else 'a4'};
            margin-top: {template.margin_top}px;
            margin-bottom: {template.margin_bottom}px;
            margin-left: {template.margin_left}px;
            margin-right: {template.margin_right}px;
            @frame header_frame {{
                -pdf-frame-content: header_content;
                left: {template.margin_left}px; width: 100%; top: 20px; height: 100px;
            }}
            @frame footer_frame {{
                -pdf-frame-content: footer_content;
                left: {template.margin_left}px; width: 100%; bottom: 20px; height: 50px;
            }}
        }}
        body {{ font-family: Helvetica, Arial, sans-serif; }}
        """
        
        html = f"""
        <html>
        <head><style>{css}</style></head>
        <body>
            <div id="header_content">{header_html}</div>
            <div id="footer_content">{footer_html}</div>
            {body_html}
        </body>
        </html>
        """
        
        with open(filepath, "w+b") as result_file:
            pisa_status = pisa.CreatePDF(html, dest=result_file)
            
        if pisa_status.err:
            raise Exception("Error generating HTML PDF")
            
        return filepath
        
    elif template.template_type == "visual":
        # Use ReportLab for Coordinate-based rendering
        pagesize = letter if template.paper_size == 'Letter' else A4
        packet = io.BytesIO()
        c = canvas.Canvas(packet, pagesize=pagesize)
        
        # Flatten the data context to easily access properties
        # For simplicity in this visual editor, we just use string replacement on a flattened dict
        flat_data = {}
        def flatten(d, parent_key=''):
            for k, v in d.items():
                new_key = f"{parent_key}.{k}" if parent_key else k
                if isinstance(v, dict):
                    flatten(v, new_key)
                else:
                    flat_data[new_key] = str(v)
        flatten(data)
        
        config = []
        if template.visual_config:
            try:
                config = json.loads(template.visual_config)
            except:
                pass
                
        for item in config:
            text = item.get('text', '')
            x = item.get('x', 50)
            # ReportLab's Y is from bottom, UI might send Y from top
            y = pagesize[1] - item.get('y', 50)
            
            # Replace placeholders manually since it's just raw text fields now
            import re
            def replacer(match):
                key = match.group(1).strip()
                return flat_data.get(key, match.group(0))
            
            text = re.sub(r'\{\{(.*?)\}\}', replacer, text)
            
            c.setFont("Helvetica", item.get('fontSize', 12))
            c.drawString(x, y, text)
            
        c.save()
        packet.seek(0)
        
        # Merge with background if provided
        if template.background_file_url and os.path.exists(template.background_file_url):
            try:
                background_pdf = PdfReader(open(template.background_file_url, "rb"))
                new_pdf = PdfReader(packet)
                output = PdfWriter()
                
                # Assume 1 page for now
                page = background_pdf.pages[0]
                page.merge_page(new_pdf.pages[0])
                output.add_page(page)
                
                with open(filepath, "wb") as f:
                    output.write(f)
            except Exception as e:
                print(f"Error merging PDF: {e}")
                # Fallback to just the overlay
                with open(filepath, "wb") as f:
                    f.write(packet.read())
        else:
            with open(filepath, "wb") as f:
                f.write(packet.read())
                
        return filepath
        
    else:
        raise Exception("Unsupported template_type")


