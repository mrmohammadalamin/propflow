import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agentic_ui/services/api_service.dart';
import 'package:flutter_html/flutter_html.dart';

class EmailTemplatesScreen extends StatefulWidget {
  const EmailTemplatesScreen({super.key});

  @override
  State<EmailTemplatesScreen> createState() => _EmailTemplatesScreenState();
}

class _EmailTemplatesScreenState extends State<EmailTemplatesScreen> {
  List<dynamic> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/email-settings/templates?agency_id=${api.agencyId}');
      setState(() {
        _templates = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openEditor({Map<String, dynamic>? template}) {
    showDialog(
      context: context,
      builder: (context) => EmailTemplateEditor(
        template: template,
        onSave: () {
          Navigator.pop(context);
          _loadTemplates();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(),
            tooltip: 'Create New Template',
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Create New Template', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _templates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("No templates found.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _openEditor(),
                              child: const Text('Create Your First Template'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _templates.length,
                        itemBuilder: (context, index) {
                          final t = _templates[index];
                          return Card(
                            child: ListTile(
                              title: Text(t['name']),
                              subtitle: Text('Subject: ${t['subject']}'),
                              trailing: Switch(
                                value: t['is_active'] ?? true,
                                onChanged: null, // Readonly in list
                              ),
                              onTap: () {
                                // Fetch full template to edit
                                Provider.of<ApiService>(context, listen: false)
                                    .get('/email-settings/templates/${t['id']}?agency_id=${Provider.of<ApiService>(context, listen: false).agencyId}')
                                    .then((fullTemplate) => _openEditor(template: fullTemplate));
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class EmailTemplateEditor extends StatefulWidget {
  final Map<String, dynamic>? template;
  final VoidCallback onSave;

  const EmailTemplateEditor({super.key, this.template, required this.onSave});

  @override
  State<EmailTemplateEditor> createState() => _EmailTemplateEditorState();
}

class _EmailTemplateEditorState extends State<EmailTemplateEditor> {
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _subjectFocus = FocusNode();
  final _bodyFocus = FocusNode();
  bool _isActive = true;

  final List<Map<String, dynamic>> _variableGroups = [
    {
      'group': 'Tenant Details',
      'icon': Icons.person,
      'vars': ['{{Tenant First Name}}', '{{Tenant Last Name}}', '{{Tenant Name}}', '{{Tenant Email}}', '{{Tenant Phone}}']
    },
    {
      'group': 'Property Details',
      'icon': Icons.house,
      'vars': ['{{Property Room No}}', '{{Property Address Line 1}}', '{{Property Address}}', '{{Property City}}', '{{Property Postcode}}']
    },
    {
      'group': 'Landlord Details',
      'icon': Icons.real_estate_agent,
      'vars': ['{{Landlord First Name}}', '{{Landlord Last Name}}', '{{Landlord Name}}']
    },
    {
      'group': 'Rent Details',
      'icon': Icons.attach_money,
      'vars': ['{{Rent Due Date}}', '{{Expected Amount}}', '{{Paid Amount}}', '{{Outstanding Amount}}', '{{Days Offset}}']
    }
  ];

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _nameController.text = widget.template!['name'];
      _subjectController.text = widget.template!['subject'];
      _bodyController.text = widget.template!['body_html'] ?? '';
      _isActive = widget.template!['is_active'] ?? true;
    }
  }

  @override
  void dispose() {
    _subjectFocus.dispose();
    _bodyFocus.dispose();
    _nameController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _insertPlaceholder(String placeholder, TextEditingController activeController) {
    final text = activeController.text;
    final selection = activeController.selection;
    if (selection.baseOffset >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, placeholder);
      activeController.value = activeController.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + placeholder.length),
      );
    } else {
      activeController.text += placeholder;
    }
  }

  void _showVariablePicker(TextEditingController targetController) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Insert Variable', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Click a variable below to insert it.'),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _variableGroups.length,
                      itemBuilder: (context, index) {
                        final group = _variableGroups[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(group['icon'], size: 18, color: Colors.indigo),
                                  const SizedBox(width: 8),
                                  Text(group['group'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: (group['vars'] as List<String>).map((p) {
                                return ActionChip(
                                  label: Text(p, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.black87)),
                                  onPressed: () {
                                    _insertPlaceholder(p, targetController);
                                  },
                                  backgroundColor: Colors.grey.shade200,
                                  side: BorderSide(color: Colors.grey.shade400),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final data = {
      'name': _nameController.text,
      'subject': _subjectController.text,
      'body_html': _bodyController.text,
      'is_active': _isActive,
    };

    try {
      if (widget.template == null) {
        await api.post('/email-settings/templates?agency_id=${api.agencyId}', data);
      } else {
        await api.put('/email-settings/templates/${widget.template!['id']}?agency_id=${api.agencyId}', data);
      }
      widget.onSave();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save template')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.template == null ? 'Create Template' : 'Edit Template'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Template Name (e.g. Rent Overdue)'),
                readOnly: widget.template != null, // Don't allow changing name easily if it's used elsewhere
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectController,
                focusNode: _subjectFocus,
                decoration: InputDecoration(
                  labelText: 'Email Subject',
                  hintText: 'e.g. Rent Overdue for {{Property Address}}',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.data_object, color: Colors.indigo),
                    tooltip: 'Insert Variable',
                    onPressed: () => _showVariablePicker(_subjectController),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bodyController,
                focusNode: _bodyFocus,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'HTML Body',
                  hintText: 'Dear {{Tenant Name}}, your rent for {{Property Address}} is due...',
                  border: const OutlineInputBorder(),
                  suffixIcon: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.data_object, color: Colors.indigo),
                        tooltip: 'Insert Variable',
                        onPressed: () => _showVariablePicker(_bodyController),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
