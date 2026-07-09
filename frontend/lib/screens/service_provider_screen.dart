import 'package:flutter/material.dart';
import '../widgets/top_navigation_pills.dart';
import '../widgets/main_app_bar.dart';

import '../services/auth_provider.dart';
import '../services/theme_provider.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'global_settings_screen.dart';
import 'properties_screen.dart';
import 'tenants_screen.dart';
import 'landlords_screen.dart';
import 'user_management_screen.dart';
import 'service_provider_screen.dart';
import 'financial_reconciliation_screen.dart';
import 'landlord_payouts_screen.dart';
import 'advanced_report_screen.dart';
import 'package:provider/provider.dart';

import 'package:provider/provider.dart';
import '../services/api_service.dart';

class ServiceProviderScreen extends StatefulWidget {
  const ServiceProviderScreen({super.key});

  @override
  State<ServiceProviderScreen> createState() => _ServiceProviderScreenState();
}

class _ServiceProviderScreenState extends State<ServiceProviderScreen> {
  List<dynamic> _providers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.fetchServiceProviders(search: query);
      setState(() => _providers = list);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProviderDialog({dynamic provider}) {
    final companyCtrl = TextEditingController(text: provider?['company_name']);
    final directorCtrl = TextEditingController(text: provider?['director_name']);
    final addrCtrl = TextEditingController(text: provider?['address']);
    final contactCtrl = TextEditingController(text: provider?['contact_number']);
    final emailCtrl = TextEditingController(text: provider?['email']);
    bool isVatRegistered = provider?['vat_registered'] ?? false;
    final vatNumCtrl = TextEditingController(text: provider?['vat_registration_number']);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(provider == null ? 'Add Service Provider' : 'Edit Service Provider'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: companyCtrl, decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: directorCtrl, decoration: const InputDecoration(labelText: 'Director Name', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 16),
                TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('VAT Registered?'),
                    Switch(
                      value: isVatRegistered,
                      onChanged: (val) {
                        setStateDialog(() {
                          isVatRegistered = val;
                        });
                      },
                    ),
                  ],
                ),
                if (isVatRegistered) ...[
                  const SizedBox(height: 16),
                  TextField(controller: vatNumCtrl, decoration: const InputDecoration(labelText: 'VAT Registration Number', border: OutlineInputBorder())),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            if (provider != null)
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Confirm Delete'),
                      content: const Text('Are you sure you want to delete this provider?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      final api = Provider.of<ApiService>(context, listen: false);
                      await api.deleteServiceProvider(provider['id']);
                      Navigator.pop(ctx);
                      _loadProviders();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ')));
                    }
                  }
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: () async {
                if (companyCtrl.text.isEmpty) return;
                final data = {
                  'company_name': companyCtrl.text,
                  'director_name': directorCtrl.text,
                  'address': addrCtrl.text,
                  'contact_number': contactCtrl.text,
                  'email': emailCtrl.text,
                  'vat_registered': isVatRegistered,
                  'vat_registration_number': isVatRegistered ? vatNumCtrl.text : null,
                };
                try {
                  final api = Provider.of<ApiService>(context, listen: false);
                  if (provider == null) {
                    await api.createServiceProvider(data);
                  } else {
                    await api.updateServiceProvider(provider['id'], data);
                  }
                  Navigator.pop(ctx);
                  _loadProviders();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: Text(provider == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }


  Widget _navButton(BuildContext context, String title, IconData icon, Color color, Widget destination) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
        },
      ),
    );
  }

    

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool canManageUsers = auth.role == 'administrator' || auth.role == 'admin';
    final bool canManageFinance = auth.role == 'administrator' || auth.role == 'accountant' || auth.role == 'admin';

    return Scaffold(
      appBar: const MainAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TopNavigationPills(),
          const Divider(height: 1),
          AppBar(
            title: const Text('Maintenance Service Providers'),
            primary: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          Expanded(
            child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by company, director or email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => _loadProviders(query: val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _providers.isEmpty
                    ? const Center(child: Text('No service providers found.'))
                    : ListView.builder(
                        itemCount: _providers.length,
                        itemBuilder: (context, index) {
                          final p = _providers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: const Icon(Icons.build, color: Colors.blue),
                              ),
                              title: Text(p['company_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${p['director_name'] ?? 'No director'} • ${p['contact_number'] ?? 'No contact'}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.grey),
                                onPressed: () => _showProviderDialog(provider: p),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    ),
  ],
),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProviderDialog(),
        label: const Text('Add Provider'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}
