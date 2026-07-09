import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class MailSettingsScreen extends StatefulWidget {
  const MailSettingsScreen({super.key});

  @override
  State<MailSettingsScreen> createState() => _MailSettingsScreenState();
}

class _MailSettingsScreenState extends State<MailSettingsScreen> {
  bool _isLoading = true;
  bool _isEnabled = false;
  String _provider = 'smtp';
  
  final _smtpServerController = TextEditingController();
  final _smtpPortController = TextEditingController();
  final _smtpUserController = TextEditingController();
  final _smtpPassController = TextEditingController();
  final _imapServerController = TextEditingController();
  final _imapPortController = TextEditingController();
  
  final _senderNameController = TextEditingController();
  final _senderEmailController = TextEditingController();
  final _replyToController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final config = await api.getCommunicationConfig();
      setState(() {
        _isEnabled = config['is_enabled'] ?? false;
        _provider = config['mail_provider'] ?? 'smtp';
        _smtpServerController.text = config['smtp_server'] ?? '';
        _smtpPortController.text = config['smtp_port']?.toString() ?? '';
        _smtpUserController.text = config['smtp_username'] ?? '';
        _smtpPassController.text = config['smtp_password'] ?? '';
        _imapServerController.text = config['imap_server'] ?? '';
        _imapPortController.text = config['imap_port']?.toString() ?? '';
        _senderNameController.text = config['sender_name'] ?? '';
        _senderEmailController.text = config['sender_email'] ?? '';
        _replyToController.text = config['reply_to'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load settings: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.updateCommunicationConfig({
        'is_enabled': _isEnabled,
        'mail_provider': _provider,
        'smtp_server': _smtpServerController.text,
        'smtp_port': int.tryParse(_smtpPortController.text),
        'smtp_username': _smtpUserController.text,
        'smtp_password': _smtpPassController.text,
        'imap_server': _imapServerController.text,
        'imap_port': int.tryParse(_imapPortController.text),
        'sender_name': _senderNameController.text,
        'sender_email': _senderEmailController.text,
        'reply_to': _replyToController.text,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mail Configuration Settings'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveConfig),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Enable Mail System'),
              subtitle: const Text('Turn on sending and receiving capabilities.'),
              value: _isEnabled,
              onChanged: (val) => setState(() => _isEnabled = val),
            ),
            const Divider(),
            const Text('Sender Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            _buildTextField('Sender Name', _senderNameController),
            const SizedBox(height: 12),
            _buildTextField('Sender Email Address', _senderEmailController),
            const SizedBox(height: 12),
            _buildTextField('Reply-To Email Address', _replyToController),
            
            const SizedBox(height: 32),
            const Text('SMTP Settings (Outgoing Mail)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            _buildTextField('SMTP Server', _smtpServerController),
            const SizedBox(height: 12),
            _buildTextField('SMTP Port', _smtpPortController, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _buildTextField('SMTP Username', _smtpUserController),
            const SizedBox(height: 12),
            _buildTextField('SMTP Password', _smtpPassController, obscureText: true),
            
            const SizedBox(height: 32),
            const Text('IMAP Settings (Incoming Mail)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            _buildTextField('IMAP Server', _imapServerController),
            const SizedBox(height: 12),
            _buildTextField('IMAP Port', _imapPortController, keyboardType: TextInputType.number),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscureText = false, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
