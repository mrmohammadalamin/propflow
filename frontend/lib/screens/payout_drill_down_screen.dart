import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class PayoutDrillDownScreen extends StatefulWidget {
  final String? paymentType;
  final String? initialStatus;
  final String? timeframe;

  const PayoutDrillDownScreen({
    super.key,
    this.paymentType,
    this.initialStatus,
    this.timeframe,
  });

  @override
  State<PayoutDrillDownScreen> createState() => _PayoutDrillDownScreenState();
}

class _PayoutDrillDownScreenState extends State<PayoutDrillDownScreen> {
  late Future<List<dynamic>> _payoutsFuture;
  late String _currentStatus;

  final List<String> _statuses = [
    'Pending Distribution',
    'Paid',
    'Partially Paid',
    'Processing',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    // Map initialStatus (like 'pending') to dropdown values if needed
    if (widget.initialStatus == 'pending') {
      _currentStatus = 'Pending Distribution';
    } else if (widget.initialStatus == 'paid') {
      _currentStatus = 'Paid';
    } else {
      _currentStatus = _statuses.contains(widget.initialStatus) ? widget.initialStatus! : _statuses.first;
    }
    _loadPayouts();
  }

  void _loadPayouts() {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _payoutsFuture = apiService.fetchPayouts(
        paymentType: widget.paymentType,
        status: _currentStatus,
        timeframe: widget.timeframe,
      );
    });
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return 'N/A';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return 'N/A';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    String titleText = 'Details';
    if (widget.paymentType == 'agent_fee') titleText = 'Agent Fee Distributions';
    if (widget.paymentType == 'landlord') titleText = 'Landlord Distributions';
    if (widget.paymentType == 'service_provider') titleText = 'Maintenance Distributions';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Filter by Status: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _currentStatus,
                  items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _currentStatus = val;
                        _loadPayouts();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _payoutsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }

                  final payouts = snapshot.data ?? [];
                  if (payouts.isEmpty) {
                    return const Center(child: Text('No payouts found for the selected criteria.'));
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.resolveWith<Color>((states) {
                          return Theme.of(context).brightness == Brightness.dark 
                              ? Colors.indigo.shade900 
                              : Colors.indigo.shade50;
                        }),
                        headingTextStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white 
                              : Colors.indigo.shade900,
                        ),
                        columns: const [
                          DataColumn(label: Text('Property Name')),
                          DataColumn(label: Text('Property Ref')),
                          DataColumn(label: Text('Tenant')),
                          DataColumn(label: Text('Landlord')),
                          DataColumn(label: Text('Recipient')),
                          DataColumn(label: Text('Payment Type')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Payment Date')),
                        ],
                        rows: payouts.map((p) {
                          return DataRow(cells: [
                            DataCell(Text(p['property_name'] ?? 'N/A')),
                            DataCell(Text(p['property_ref'] ?? 'N/A')),
                            DataCell(Text(p['tenant_name'] ?? 'N/A')),
                            DataCell(Text(p['landlord_name'] ?? 'N/A')),
                            DataCell(Text(p['recipient_name'] ?? 'N/A')),
                            DataCell(Text(p['payment_type'] ?? 'N/A')),
                            DataCell(Text('£${double.parse((p['net_amount'] ?? 0).toString()).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(p['status'] ?? 'N/A')),
                            DataCell(Text(_formatDate(p['updated_at'] ?? ''))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
