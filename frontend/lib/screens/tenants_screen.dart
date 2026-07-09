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
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  List<dynamic> _tenants = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.fetchTenants(search: query);
      setState(() {
        _tenants = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading tenants: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddTenantDialog() {
    final fnController = TextEditingController();
    final lnController = TextEditingController();
    
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
        title: const Text('Add Tenant'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 650 ? 600 : MediaQuery.of(context).size.width * 0.95,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: fnController, decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
              const SizedBox(height: 16),
              TextField(controller: lnController, decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (fnController.text.isEmpty || lnController.text.isEmpty) return;
              try {
                final api = Provider.of<ApiService>(context, listen: false);
                await api.addTenant(fnController.text, lnController.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadTenants();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
    );
  }

  void _showEditTenantDialog(dynamic tenant) {
    final fnController = TextEditingController(text: tenant['first_name']);
    final lnController = TextEditingController(text: tenant['last_name']);
    final a1Controller = TextEditingController(text: tenant['address_line_1'] ?? '');
    final a2Controller = TextEditingController(text: tenant['address_line_2'] ?? '');
    final cityController = TextEditingController(text: tenant['city'] ?? '');
    final countyController = TextEditingController(text: tenant['county'] ?? '');
    final postController = TextEditingController(text: tenant['postcode'] ?? '');
    final emailController = TextEditingController(text: tenant['email'] ?? '');
    final phoneController = TextEditingController(text: tenant['phone'] ?? '');
      String commsPref = tenant['communication_preference'] ?? 'email_only';
    
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
        title: const Text('Edit Tenant'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 650 ? 600 : MediaQuery.of(context).size.width * 0.95,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: fnController, decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)))),
                    const SizedBox(width: 16),
                    Expanded(child: TextField(controller: lnController, decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)))),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(controller: a1Controller, decoration: const InputDecoration(labelText: 'Address Line 1', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
                const SizedBox(height: 16),
                TextField(controller: a2Controller, decoration: const InputDecoration(labelText: 'Address Line 2', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextField(controller: cityController, decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)))),
                    const SizedBox(width: 16),
                    Expanded(child: TextField(controller: countyController, decoration: const InputDecoration(labelText: 'County', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextField(controller: postController, decoration: const InputDecoration(labelText: 'Post Code', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)))),
                    const SizedBox(width: 16),
                    Expanded(child: TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)))),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (fnController.text.isEmpty || lnController.text.isEmpty) return;
              try {
                final api = Provider.of<ApiService>(context, listen: false);
                await api.updateTenant(
                  tenant['id'], 
                  fnController.text, 
                  lnController.text,
                  address1: a1Controller.text,
                  address2: a2Controller.text,
                  city: cityController.text,
                  county: countyController.text,
                  postcode: postController.text,
                  email: emailController.text,
                  phone: phoneController.text,
                  communicationPreference: commsPref,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadTenants();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
    );
  }

  void _uploadId(int tenantId, bool useAi) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _isLoading = true);
      try {
        final bytes = await image.readAsBytes();
        final api = Provider.of<ApiService>(context, listen: false);
        await api.uploadTenantIdProof(tenantId, bytes, image.name, useAi);
        await _loadTenants();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID Uploaded Successfully')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _manuallyVerify(int tenantId, String status) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.updateTenantVerifyStatus(tenantId, status, "Manually updated by agency.");
      _loadTenants();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
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
            title: const Text('Tenants'),
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
                hintText: 'Search tenants...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => _loadTenants(query: val),
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _tenants.isEmpty
                    ? const Center(child: Text('No tenants found. Add one!'))
                    : ListView.builder(
                        itemCount: _tenants.length,
                        itemBuilder: (context, index) {
                          final t = _tenants[index];
                          final String status = t['id_verification_status'] ?? 'missing';
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // --- Header Row ---
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.person, color: Colors.green, size: 24),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${t['first_name']} ${t['last_name']}',
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.green.shade200),
                                        ),
                                        child: Text(
                                          'Credit: £${t['credit_balance'] ?? '0.00'}',
                                          style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),

                                  // --- Body Address & Contact details ---
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isWide = constraints.maxWidth > 500;
                                      final addressWidget = Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.location_on_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                                              const SizedBox(width: 4),
                                              const Text('Tenant Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            [
                                              t['address_line_1'],
                                              t['address_line_2'],
                                              t['city'],
                                              t['county'],
                                              t['postcode']
                                            ].where((element) => element != null && element.toString().trim().isNotEmpty).join(', '),
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                                          ),
                                        ],
                                      );

                                      final contactWidget = Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.contact_phone_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                                              const SizedBox(width: 4),
                                              const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  t['email'] ?? 'No email provided',
                                                  style: const TextStyle(fontSize: 12),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                              const SizedBox(width: 6),
                                              Text(
                                                t['phone'] ?? 'No phone provided',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );

                                      if (isWide) {
                                        return Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(flex: 3, child: addressWidget),
                                            const SizedBox(width: 16),
                                            Expanded(flex: 2, child: contactWidget),
                                          ],
                                        );
                                      } else {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            addressWidget,
                                            const SizedBox(height: 16),
                                            contactWidget,
                                          ],
                                        );
                                      }
                                    },
                                  ),

                                  const SizedBox(height: 16),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),

                                  // --- Footer: Verification details directly visible ---
                                  Row(
                                    children: [
                                      const Icon(Icons.verified_user_outlined, size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      const Text('Identity Verification: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 4),
                                      _buildStatusChip(status),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                        tooltip: 'Edit Tenant',
                                        onPressed: () => _showEditTenantDialog(t),
                                      ),
                                    ],
                                  ),

                                  if (t['id_verification_notes'] != null && t['id_verification_notes'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                                      child: Text(
                                        'Verification Notes: ${t['id_verification_notes']}',
                                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                                      ),
                                    ),

                                  const SizedBox(height: 8),

                                  // Upload controls or review controls directly displayed on card face
                                  if (status == 'missing' || status == 'rejected') ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            icon: const Icon(Icons.psychology, size: 16),
                                            label: const Text('Verify with AI', style: TextStyle(fontSize: 12)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.purple,
                                              side: BorderSide(color: Colors.purple.withOpacity(0.5)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                            ),
                                            onPressed: () => _uploadId(t['id'], true),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.upload_file, size: 16),
                                            label: const Text('Upload Proof', style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                            ),
                                            onPressed: () => _uploadId(t['id'], false),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else if (status == 'pending') ...[
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.orange.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text(
                                            'Under Review',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange),
                                          ),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: () {},
                                            child: const Text('View Doc', style: TextStyle(fontSize: 12)),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () => _manuallyVerify(t['id'], 'verified'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            child: const Text('Approve', style: TextStyle(fontSize: 11)),
                                          ),
                                          const SizedBox(width: 6),
                                          TextButton(
                                            onPressed: () => _manuallyVerify(t['id'], 'rejected'),
                                            child: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.account_balance_wallet, size: 18),
                                      label: const Text('Manage Deposit'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo.shade50,
                                        foregroundColor: Colors.indigo,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _showDepositManagementDialog(t),
                                    ),
                                  ),
                                ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTenantDialog,
        child: const Icon(Icons.add),
      ),
    );
  }


  void _showDepositManagementDialog(dynamic tenant) {
    showDialog(
      context: context,
      builder: (context) {
        return _DepositManagementDialog(tenant: tenant);
      },
    );
  }

  Widget _buildStatusChip(String status) {

    Color color;
    IconData icon;
    switch (status) {
      case 'verified':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      backgroundColor: color,
    );
  }
}

