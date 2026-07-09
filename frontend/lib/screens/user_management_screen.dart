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

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.fetchUsers();
      setState(() => _users = list);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final pwdCtrl = TextEditingController();
    String? selectedRole;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Sub-Agent'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: pwdCtrl, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()), obscureText: true),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  items: [
                    {'val': 'administrator', 'label': 'Administrator (Full Access)'},
                    {'val': 'admin', 'label': 'Admin (Management Access)'},
                    {'val': 'support_agent', 'label': 'Support Agent (Assigned Properties)'},
                    {'val': 'accountant', 'label': 'Accountant (Financials Only)'},
                  ].map((role) {
                    return DropdownMenuItem<String>(
                      value: role['val'],
                      child: Text(role['label']!),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || selectedRole == null) return;
                try {
                  final api = Provider.of<ApiService>(context, listen: false);
                  await api.createSubAgent(nameCtrl.text, emailCtrl.text, pwdCtrl.text, selectedRole!);
                  Navigator.pop(ctx);
                  _loadUsers();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text('Create Agent'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(dynamic u) {
    final nameCtrl = TextEditingController(text: u['name']);
    final emailCtrl = TextEditingController(text: u['email']);
    final pwdCtrl = TextEditingController();
    String? selectedRole = u['role'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Sub-Agent: ${u['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(
                  controller: pwdCtrl, 
                  decoration: const InputDecoration(
                    labelText: 'New Password (leave blank to keep current)', 
                    border: OutlineInputBorder()
                  ), 
                  obscureText: true
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  items: [
                    {'val': 'administrator', 'label': 'Administrator (Full Access)'},
                    {'val': 'admin', 'label': 'Admin (Management Access)'},
                    {'val': 'support_agent', 'label': 'Support Agent (Assigned Properties)'},
                    {'val': 'accountant', 'label': 'Accountant (Financials Only)'},
                  ].map((role) {
                    return DropdownMenuItem<String>(
                      value: role['val'],
                      child: Text(role['label']!),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || selectedRole == null) return;
                try {
                  final api = Provider.of<ApiService>(context, listen: false);
                  await api.updateUserByAdmin(
                    u['id'],
                    nameCtrl.text,
                    emailCtrl.text,
                    pwdCtrl.text.isNotEmpty ? pwdCtrl.text : null,
                    selectedRole!,
                  );
                  Navigator.pop(ctx);
                  _loadUsers();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text('Save Changes'),
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
            title: const Text('User & Role Management'),
            primary: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          Expanded(
            child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final u = _users[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getRoleColor(u['role']).withOpacity(0.1),
                        child: Icon(Icons.person, color: _getRoleColor(u['role'])),
                      ),
                      title: Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${u['email']} • ${u['role'].toString().replaceAll('_', ' ').toUpperCase()}'),
                      trailing: const Icon(Icons.edit, color: Colors.blue, size: 20),
                      onTap: () => _showEditUserDialog(u),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        label: const Text('Add Agent'),
        icon: const Icon(Icons.person_add),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'administrator': return Colors.red;
      case 'admin': return Colors.orange;
      case 'support_agent': return Colors.green;
      case 'accountant': return Colors.blue;
      default: return Colors.grey;
    }
  }
}
