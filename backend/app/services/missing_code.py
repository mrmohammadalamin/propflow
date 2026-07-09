    section_style = ParagraphStyle(name='Section', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=14, textColor=colors.HexColor("#3F51B5"))

    elements = []
    
    elements.append(_build_header("Consolidated Landlord Statement", agency_info, styles))
    elements.append(Spacer(1, 24))
    
    elements.append(Paragraph(f"<b>Landlord:</b> {data['landlord']['name']}", normal_style))
    elements.append(Paragraph(f"<b>Date Range:</b> {data['date_from']} to {data['date_to']}", normal_style))
    elements.append(Paragraph(f"<b>Statement Date:</b> {datetime.now().strftime('%d %B %Y')}", normal_style))
    elements.append(Spacer(1, 16))

    invoice_number = f"INV-{timestamp}"
    title_style = ParagraphStyle(name='InvoiceTitle', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=24, textColor=colors.black)
    elements.append(Paragraph("INVOICE", title_style))
    elements.append(Paragraph(f"<b>Invoice Number:</b> {invoice_number}", normal_style))
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
    
    elements.append(_build_header("Tenant Rent Invoice", agency_info, styles))
    elements.append(Spacer(1, 24))
    
    elements.append(Paragraph(f"<b>Tenant:</b> {data['tenant']['name']}", normal_style))
    elements.append(Paragraph(f"<b>Property:</b> {data['property']['name']}", normal_style))
    elements.append(Paragraph(f"<b>Date Range:</b> {data['date_from']} to {data['date_to']}", normal_style))
    elements.append(Paragraph(f"<b>Issue Date:</b> {datetime.now().strftime('%d %B %Y')}", normal_style))
    elements.append(Spacer(1, 16))

    invoice_number = f"INV-{timestamp}"
    title_style = ParagraphStyle(name='InvoiceTitle', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=24, textColor=colors.black)
    elements.append(Paragraph("INVOICE", title_style))
    elements.append(Paragraph(f"<b>Invoice Number:</b> {invoice_number}", normal_style))
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

def generate_agency_property_statement_pdf(
