import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agentic_ui/services/api_service.dart';
import 'package:intl/intl.dart';

class EmailActivityScreen extends StatefulWidget {
  const EmailActivityScreen({super.key});

  @override
  State<EmailActivityScreen> createState() => _EmailActivityScreenState();
}

class _EmailActivityScreenState extends State<EmailActivityScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final api = Provider.of<ApiService>(context, listen: false);
    setState(() => _isLoading = true);
    try {
      final res = await api.fetchEmailActivityLogs(status: _selectedStatus);
      setState(() {
        _logs = res['logs'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Activity Logs'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text('Status Filter: '),
                DropdownButton<String>(
                  value: _selectedStatus,
                  dropdownColor: Colors.white,
                  items: ['All', 'Sent', 'Opened', 'Unopened', 'Failed', 'Pending']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedStatus = val;
                      });
                      _loadLogs();
                    }
                  },
                ),
              ],
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text("No email logs found."))
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.grey.withOpacity(0.1)),
                      columns: const [
                        DataColumn(label: Text('Date Sent', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Recipient', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Tenant', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Property', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Delivery Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Open Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _logs.map((log) {
                        return DataRow(cells: [
                          DataCell(Text(DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(log['date_sent']).toLocal()))),
                          DataCell(Text(log['email_type'] ?? '')),
                          DataCell(Text(log['subject'] ?? 'No Subject')),
                          DataCell(Text(log['recipient_email'] ?? '')),
                          DataCell(Text(log['tenant_name'] ?? '')),
                          DataCell(Text(log['property_address'] ?? '')),
                          DataCell(_buildStatusChip(log['delivery_status'])),
                          DataCell(_buildOpenStatusChip(log['open_status'])),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color = Colors.grey;
    if (status == 'sent' || status == 'delivered') color = Colors.green;
    if (status == 'failed' || status == 'bounced') color = Colors.red;
    if (status == 'pending') color = Colors.orange;

    return Chip(
      label: Text((status ?? 'Unknown').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildOpenStatusChip(String? status) {
    bool opened = status == 'Opened';
    return Chip(
      label: Text(opened ? 'OPENED' : 'UNOPENED', style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: opened ? Colors.blue : Colors.grey,
      padding: EdgeInsets.zero,
    );
  }
}
