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

class LandlordsScreen extends StatefulWidget {
  const LandlordsScreen({super.key});

  @override
  State<LandlordsScreen> createState() => _LandlordsScreenState();
}

class _LandlordsScreenState extends State<LandlordsScreen> {
  List<dynamic> _landlords = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLandlords();
  }

  Future<void> _loadLandlords({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final list = await api.fetchLandlords(search: query);
      setState(() {
        _landlords = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading landlords: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddLandlordDialog() {
    final fnController = TextEditingController();
    final lnController = TextEditingController();
    final coController = TextEditingController();
    final a1Controller = TextEditingController();
    final a2Controller = TextEditingController();
    final cityController = TextEditingController();
    final countyController = TextEditingController();
    final postController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    String commsPref = 'email_only';
    
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
        title: const Text('Add Landlord'),
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
                TextField(controller: coController, decoration: const InputDecoration(labelText: 'Care of (C/O) / Company', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
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
                await api.addLandlord(
                  fnController.text, 
                  lnController.text,
                  co: coController.text,
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
                  _loadLandlords();
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

  void _showEditLandlordDialog(dynamic landlord) {
    final fnController = TextEditingController(text: landlord['first_name']);
    final lnController = TextEditingController(text: landlord['last_name']);
    final coController = TextEditingController(text: landlord['co'] ?? '');
    final a1Controller = TextEditingController(text: landlord['address_line_1'] ?? '');
    final a2Controller = TextEditingController(text: landlord['address_line_2'] ?? '');
    final cityController = TextEditingController(text: landlord['city'] ?? '');
    final countyController = TextEditingController(text: landlord['county'] ?? '');
    final postController = TextEditingController(text: landlord['postcode'] ?? '');
    final emailController = TextEditingController(text: landlord['email'] ?? '');
    final phoneController = TextEditingController(text: landlord['phone'] ?? '');
      String commsPref = landlord['communication_preference'] ?? 'email_only';
    
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
        title: const Text('Edit Landlord'),
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
                TextField(controller: coController, decoration: const InputDecoration(labelText: 'Care of (C/O) / Company', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
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
                await api.updateLandlord(
                  landlord['id'],
                  fnController.text, 
                  lnController.text,
                  co: coController.text,
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
                  _loadLandlords();
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

  void _showIssueAdvanceDialog(dynamic landlord) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    
    showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
        title: Text('Issue Advance to ${landlord['first_name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount (£)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notes (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (amountController.text.isEmpty) return;
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) return;
              
              try {
                final api = Provider.of<ApiService>(context, listen: false);
                await api.issueLandlordAdvance(landlord['id'], amount, notesController.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadLandlords();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Issue Advance'),
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
            title: const Text('Landlords'),
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
                hintText: 'Search landlords...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => _loadLandlords(query: val),
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _landlords.isEmpty
                    ? const Center(child: Text('No landlords found. Add one!'))
                    : ListView.builder(
                        itemCount: _landlords.length,
                        itemBuilder: (context, index) {
                          final l = _landlords[index];
                          final outstanding = l['outstanding_advance'] != null ? (l['outstanding_advance'] as num).toDouble() : 0.0;
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
                                          const Icon(Icons.business_center, color: Colors.orange, size: 24),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${l['first_name']} ${l['last_name']}',
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.orange.shade200),
                                        ),
                                        child: Text(
                                          'Payout: ${(l['payout_preference'] ?? 'auto').toString().toUpperCase()}',
                                          style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),

                                  // --- Body columns ---
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
                                              const Text('Registered Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          if (l['co'] != null && l['co'].toString().isNotEmpty)
                                            Text('C/O: ${l['co']}', style: const TextStyle(fontSize: 12)),
                                          Text(
                                            [
                                              l['address_line_1'],
                                              l['address_line_2'],
                                              l['city'],
                                              l['county'],
                                              l['postcode']
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
                                                  l['email'] ?? 'No email provided',
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
                                                l['phone'] ?? 'No phone provided',
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

                                  // --- Footer Row ---
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      outstanding > 0
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.red.shade100),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Outstanding Advance: £${outstanding.toStringAsFixed(2)}',
                                                    style: TextStyle(color: Colors.red.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Text(
                                              'No active advances',
                                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic),
                                            ),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.payments_outlined, size: 16),
                                            label: const Text('Advance', style: TextStyle(fontSize: 12)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.green,
                                              side: BorderSide(color: Colors.green.withOpacity(0.5)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            onPressed: () => _showIssueAdvanceDialog(l),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                                            tooltip: 'Edit Landlord',
                                            onPressed: () => _showEditLandlordDialog(l),
                                          ),
                                        ],
                                      ),
                                    ],
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
        onPressed: _showAddLandlordDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}


