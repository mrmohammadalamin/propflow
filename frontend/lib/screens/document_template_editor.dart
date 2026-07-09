import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DocumentTemplateEditor extends StatefulWidget {
  final Map<String, dynamic>? template;

  const DocumentTemplateEditor({super.key, this.template});

  @override
  State<DocumentTemplateEditor> createState() => _DocumentTemplateEditorState();
}

class _DocumentTemplateEditorState extends State<DocumentTemplateEditor> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _headerController;
  late TextEditingController _bodyController;
  late TextEditingController _footerController;
  
  String _documentType = 'landlord_invoice_single';
  bool _isDefault = false;
  String _paperSize = 'A4';
  String _orientation = 'Portrait';
  double _marginTop = 20.0;
  double _marginBottom = 20.0;
  double _marginLeft = 20.0;
  double _marginRight = 20.0;

  final List<String> _documentTypes = [
    'landlord_invoice_single',
    'landlord_invoice_multi',
    'tenant_invoice',
    'agency_summary',
    'agency_property_statement'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?['name'] ?? '');
    _headerController = TextEditingController(text: widget.template?['header_html'] ?? '');
    _bodyController = TextEditingController(text: widget.template?['body_html'] ?? '');
    _footerController = TextEditingController(text: widget.template?['footer_html'] ?? '');
    
    if (widget.template != null) {
      _documentType = widget.template!['document_type'];
      _isDefault = widget.template!['is_default'];
      _paperSize = widget.template!['paper_size'] ?? 'A4';
      _orientation = widget.template!['orientation'] ?? 'Portrait';
      _marginTop = (widget.template!['margin_top'] ?? 20.0).toDouble();
      _marginBottom = (widget.template!['margin_bottom'] ?? 20.0).toDouble();
      _marginLeft = (widget.template!['margin_left'] ?? 20.0).toDouble();
      _marginRight = (widget.template!['margin_right'] ?? 20.0).toDouble();
    }
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;
    
    final payload = {
      'name': _nameController.text,
      'document_type': _documentType,
      'is_default': _isDefault,
      'paper_size': _paperSize,
      'orientation': _orientation,
      'margin_top': _marginTop,
      'margin_bottom': _marginBottom,
      'margin_left': _marginLeft,
      'margin_right': _marginRight,
      'header_html': _headerController.text,
      'body_html': _bodyController.text,
      'footer_html': _footerController.text,
    };

    try {
      http.Response response;
      if (widget.template == null) {
        response = await http.post(
          Uri.parse('http://127.0.0.1:8000/api/templates'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        );
      } else {
        response = await http.put(
          Uri.parse('http://127.0.0.1:8000/api/templates/${widget.template!['id']}'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload),
        );
      }

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving template: ${response.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'Create Template' : 'Edit Template'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveTemplate,
            tooltip: 'Save Template',
          )
        ],
      ),
      body: Row(
        children: [
          // Main Editor Area
          Expanded(
            flex: 3,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Basic Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Basic Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Template Name', border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _documentType,
                            decoration: const InputDecoration(labelText: 'Document Type', border: OutlineInputBorder()),
                            items: _documentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _documentType = v!),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Set as Default for this Type'),
                            value: _isDefault,
                            onChanged: (v) => setState(() => _isDefault = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Page Settings Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Page Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _paperSize,
                                  decoration: const InputDecoration(labelText: 'Paper Size', border: OutlineInputBorder()),
                                  items: ['A4', 'A5', 'Letter', 'Legal'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                  onChanged: (v) => setState(() => _paperSize = v!),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _orientation,
                                  decoration: const InputDecoration(labelText: 'Orientation', border: OutlineInputBorder()),
                                  items: ['Portrait', 'Landscape'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                  onChanged: (v) => setState(() => _orientation = v!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('Margins (px)'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: _marginTop.toString(),
                                  decoration: const InputDecoration(labelText: 'Top', border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => _marginTop = double.tryParse(v) ?? 20.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _marginBottom.toString(),
                                  decoration: const InputDecoration(labelText: 'Bottom', border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => _marginBottom = double.tryParse(v) ?? 20.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _marginLeft.toString(),
                                  decoration: const InputDecoration(labelText: 'Left', border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => _marginLeft = double.tryParse(v) ?? 20.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _marginRight.toString(),
                                  decoration: const InputDecoration(labelText: 'Right', border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => _marginRight = double.tryParse(v) ?? 20.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // HTML Content Editor
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Template Content (HTML + Jinja2 variables)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _headerController,
                            decoration: const InputDecoration(labelText: 'Header HTML', border: OutlineInputBorder(), alignLabelWithHint: true),
                            maxLines: 5,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _bodyController,
                            decoration: const InputDecoration(labelText: 'Body HTML', border: OutlineInputBorder(), alignLabelWithHint: true),
                            maxLines: 15,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _footerController,
                            decoration: const InputDecoration(labelText: 'Footer HTML', border: OutlineInputBorder(), alignLabelWithHint: true),
                            maxLines: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Sidebar with Placeholders
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Variables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: const [
                        ListTile(title: Text('{{ agency_info.name }}'), subtitle: Text('Agency Name')),
                        ListTile(title: Text('{{ agency_info.address }}'), subtitle: Text('Agency Address')),
                        ListTile(title: Text('{{ agency_info.email }}'), subtitle: Text('Agency Email')),
                        ListTile(title: Text('{{ agency_info.logo_url }}'), subtitle: Text('Agency Logo URL')),
                        Divider(),
                        ListTile(title: Text('{{ property.name }}'), subtitle: Text('Property Address')),
                        ListTile(title: Text('{{ landlord.name }}'), subtitle: Text('Landlord Name')),
                        ListTile(title: Text('{{ tenant.name }}'), subtitle: Text('Tenant Name')),
                        Divider(),
                        ListTile(title: Text('{{ date_from }}'), subtitle: Text('Report Start Date')),
                        ListTile(title: Text('{{ date_to }}'), subtitle: Text('Report End Date')),
                        Divider(),
                        ListTile(title: Text('{% for row in ledger %}...{% endfor %}'), subtitle: Text('Loop over ledger entries (for statements)')),
                        ListTile(title: Text('{% for prop in properties_breakdown %}...{% endfor %}'), subtitle: Text('Loop over properties (for multi-statement)')),
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
