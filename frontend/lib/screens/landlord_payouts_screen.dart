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
import 'package:agentic_ui/services/api_service.dart';
import 'package:agentic_ui/utils/formatters.dart';

class LandlordPayoutsScreen extends StatefulWidget {
  const LandlordPayoutsScreen({super.key});

  @override
  State<LandlordPayoutsScreen> createState() => _LandlordPayoutsScreenState();
}

class _LandlordPayoutsScreenState extends State<LandlordPayoutsScreen> {
  List<dynamic> _payouts = [];
  Map<String, dynamic> _summary = {
    'pending_landlord': 0.0,
    'pending_service_provider': 0.0,
    'pending_agent_fee': 0.0,
    'paid_this_month': 0.0,
    'total_outstanding': 0.0
  };
  bool _isLoading = true;
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final summary = await api.fetchPayoutsSummary();
      final payouts = await api.fetchAllPayouts();
      setState(() {
        _summary = summary;
        _payouts = payouts;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int payoutId, String currentStatus, String? currentRef) async {
    String selectedStatus = currentStatus;
    final refController = TextEditingController(text: currentRef ?? '');
    
    final statuses = ['pending', 'processing', 'paid', 'partially_paid', 'cancelled', 'failed'];

    final bool? confirm = await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update Payout Status'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: statuses.contains(selectedStatus) ? selectedStatus : 'pending',
                    items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedStatus = val);
                    },
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: refController,
                    decoration: const InputDecoration(labelText: 'Reference Number', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
              ],
            );
          }
        );
      }
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final api = Provider.of<ApiService>(context, listen: false);
        await api.updatePayoutStatus(payoutId, selectedStatus, referenceNumber: refController.text);
        await _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
            title: const Text('Payout Management'),
            primary: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          Expanded(
            child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryDashboard(),
                  const SizedBox(height: 24),
                  const Text('All Payouts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildPayoutsGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        final cards = [
          _statCard('Pending Landlord', _summary['pending_landlord'], Colors.orange, 'pending_landlord'),
          _statCard('Pending Service', _summary['pending_service_provider'], Colors.orange, 'pending_service'),
          _statCard('Pending Agent Fee', _summary['pending_agent_fee'], Colors.orange, 'pending_agent'),
          _statCard('Total Outstanding', _summary['total_outstanding'], Colors.red, 'total_outstanding'),
          _statCard('Paid This Month', _summary['paid_this_month'], Colors.green, 'paid'),
        ];
        
        if (isDesktop) {
          return Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.all(4.0), child: c))).toList());
        } else {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards.map((c) => SizedBox(width: constraints.maxWidth / 2 - 12, child: c)).toList(),
          );
        }
      }
    );
  }

  Widget _statCard(String title, dynamic value, Color color, String filterKey) {
    final v = double.tryParse(value?.toString() ?? '0') ?? 0.0;
    final isSelected = _filterType == filterKey;
    return InkWell(
      onTap: () {
        setState(() {
          _filterType = _filterType == filterKey ? 'all' : filterKey;
        });
      },
      child: Card(
        elevation: isSelected ? 8 : 2,
        shape: isSelected ? RoundedRectangleBorder(side: BorderSide(color: color, width: 2), borderRadius: BorderRadius.circular(4)) : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('£${v.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayoutsGrid() {
    List<dynamic> filtered = _payouts.where((p) {
      if (_filterType == 'all') return true;
      final type = p['payment_type']?.toString().toLowerCase() ?? 'landlord';
      final status = p['status']?.toString().toLowerCase() ?? 'pending';
      if (_filterType == 'pending_landlord') return type == 'landlord' && status == 'pending';
      if (_filterType == 'pending_service') return type == 'service_provider' && status == 'pending';
      if (_filterType == 'pending_agent') return type == 'agent_fee' && status == 'pending';
      if (_filterType == 'total_outstanding') return status == 'pending';
      if (_filterType == 'paid') return status == 'paid';
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No payouts found for this filter.'));
    }
    
    return Card(
      elevation: 2,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
          columns: const [
            DataColumn(label: Text('Property')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Recipient')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Reference')),
            DataColumn(label: Text('Actions')),
          ],
          rows: filtered.map((p) {
            final prop = p['property_name'] ?? 'Unknown';
            final type = p['payment_type']?.toString().toUpperCase() ?? 'LANDLORD';
            final amount = double.tryParse(p['net_amount']?.toString() ?? '0') ?? 0.0;
            final date = p['created_at'] != null ? p['created_at'].toString().split('T')[0] : '';
            final status = p['status'] ?? 'pending';
            final ref = p['reference_number'] ?? '';
            
            return DataRow(
              cells: [
                DataCell(Text(prop?.toString() ?? 'Unknown')),
                DataCell(Chip(label: Text(type, style: const TextStyle(fontSize: 10)), padding: EdgeInsets.zero)),
                DataCell(Text(p['recipient_name']?.toString() ?? 
                  (p['payment_type'] == 'landlord' && p['landlord'] != null ? p['landlord']['first_name'] + ' ' + p['landlord']['last_name'] : 
                   p['payment_type'] == 'service_provider' && p['service_provider'] != null ? p['service_provider']['company_name'] ?? p['service_provider']['name'] : 'Unknown'))),
                DataCell(Text('£${amount.toStringAsFixed(2)}')),
                DataCell(Text(date?.toString() ?? '')),
                DataCell(Text(status.toUpperCase(), style: TextStyle(
                  color: status == 'paid' ? Colors.green : (status == 'failed' || status == 'cancelled' ? Colors.red : Colors.orange)
                ))),
                DataCell(Text(ref?.toString() ?? '')),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _updateStatus(p['id'], status, p['reference_number']),
                    tooltip: 'Update Status',
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        ),
      ),
    );
  }
}
