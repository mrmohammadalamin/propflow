import 'package:flutter/material.dart';
import 'mail_settings_screen.dart';
import 'document_templates_screen.dart';
import 'email_schedule_settings_screen.dart';
import 'email_templates_screen.dart';
import 'vat_settings_screen.dart';

class GlobalSettingsScreen extends StatefulWidget {
  const GlobalSettingsScreen({super.key});

  @override
  State<GlobalSettingsScreen> createState() => _GlobalSettingsScreenState();
}

class _GlobalSettingsScreenState extends State<GlobalSettingsScreen> {
  // AI Agent Settings State
  String _selectedProvider = 'gemini';
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _modelNameController = TextEditingController(text: 'gemini-1.5-pro');

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Global Settings Saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Global Settings'),
          backgroundColor: Colors.indigo.shade900,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: 'General Config'),
              Tab(text: 'AI Agent Config'),
              Tab(text: 'Email Scheduling'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // General Config Tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  const ListTile(
                    leading: Icon(Icons.business),
                    title: Text('Agency Profile'),
                    subtitle: Text('Manage your business details, logos, and global defaults.'),
                    trailing: Icon(Icons.arrow_forward_ios, size: 14),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('Mail & Communication Settings'),
                    subtitle: const Text('Configure SMTP, mail providers, and communication defaults.'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MailSettingsScreen()));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email Templates'),
                    subtitle: const Text('Manage templates for automated email campaigns.'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const EmailTemplatesScreen()));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.description),
                    title: const Text('Document Template Settings'),
                    subtitle: const Text('Manage document templates for invoices and statements.'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentTemplatesScreen()));
                    },
                  ),
                  const Divider(),
                  const ListTile(
                    leading: Icon(Icons.payment),
                    title: Text('Payment Gateways'),
                    subtitle: Text('Configure Stripe, GoCardless, or manual banking.'),
                    trailing: Icon(Icons.arrow_forward_ios, size: 14),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.account_balance),
                    title: const Text('Tax & VAT Settings'),
                    subtitle: const Text('Configure agency VAT defaults.'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const VatSettingsScreen()));
                    },
                  ),
                ],
              ),
            ),
            
            
            // AI Agent Config Tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select AI Provider', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    value: _selectedProvider,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')),
                      DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                      DropdownMenuItem(value: 'ollama', child: Text('Ollama (Open Source)')),
                      DropdownMenuItem(value: 'vllm', child: Text('vLLM (Open Source)')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedProvider = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('API Key', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      hintText: 'Enter API Key (Leave blank to use .env defaults)',
                      isDense: true,
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  const Text('Model Name', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _modelNameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. gemini-2.5-pro, gpt-4o',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedProvider == 'ollama' || _selectedProvider == 'vllm') ...[
                    const Text('Base URL', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        hintText: 'http://localhost:11434/api',
                        isDense: true,
                      ),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.purple.shade900,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save AI Settings'),
                    ),
                  ),
                ],
              ),
            ),
            const EmailCampaignsScreen(),
          ],
        ),
      ),
    );
  }
}