class _DepositManagementDialog extends StatefulWidget {
  final dynamic tenant;
  const _DepositManagementDialog({required this.tenant});

  @override
  State<_DepositManagementDialog> createState() => _DepositManagementDialogState();
}

class _DepositManagementDialogState extends State<_DepositManagementDialog> {
  Map<String, dynamic>? _info;
  bool _isLoading = true;
  final TextEditingController _amtCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final info = await api.getDepositInfo(widget.tenant['id']);
      if (mounted) setState(() { _info = info; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _refund() async {
    final amt = double.tryParse(_amtCtrl.text);
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.refundDeposit(widget.tenant['id'], amt, _refCtrl.text);
      _amtCtrl.clear();
      _refCtrl.clear();
      await _loadInfo();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refund processed')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
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
    return AlertDialog(
      title: Text('Manage Deposit: ${widget.tenant['first_name']} ${widget.tenant['last_name']}'),
      content: SizedBox(
        width: 600,
        child: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _statCard('Total Deposit', _info!['total_deposit'])),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Refunded', _info!['refunded_amount'], Colors.red)),
                const SizedBox(width: 8),
                Expanded(child: _statCard('Remaining', _info!['remaining_balance'], Colors.green)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Refund History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: _info!['history'].isEmpty 
                ? const Center(child: Text('No refunds yet', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _info!['history'].length,
                    itemBuilder: (ctx, i) {
                      final h = _info!['history'][i];
                      return ListTile(
                        dense: true,
                        title: Text('£${h['amount']}'),
                        subtitle: Text(h['reference'] ?? ''),
                        trailing: Text(h['date'] != null ? h['date'].toString().split('T')[0] : ''),
                      );
                    },
                  ),
            ),
            const SizedBox(height: 24),
            const Text('Process New Refund', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _amtCtrl, decoration: const InputDecoration(labelText: 'Amount (£)', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'Reference', border: OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _refund,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                  child: const Text('Refund'),
                )
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
      ],
    );
  }

  Widget _statCard(String label, dynamic value, [Color? color]) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text('£${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}


