import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agentic_ui/services/api_service.dart';

class EmailCampaignsScreen extends StatefulWidget {
  const EmailCampaignsScreen({super.key});

  @override
  State<EmailCampaignsScreen> createState() => _EmailCampaignsScreenState();
}

class _EmailCampaignsScreenState extends State<EmailCampaignsScreen> {
  List<dynamic> _campaigns = [];
  List<dynamic> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final campaigns = await api.get('/email-settings/campaigns?agency_id=${api.agencyId}');
      final templates = await api.get('/email-settings/templates?agency_id=${api.agencyId}');
      setState(() {
        _campaigns = campaigns is List ? campaigns : [];
        _templates = templates is List ? templates : [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openCampaignEditor({Map<String, dynamic>? campaign}) async {
    // Ensure we have the freshest templates list before opening the editor
    await _loadData();
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => EmailCampaignEditor(
        campaign: campaign,
        templates: _templates,
        onSave: () {
          Navigator.pop(context);
          _loadData();
        },
      ),
    );
  }

  Future<void> _deleteCampaign(int id) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.delete('/email-settings/campaigns/$id?agency_id=${api.agencyId}');
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete campaign')));
    }
  }

  Future<void> _triggerScheduler() async {
    final api = Provider.of<ApiService>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Triggering email scheduler...')));
    try {
      await api.post('/email-settings/campaigns/trigger-scheduler?agency_id=${api.agencyId}', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scheduler finished! Check Email Activity tab.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to trigger scheduler')));
    }
  }


  Future<void> _testCampaign(int campaignId) async {
    final emailController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Campaign'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your email address to receive a test email using sample tenant data:'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, emailController.text.trim()), 
            child: const Text('Send Test')
          ),
        ],
      )
    );

    if (result != null && result.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending test email...')));
      final api = Provider.of<ApiService>(context, listen: false);
      try {
        await api.post('/email-settings/campaigns/$campaignId/test?agency_id=${api.agencyId}', {'test_email': result});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test email sent successfully!')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send test: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Email Campaigns (Automatic Reminders)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openCampaignEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('New Campaign'),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          _campaigns.isEmpty
              ? const Card(child: Padding(padding: EdgeInsets.all(32.0), child: Text("No active campaigns. Create one above!")))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _campaigns.length,
                  itemBuilder: (context, index) {
                    final c = _campaigns[index];
                    final templateName = _templates.firstWhere((t) => t['id'] == c['template_id'], orElse: () => {'name': 'Unknown'})['name'];
                    
                    return Card(
                      child: ListTile(
                        title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Trigger: ${c['trigger_type']} | Offset Days: ${c['days_offset']}\nTemplate: $templateName'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: c['is_active'] ?? true,
                              onChanged: null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.green),
                              tooltip: 'Test Campaign',
                              onPressed: () => _testCampaign(c['id']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _openCampaignEditor(campaign: c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCampaign(c['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

class EmailCampaignEditor extends StatefulWidget {
  final Map<String, dynamic>? campaign;
  final List<dynamic> templates;
  final VoidCallback onSave;

  const EmailCampaignEditor({super.key, this.campaign, required this.templates, required this.onSave});

  @override
  State<EmailCampaignEditor> createState() => _EmailCampaignEditorState();
}

class _EmailCampaignEditorState extends State<EmailCampaignEditor> {
  final _nameController = TextEditingController();
  String _triggerType = 'rent_overdue';
  int? _templateId;
  List<int> _selectedDays = [];
  final List<int> _availableDays = [0, 1, 3, 5, 7, 14, 30]; // 0 means on due date
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.templates.isNotEmpty) {
      final firstId = widget.templates.first['id'];
      _templateId = firstId is int ? firstId : int.tryParse(firstId.toString());
    }
    
    if (widget.campaign != null) {
      _nameController.text = widget.campaign!['name'];
      _triggerType = widget.campaign!['trigger_type'];
      
      final tId = widget.campaign!['template_id'];
      _templateId = tId is int ? tId : int.tryParse(tId.toString());

      _isActive = widget.campaign!['is_active'] ?? true;
      
      String daysStr = widget.campaign!['days_offset'] ?? '';
      if (daysStr.isNotEmpty) {
        _selectedDays = daysStr.split(',').map((e) => int.tryParse(e.trim()) ?? -1).where((e) => e >= 0).toList();
      }
    }
  }

  Future<void> _save() async {
    if (_templateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a template')));
      return;
    }

    final api = Provider.of<ApiService>(context, listen: false);
    _selectedDays.sort();
    
    final data = {
      'name': _nameController.text,
      'trigger_type': _triggerType,
      'days_offset': _selectedDays.join(','),
      'template_id': _templateId,
      'is_active': _isActive,
    };

    try {
      if (widget.campaign == null) {
        await api.post('/email-settings/campaigns?agency_id=${api.agencyId}', data);
      } else {
        await api.put('/email-settings/campaigns/${widget.campaign!['id']}?agency_id=${api.agencyId}', data);
      }
      widget.onSave();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save campaign')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.campaign == null ? 'Create Campaign' : 'Edit Campaign'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Campaign Name (e.g. Overdue Notice Level 1)'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _triggerType,
                decoration: const InputDecoration(labelText: 'Trigger Event'),
                items: const [
                  DropdownMenuItem(value: 'rent_overdue', child: Text('Rent is Overdue (After Due Date)')),
                  DropdownMenuItem(value: 'rent_upcoming', child: Text('Rent is Upcoming (Before Due Date)')),
                ],
                onChanged: (val) => setState(() => _triggerType = val!),
              ),
              const SizedBox(height: 16),
              widget.templates.isEmpty 
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No templates available. Please create an email template first.', style: TextStyle(color: Colors.red)),
                    )
                  : DropdownButtonFormField<int>(
                      value: _templateId,
                      decoration: const InputDecoration(labelText: 'Email Template'),
                      items: widget.templates.map<DropdownMenuItem<int>>((t) {
                        final int id = t['id'] is int ? t['id'] : int.tryParse(t['id'].toString()) ?? 0;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(t['name'].toString()),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _templateId = val),
                    ),
              const SizedBox(height: 16),
              const Text('Days Offset (0 = On Due Date)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                children: _availableDays.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day == 0 ? 'On Date' : '$day Days'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(day);
                        } else {
                          _selectedDays.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
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
