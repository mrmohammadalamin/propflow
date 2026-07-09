import 'package:flutter/material.dart';
import '../widgets/top_navigation_pills.dart';
import '../widgets/main_app_bar.dart';
import 'package:provider/provider.dart';
import 'communication_centre_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:agentic_ui/services/api_service.dart';
import 'package:agentic_ui/utils/formatters.dart';
import 'package:url_launcher/url_launcher.dart';
import 'advanced_property_setup.dart';
import 'financial_reconciliation_screen.dart';

class PropertiesScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final String? initialAction; // 'lease_plan', 'statements', 'collect_rent', 'maintenance', 'details'
  const PropertiesScreen({super.key, this.initialSearchQuery, this.initialAction});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  List<dynamic> _properties = [];
  List<dynamic> _serviceProviders = [];
  bool _isLoading = true;
  late final TextEditingController _searchController;
  bool _hasTriggeredAction = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearchQuery);
    _loadProperties(query: widget.initialSearchQuery);
  }



  Future<void> _loadProperties({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final props = await api.fetchProperties(search: query);
      
      // Sort by next_due_date (earliest first). Nulls go to the bottom.
      props.sort((a, b) {
        if (a['next_due_date'] == null && b['next_due_date'] == null) return 0;
        if (a['next_due_date'] == null) return 1;
        if (b['next_due_date'] == null) return -1;
        return DateTime.parse(a['next_due_date']).compareTo(DateTime.parse(b['next_due_date']));
      });

      final providers = await api.fetchServiceProviders();
      setState(() {
        _properties = props;
        _serviceProviders = providers;
      });

      // Automatically trigger action if passed and not yet triggered
      if (widget.initialAction != null && props.isNotEmpty && !_hasTriggeredAction) {
        _hasTriggeredAction = true;
        final targetProp = props.first;
        final tenancies = targetProp['tenancies'] as List? ?? [];
        final activeTenancy = tenancies.where((t) => t['status'] == 'active').firstOrNull;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          switch (widget.initialAction) {
            case 'lease_plan':
              if (activeTenancy != null) _showRentalPlan(activeTenancy, targetProp);
              break;
            case 'statements':
              _showPropertyStatements(targetProp);
              break;
            case 'collect_rent':
              if (activeTenancy != null) _showQuickCollectDialog(activeTenancy, targetProp);
              break;
            case 'maintenance':
              _showAddMaintenanceDialog(targetProp['id']);
              break;
            case 'details':
              _showPropertyDetails(targetProp);
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading properties: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _launchAdvancedSetup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdvancedPropertySetupScreen()),
    );
    if (result == true) {
      _loadProperties();
    }
  }

  void _showEditPropertyDialog(dynamic prop) {
    final roomNoController = TextEditingController(text: prop['room_no']?.toString() ?? '');
    final addrController = TextEditingController(text: prop['address_line_1']);
    final cityController = TextEditingController(text: prop['city']);
    final postController = TextEditingController(text: prop['postcode']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Property'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 650 ? 550 : MediaQuery.of(context).size.width * 0.95,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: roomNoController, 
                  decoration: const InputDecoration(
                    labelText: 'Flat or Room No', 
                    border: OutlineInputBorder(), 
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addrController, 
                  decoration: const InputDecoration(
                    labelText: 'Address Line 1', 
                    border: OutlineInputBorder(), 
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cityController, 
                  decoration: const InputDecoration(
                    labelText: 'City', 
                    border: OutlineInputBorder(), 
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: postController, 
                  decoration: const InputDecoration(
                    labelText: 'Postcode', 
                    border: OutlineInputBorder(), 
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (addrController.text.isEmpty) return;
              try {
                final api = Provider.of<ApiService>(context, listen: false);
                await api.updateProperty(prop['id'], roomNoController.text, addrController.text, cityController.text, postController.text, prop['landlord_id']);
                if (context.mounted) {
                  Navigator.pop(context); // Close edit dialog
                  Navigator.pop(context); // Close bottom sheet to refresh state cleanly
                  _loadProperties();
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
    );
  }

  void _showRentalPlan(dynamic tenancy, dynamic property) {
    if (tenancy == null || property == null) return;
    DateTime start = DateTime.parse(tenancy['start_date']);
    int dueDay = tenancy['due_day'];
    double rent = double.parse(tenancy['rent_amount'].toString());
    final ScrollController horizontalScroll = ScrollController();
    
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<dynamic>>(
        future: Provider.of<ApiService>(context, listen: false).fetchPaymentPlan(tenancy['id']),
        builder: (context, snapshot) {
          final planData = snapshot.data ?? [];
          final tenants = property['tenants'] as List? ?? [];
          final tenantName = tenants.isNotEmpty ? '${tenants[0]['first_name']} ${tenants[0]['last_name']}' : 'No Tenant';
          final propRef = property['reference_number'] ?? 'REF-PENDING';

          double totalExpected = 0.0;
          double totalCollected = 0.0;
          double totalAgentFee = 0.0;
          double totalActualMaint = 0.0;
          double totalMaint = 0.0;
          double totalRecovery = 0.0;
          double totalNetPayout = 0.0;

          for (int i = 0; i < 12; i++) {
            DateTime due = DateTime(start.year, start.month + i, dueDay);
            final payment = planData.where((p) {
              DateTime pDate = DateTime.parse(p['due_date']);
              return pDate.year == due.year && pDate.month == due.month;
            }).firstOrNull;

            final payouts = payment != null ? (payment['payouts'] as List? ?? []) : [];
            double expectedMaint = payment != null ? double.parse((payment['expected_maintenance'] ?? 0.0).toString()) : 0.0;
            double expectedFee = (rent * double.parse((tenancy['management_fee_percentage'] ?? 0).toString())) / 100;

            double displayMaint = payouts.isEmpty ? expectedMaint : payouts.fold(0.0, (sum, p) => sum + double.parse(p['maintenance_cost'].toString()));
            double displayFee = payouts.isEmpty ? expectedFee : payouts.fold(0.0, (sum, p) => sum + double.parse(p['management_fee'].toString()));
            double displayAdv = payouts.fold(0.0, (sum, p) => sum + double.parse(p['advance_recovery'].toString()));
            double displayNet = payouts.isEmpty ? (rent - displayFee - displayMaint) : payouts.fold(0.0, (sum, p) => sum + double.parse(p['net_amount'].toString()));
            
            List<dynamic> maintRecords = payment != null && payment['maintenance_records'] != null ? payment['maintenance_records'] : [];
            double displayActualMaint = maintRecords.fold(0.0, (sum, item) => sum + (item['actual_cost'] != null ? double.parse(item['actual_cost'].toString()) : double.parse(item['cost'].toString())));

            totalExpected += rent;
            totalCollected += (payment != null ? double.parse(payment['paid_amount'].toString()) : 0.0);
            totalAgentFee += displayFee;
            totalActualMaint += displayActualMaint;
            totalMaint += displayMaint;
            totalRecovery += displayAdv;
            totalNetPayout += displayNet;
          }

          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rent Payment Plan: $propRef', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Tenant: $tenantName', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            content: SizedBox(
              width: 1200, // Wide for horizontal layout
              child: snapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : Scrollbar(
                    controller: horizontalScroll,
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 10,
                    child: SingleChildScrollView(
                      controller: horizontalScroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 1400,
                      child: Column(
                        children: [
                          // TABLE HEADER
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8))),
                            child: Row(
                              children: [
                                _buildHeaderCell('Month', 60),
                                _buildHeaderCell('Due Date', 100),
                                _buildHeaderCell('Expected', 100),
                                _buildHeaderCell('Collected', 100),
                                _buildHeaderCell('Agent Fee (%)', 100),
                                _buildHeaderCell('Agent Fee', 100),
                                _buildHeaderCell('Actual Maint.', 100),
                                _buildHeaderCell('Maint.', 100),
                                _buildHeaderCell('Recovery', 100),
                                _buildHeaderCell('Net Payout', 100),
                                _buildHeaderCell('Rent Status', 100),
                                _buildHeaderCell('Payout Status', 100),
                                _buildHeaderCell('Paid Date', 100),
                                _buildHeaderCell('Action', 100),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: 12,
                              itemBuilder: (context, i) {
                                DateTime due = DateTime(start.year, start.month + i, dueDay);
                                final payment = planData.where((p) {
                                  DateTime pDate = DateTime.parse(p['due_date']);
                                  return pDate.year == due.year && pDate.month == due.month;
                                }).firstOrNull;

                                
                                Color statusColor = Colors.red;
                                String statusText = 'UNPAID';
                                if (payment != null) {
                                  if (payment['status'] == 'paid') {
                                    statusColor = Colors.green;
                                    statusText = 'PAID';
                                  } else if (payment['status'] == 'partially_paid') {
                                    statusColor = Colors.orange;
                                    statusText = 'PARTIAL';
                                  }
                                }

                                final payouts = payment != null ? (payment['payouts'] as List? ?? []) : [];
                                double totalPaid = payment != null ? double.parse(payment['paid_amount'].toString()) : 0.0;
                                
                                double expectedMaint = payment != null ? double.parse((payment['expected_maintenance'] ?? 0.0).toString()) : 0.0;
                                double expectedFee = (rent * double.parse((tenancy['management_fee_percentage'] ?? 0).toString())) / 100;
                                
                                double displayMaint = payouts.isEmpty ? expectedMaint : payouts.fold(0.0, (sum, p) => sum + double.parse(p['maintenance_cost'].toString()));
                                
                                List<dynamic> maintRecords = payment != null && payment['maintenance_records'] != null ? payment['maintenance_records'] : [];
                                double displayActualMaint = maintRecords.fold(0.0, (sum, item) => sum + (item['actual_cost'] != null ? double.parse(item['actual_cost'].toString()) : double.parse(item['cost'].toString())));

                                double displayFee = payouts.isEmpty ? expectedFee : payouts.fold(0.0, (sum, p) => sum + double.parse(p['management_fee'].toString()));
                                double displayAdv = payouts.fold(0.0, (sum, p) => sum + double.parse(p['advance_recovery'].toString()));
                                
                                double displayNet = payouts.isEmpty ? (rent - displayFee - displayMaint) : payouts.fold(0.0, (sum, p) => sum + double.parse(p['net_amount'].toString()));


                                Color payoutColor = Colors.grey;
                                String payoutText = '-';
                                if (payouts.isNotEmpty) {
                                  if (payouts.last['status'] == 'paid') {
                                    payoutColor = Colors.green;
                                    payoutText = 'SENT';
                                  } else {
                                    payoutColor = Colors.orange;
                                    payoutText = 'PENDING';
                                  }
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildDataCell('#${i + 1}', 60, isBold: true),
                                      _buildDataCell(DateFormat('dd/MM/yy').format(due), 100),
                                      _buildDataCell('£${rent.toStringAsFixed(2)}', 100),
                                      _buildDataCell('£${totalPaid.toStringAsFixed(2)}', 100, color: Colors.blue),
                                      _buildDataCell('${tenancy['management_fee_percentage']}%', 100, color: Colors.grey),
                                      _buildDataCell('-£${displayFee.toStringAsFixed(2)}', 100, color: Colors.red.shade300),
                                      _buildClickableDataCell('-£${displayActualMaint.toStringAsFixed(2)}', 100, maintRecords, color: Colors.red.shade300, isActual: true),
                                      _buildClickableDataCell('-£${displayMaint.toStringAsFixed(2)}', 100, maintRecords, color: Colors.red.shade300),
                                      _buildDataCell('-£${displayAdv.toStringAsFixed(2)}', 100, color: Colors.orange),
                                      _buildDataCell('£${displayNet.toStringAsFixed(2)}', 100, color: Colors.green, isBold: true),
                                      _buildStatusCell(statusText, statusColor, 100),
                                      _buildStatusCell(payoutText, payoutColor, 100),
                                      _buildDataCell(payouts.isNotEmpty ? payouts.last['created_at'].split('T')[0] : '-', 100, color: Colors.grey),
                                      SizedBox(
                                        width: 100,
                                        child: SizedBox(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))),
                            child: Row(
                              children: [
                                _buildHeaderCell('TOTALS', 60),
                                _buildHeaderCell('-', 100),
                                _buildHeaderCell('£${totalExpected.toStringAsFixed(2)}', 100),
                                _buildHeaderCell('£${totalCollected.toStringAsFixed(2)}', 100),
                                _buildHeaderCell('-', 100),
                                _buildHeaderCell('-£${totalAgentFee.toStringAsFixed(2)}', 100),
                                _buildHeaderCell('-£${totalActualMaint.toStringAsFixed(2)}', 100),
                                _buildHeaderCell('-£${totalMaint.toStringAsFixed(2)}', 100),
                                _buildHeaderCell('-£${totalRecovery.toStringAsFixed(2)}', 100),
                                _buildHeaderCell('£${totalNetPayout.toStringAsFixed(2)}', 100),
                                _buildHeaderCell('-', 100),
                                _buildHeaderCell('-', 100),
                                _buildHeaderCell('-', 100),
                                _buildHeaderCell('-', 100),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        );
        }
      ),
    );
  }

  Widget _buildHeaderCell(String label, double width, {Color color = Colors.white}) {
    return SizedBox(
      width: width,
      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
    );
  }

  Widget _buildDataCell(String value, double width, {Color? color, bool isBold = false}) {
    return SizedBox(
      width: width,
      child: Text(
        value, 
        style: TextStyle(
          fontSize: 12, 
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  void _showMaintPopup(List<dynamic> records, {bool isActual = false}) {
    final ScrollController scrollController = ScrollController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isActual ? 'Actual Maintenance Breakdown' : 'Maintenance Breakdown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 350),
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thickness: 8,
                  radius: const Radius.circular(4),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade900),
                        headingRowHeight: 40,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 40,
                        columns: const [
                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))),
                          DataColumn(label: Text('Provider', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))),
                          DataColumn(label: Text('Service Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))),
                          DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))),
                        ],
                        rows: records.map((rec) {
                          final amt = isActual ? (rec['actual_cost'] ?? rec['cost']) : rec['cost'];
                          return DataRow(cells: [
                            DataCell(Text(rec['maintenance_date'].toString().split('T')[0], style: const TextStyle(fontSize: 12))),
                            DataCell(Text(rec['service_provider_name'].toString(), style: const TextStyle(fontSize: 12))),
                            DataCell(Text(rec['maintenance_type']?.toString() ?? '-', style: const TextStyle(fontSize: 12))),
                            DataCell(Text('-£$amt', style: TextStyle(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.bold))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL AMOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    Text('-£${records.fold(0.0, (sum, rec) => sum + double.parse((isActual ? (rec['actual_cost'] ?? rec['cost']) : rec['cost']).toString())).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx), 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  Widget _buildClickableDataCell(String text, double width, List<dynamic> records, {Color? color, bool isActual = false}) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: records.isNotEmpty ? () => _showMaintPopup(records, isActual: isActual) : null,
        child: Row(
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                decoration: TextDecoration.none,
              ),
            ),
            if (records.isNotEmpty) ...[
              const SizedBox(width: 4),
              const Icon(Icons.info_outline, size: 14, color: Colors.grey),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildStatusCell(String text, Color color, double width) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
      ),
    );
  }


  Widget _buildBreakdownRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  void _showQuickCollectDialog(dynamic tenancy, dynamic property) {
    if (tenancy == null || property == null) return;
    final amtCtrl = TextEditingController(text: tenancy['rent_amount'].toString());
    final refCtrl = TextEditingController(text: 'Rent Payment - ${formatPropertyAddress(property)}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Direct Rent Collection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Property: ${formatPropertyAddress(property)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: amtCtrl, decoration: const InputDecoration(labelText: 'Amount Received (£)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const Text(
              'Note: This will automatically allocate payment to the oldest unpaid months first.',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final api = Provider.of<ApiService>(context, listen: false);
                await api.quickCollect(tenancy['id'], double.parse(amtCtrl.text), refCtrl.text);
                Navigator.pop(ctx);
                _loadProperties(); // Refresh
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rent collected and allocated successfully!')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Collect & Sync'),
          ),
        ],
      ),
    );
  }

  void _showAddMaintenanceDialog(int propertyId) {
    final typeCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final actualCostCtrl = TextEditingController();
    DateTime mDate = DateTime.now();
    XFile? invoiceFile;

    int? selectedProviderId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Maintenance Record'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedProviderId,
                  decoration: const InputDecoration(labelText: 'Service Provider (Optional)', border: OutlineInputBorder()),
                  items: _serviceProviders.map((sp) {
                    return DropdownMenuItem<int>(
                      value: sp['id'],
                      child: Text(sp['company_name']),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedProviderId = val),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: typeCtrl.text.isEmpty ? null : typeCtrl.text,
                  decoration: const InputDecoration(labelText: 'Maintenance Type'),
                  items: [
                    'Plumbing', 'Electrical', 'Gas & Heating', 'Roofing', 'Carpentry',
                    'Painting & Decoration', 'Cleaning', 'Gardening', 'Pest Control',
                    'Locksmith', 'General Repairs', 'Appliance Repair', 'Window/Glazing', 'Other'
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setDialogState(() => typeCtrl.text = newValue ?? '');
                  },
                ),
                const SizedBox(height: 16),
                TextField(controller: detailCtrl, decoration: const InputDecoration(labelText: 'Details')),
                const SizedBox(height: 16),
                TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Maintenance Cost (Landlord) (£)'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                TextField(controller: actualCostCtrl, decoration: const InputDecoration(labelText: 'Actual Maintenance Cost (Internal) (£)'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                ListTile(
                  title: Text('Date: ${DateFormat('dd/MM/yyyy').format(mDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: mDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setDialogState(() => mDate = picked);
                  },
                ),
                ListTile(
                  title: Text(invoiceFile == null ? 'Upload Invoice' : 'Invoice Selected'),
                  subtitle: Text(invoiceFile?.name ?? 'No file chosen'),
                  trailing: const Icon(Icons.upload_file),
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) setDialogState(() => invoiceFile = picked);
                  },
                ),
              ],
            ),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final api = Provider.of<ApiService>(context, listen: false);
                  List<int>? bytes;
                  if (invoiceFile != null) bytes = await invoiceFile!.readAsBytes();
                  
                  double actual = double.tryParse(actualCostCtrl.text) ?? 0.0;
                  double vatRate = 0.0;
                  double vatAmount = 0.0;
                  double baseCost = actual;

                  if (selectedProviderId != null) {
                    final sp = _serviceProviders.firstWhere((p) => p['id'] == selectedProviderId, orElse: () => null);
                    if (sp != null && sp['vat_registered'] == true) {
                      vatRate = 20.0;
                      baseCost = actual / 1.20;
                      vatAmount = actual - baseCost;
                    }
                  }

                  await api.addMaintenance(
                    propertyId: propertyId,
                    type: typeCtrl.text,
                    details: detailCtrl.text,
                    cost: double.tryParse(costCtrl.text) ?? 0.0,
                    actualCost: actual,
                    baseCost: baseCost,
                    vatRate: vatRate,
                    vatAmount: vatAmount,
                    date: mDate,
                    serviceProviderId: selectedProviderId,
                    invoiceBytes: bytes,
                    filename: invoiceFile?.name,
                  );
                  Navigator.pop(ctx);
                  _loadProperties(); // Refresh
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Add Record'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPropertyDetails(dynamic prop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final landlord = prop['landlord'];
        final tenants = prop['tenants'] as List<dynamic>? ?? [];
        final tenancies = prop['tenancies'] as List<dynamic>? ?? [];
        final currentTenancy = tenancies.where((t) => t['status'] == 'active').firstOrNull ?? (tenancies.isNotEmpty ? tenancies.first : null);
        
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatPropertyAddress(prop), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.mail_outline, color: Colors.blueGrey), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CommunicationCentreScreen(initialPropertyId: prop['id'])))),
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditPropertyDialog(prop)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Created: ${prop['created_at']?.split('T')[0] ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (prop['assigned_manager'] != null)
                        Chip(
                          avatar: const Icon(Icons.person, size: 12, color: Colors.blue),
                          label: Text('Managed by: ${prop['assigned_manager']['name']}', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const Divider(height: 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Landlord', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (landlord != null) TextButton(onPressed: () {}, child: const Text('View Profile'))
                    ],
                  ),
                  if (landlord != null) 
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade50, 
                        child: const Icon(Icons.business_center, color: Colors.orange)
                      ),
                      title: Text(
                        '${landlord['first_name']} ${landlord['last_name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (landlord['email'] != null && landlord['email'].toString().isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.email_outlined, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    landlord['email'],
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          if (landlord['phone'] != null && landlord['phone'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    landlord['phone'],
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    const Text('No landlord linked.'),
                  
                  const Divider(height: 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Active Tenancy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (currentTenancy != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.green.withOpacity(0.2) 
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.green.withOpacity(0.4)
                                  : Colors.green.shade200,
                            ),
                          ),
                          child: const Text('ACTIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                    ],
                  ),
                  if (currentTenancy != null) ...[
                    Card(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.green.withOpacity(0.1) 
                          : Colors.green.shade50,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.green.withOpacity(0.3)
                              : Colors.green.shade200,
                        ),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Monthly Rent: £${currentTenancy['rent_amount']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).brightness == Brightness.dark ? Colors.green.shade300 : Colors.green.shade700)),
                                Text('Due: Day ${currentTenancy['due_day']}', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.green.shade300 : Colors.green.shade700, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Started: ${currentTenancy['start_date']}', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _showRentalPlan(currentTenancy, prop),
                              icon: const Icon(Icons.calendar_month, color: Colors.green),
                              label: const Text('View 1-Year Rental Plan', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.green.shade600 : Colors.green.shade300),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ] else 
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No active tenancy found.'),
                    ),
                  
                  const Divider(height: 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Maintenance Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blue), onPressed: () => _showAddMaintenanceDialog(prop['id'])),
                    ],
                  ),
                  FutureBuilder<List<dynamic>>(
                    future: Provider.of<ApiService>(context, listen: false).fetchMaintenance(prop['id']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: LinearProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text('No maintenance records yet.', style: TextStyle(color: Colors.grey, fontSize: 12));
                      return Column(
                        children: snapshot.data!.map((m) {
                          final mDate = DateTime.tryParse(m['maintenance_date'] ?? '') ?? DateTime.now();
                          final cDate = DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(backgroundColor: Colors.brown.shade50, child: const Icon(Icons.build_circle, color: Colors.brown)),
                            title: Text(m['maintenance_type'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m['details']),
                                Text('Date: ${DateFormat('dd/MM/yyyy').format(mDate)} | Logged: ${DateFormat('dd/MM/yyyy HH:mm').format(cDate)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('£${m['cost']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                    if (m['invoice_url'] != null) const Icon(Icons.attachment, size: 14, color: Colors.blue),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () async {
                                    try {
                                      final api = Provider.of<ApiService>(context, listen: false);
                                      await api.deleteMaintenance(prop['id'], m['id']);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maintenance deleted')));
                                      Navigator.pop(context); // close bottom sheet
                                      _showPropertyDetails(prop); // reopen bottom sheet to refresh
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  
                  const Divider(height: 32),
                  const Text('Tenants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (tenants.isNotEmpty)
                    ...tenants.map((t) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade50, 
                        child: const Icon(Icons.person, color: Colors.green)
                      ),
                      title: Text(
                        '${t['first_name']} ${t['last_name']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (t['email'] != null && t['email'].toString().isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.email_outlined, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    t['email'],
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          if (t['phone'] != null && t['phone'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    t['phone'],
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Balance: £${t['credit_balance']}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    )).toList()
                  else
                    const Text('No tenants at this property.'),
                    
                  const SizedBox(height: 40),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showPropertyStatements(dynamic prop) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Statements - ${formatPropertyAddress(prop)}'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<dynamic>>(
              future: Provider.of<ApiService>(context, listen: false).fetchPropertyStatements(prop['id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                final statements = snapshot.data ?? [];
                if (statements.isEmpty) {
                  return const Text('No statements generated for this property yet.');
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: statements.length,
                  itemBuilder: (context, index) {
                    final stmt = statements[index];
                    return ListTile(
                      leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      title: Text(stmt['date'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(stmt['filename'], style: const TextStyle(fontSize: 10)),
                      trailing: IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () async {
                          final Uri url = Uri.parse(stmt['url']);
                          if (!await launchUrl(url)) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open document')));
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainAppBar(),
      body: Column(
        children: [
          const TopNavigationPills(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search properties...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => _loadProperties(query: val),
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _properties.isEmpty
                    ? const Center(child: Text('No properties found. Add one!'))
                    : ListView.builder(
                        itemCount: _properties.length,
                        itemBuilder: (context, index) {
                          final prop = _properties[index];
                          final landlord = prop['landlord'];
                          final tenancies = prop['tenancies'] as List<dynamic>? ?? [];
                          final activeTenancy = tenancies.where((t) => t['status'] == 'active').firstOrNull;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: InkWell(
                              onTap: () => _showPropertyDetails(prop),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // TOP ROW: Address and Rent
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(prop['reference_number'] ?? 'REF-PENDING', style: TextStyle(color: Colors.indigo.shade300, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                              Text(
                                                formatPropertyAddress(prop),
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).textTheme.bodyLarge?.color),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (activeTenancy != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                                            child: Text('£${activeTenancy['rent_amount']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // MIDDLE SECTION: Landlord and Tenant (Side by Side to fill space)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('LANDLORD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.business_center, size: 14, color: Colors.orange),
                                                  const SizedBox(width: 4),
                                                  Expanded(child: Text(landlord != null ? '${landlord['first_name']} ${landlord['last_name']}' : 'No landlord', style: const TextStyle(fontWeight: FontWeight.w500))),
                                                ],
                                              ),
                                              if (landlord != null) ...[
                                                if (landlord['email'] != null && landlord['email'].toString().isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2.0, left: 18.0),
                                                    child: Text(
                                                      landlord['email'],
                                                      style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                if (landlord['phone'] != null && landlord['phone'].toString().isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2.0, left: 18.0),
                                                    child: Text(
                                                      landlord['phone'],
                                                      style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                                    ),
                                                  ),
                                              ],
                                              if (prop['landlord_credit'] != null && prop['landlord_credit'] > 0)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4.0),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade200)),
                                                    child: Text('Landlord Payable: £${prop['landlord_credit']}', style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                                  ),
                                                ),
                                              if (prop['landlord_debt'] != null && prop['landlord_debt'] > 0)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4.0),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade200)),
                                                    child: Text('Owed to Agency: £${prop['landlord_debt']}', style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('TENANT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.person, size: 14, color: Colors.green),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      prop['tenants'] != null && (prop['tenants'] as List).isNotEmpty 
                                                        ? (prop['tenants'] as List).first['first_name'] + ' ' + (prop['tenants'] as List).first['last_name']
                                                        : 'No tenants',
                                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (prop['tenants'] != null && (prop['tenants'] as List).isNotEmpty) ...[
                                                Builder(
                                                  builder: (context) {
                                                    final firstTenant = (prop['tenants'] as List).first;
                                                    return Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        if (firstTenant['email'] != null && firstTenant['email'].toString().isNotEmpty)
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 2.0, left: 18.0),
                                                            child: Text(
                                                              firstTenant['email'],
                                                              style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        if (firstTenant['phone'] != null && firstTenant['phone'].toString().isNotEmpty)
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 2.0, left: 18.0),
                                                            child: Text(
                                                              firstTenant['phone'],
                                                              style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                                                            ),
                                                          ),
                                                      ],
                                                    );
                                                  }
                                                ),
                                              ],
                                              if (prop['tenant_credit'] != null && prop['tenant_credit'] > 0)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4.0),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade200)),
                                                    child: Text('Tenant Credit: £${prop['tenant_credit']}', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // BOTTOM SECTION: Managed By & Due Date
                                    Row(
                                      children: [
                                        if (prop['assigned_manager'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.admin_panel_settings, size: 12, color: Colors.blue),
                                                const SizedBox(width: 4),
                                                Text('Agent: ${prop['assigned_manager']['name']}', style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        const Spacer(),
                                        Builder(
                                          builder: (context) {
                                            DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                                            bool isOverdue = false;
                                            if (prop['next_due_date'] != null) {
                                                DateTime dueDate = DateTime.parse(prop['next_due_date']);
                                                isOverdue = !dueDate.isAfter(today);
                                            }
                                            String dateText = prop['next_due_date'] != null 
                                              ? 'Due: ${DateFormat('dd MMM').format(DateTime.parse(prop['next_due_date']))}' 
                                              : (activeTenancy != null ? 'Due: Day ${activeTenancy['due_day']}' : 'No lease');
                                              
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isOverdue ? Colors.red : Colors.transparent,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.calendar_today, size: 14, color: isOverdue ? Colors.white : Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    dateText, 
                                                    style: TextStyle(
                                                      fontSize: 12, 
                                                      color: isOverdue ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                                                      fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                                    )
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        ),
                                      ],
                                    ),
                                    
                                    const Divider(height: 20),
                                    
                                    // FOOTER: Dates and Actions
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Added: ${prop['created_at']?.split('T')[0] ?? 'N/A'}',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                        Row(
                                          children: [
                                            if (activeTenancy != null)
                                              InkWell(
                                                onTap: () => _showRentalPlan(activeTenancy, prop),
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.description_outlined, size: 14, color: Colors.blue),
                                                      SizedBox(width: 4),
                                                      Text('Rent Schedule', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            InkWell(
                                              onTap: () => _showPropertyStatements(prop),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.receipt_long, size: 14, color: Colors.blue),
                                                    SizedBox(width: 4),
                                                    Text('Statements', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            if (activeTenancy != null)
                                              InkWell(
                                                onTap: () {
                                                  _showQuickCollectDialog(activeTenancy, prop);
                                                },
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.add_circle_outline, size: 14, color: Colors.blue),
                                                    SizedBox(width: 4),
                                                    Text('Collect Rent', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            const SizedBox(width: 12),
                                            InkWell(
                                              onTap: () {
                                                _showAddMaintenanceDialog(prop['id']);
                                              },
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.build_circle_outlined, size: 14, color: Colors.blue),
                                                  SizedBox(width: 4),
                                                  Text('Maintenance', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            InkWell(
                                              onTap: () {
                                                Navigator.push(context, MaterialPageRoute(builder: (context) => CommunicationCentreScreen(initialPropertyId: prop['id'])));
                                              },
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.mail_outline, size: 14, color: Colors.blue),
                                                  SizedBox(width: 4),
                                                  Text('Email', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text('View More', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                            const Icon(Icons.chevron_right, size: 16, color: Colors.blue),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _launchAdvancedSetup,
        child: const Icon(Icons.add),
      ),
    );
  }
}
