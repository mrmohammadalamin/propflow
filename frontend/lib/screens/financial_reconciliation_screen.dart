import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:agentic_ui/services/api_service.dart';
import 'package:agentic_ui/utils/formatters.dart';

class FinancialReconciliationScreen extends StatefulWidget {
  const FinancialReconciliationScreen({super.key});

  @override
  State<FinancialReconciliationScreen> createState() => _FinancialReconciliationScreenState();
}

class _FinancialReconciliationScreenState extends State<FinancialReconciliationScreen> {
  List<dynamic> _bankEntries = [];
  List<dynamic> _expectedPayments = [];
  bool _isLoading = true;
  dynamic _selectedEntry;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final entries = await api.fetchBankEntries();
      final expected = await api.fetchExpectedPayments();
      setState(() {
        _bankEntries = entries;
        _expectedPayments = expected;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAllocationDialog(dynamic tenancy) {
    if (_selectedEntry == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a bank entry first')));
      return;
    }

    final remainingInEntry = double.parse(_selectedEntry['amount'].toString()) - double.parse(_selectedEntry['allocated_amount'].toString());
    final rentAmount = double.parse(tenancy['rent_amount'].toString());
    final amountCtrl = TextEditingController(text: (remainingInEntry < rentAmount ? remainingInEntry : rentAmount).toString());
    DateTime selectedMonth = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Allocate Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Allocating from: ${_selectedEntry['reference']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('To Tenancy: ${formatPropertyAddress(tenancy['property'])}'),
              const Divider(height: 32),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount to Allocate (£)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('Month: ${DateFormat('MMMM yyyy').format(selectedMonth)}'),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  // Simplified month picker
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedMonth,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setDialogState(() => selectedMonth = DateTime(picked.year, picked.month, 1));
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final api = Provider.of<ApiService>(context, listen: false);
                  await api.allocatePayment({
                    'bank_entry_id': _selectedEntry['id'],
                    'tenancy_id': tenancy['id'],
                    'amount': double.parse(amountCtrl.text),
                    'month_date': DateFormat('yyyy-MM-01').format(selectedMonth),
                  });
                  Navigator.pop(ctx);
                  _loadData();
                  setState(() => _selectedEntry = null);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment allocated and deductions calculated!')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Confirm Allocation'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBankEntryDialog() {
    final refCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Bank Statement Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference (e.g. SMITH RENT)')),
              TextField(controller: amtCtrl, decoration: const InputDecoration(labelText: 'Amount (£)'), keyboardType: TextInputType.number),
              ListTile(
                title: Text('Date: ${DateFormat('dd/MM/yyyy').format(date)}'),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (picked != null) setDialogState(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final api = Provider.of<ApiService>(context, listen: false);
                  await api.createBankEntry({
                    'reference': refCtrl.text,
                    'amount': double.parse(amtCtrl.text),
                    'date': DateFormat('yyyy-MM-dd').format(date),
                  });
                  Navigator.pop(ctx);
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Rent Allocation'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.add_card), onPressed: _showAddBankEntryDialog),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    children: [
                      Expanded(flex: 2, child: _buildBankPanel()),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 3, child: _buildExpectedPanel()),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Expanded(child: _buildBankPanel()),
                      const Divider(height: 1),
                      Expanded(child: _buildExpectedPanel()),
                    ],
                  );
                }
              },
            ),
    );
  }

  Widget _buildBankPanel() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          width: double.infinity,
          child: const Text('BANK STATEMENT ENTRIES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _bankEntries.length,
            itemBuilder: (context, index) {
              final entry = _bankEntries[index];
              final isSelected = _selectedEntry?['id'] == entry['id'];
              final isAllocated = entry['status'] == 'allocated';
              
              return ListTile(
                selected: isSelected,
                selectedTileColor: Colors.blue.withOpacity(0.1),
                leading: Icon(
                  isAllocated ? Icons.check_circle : Icons.account_balance_wallet,
                  color: isAllocated ? Colors.green : (isSelected ? Colors.blue : Colors.grey),
                ),
                title: Text(entry['reference'] ?? 'No Ref'),
                subtitle: Text(entry['date']),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('£${entry['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (entry['allocated_amount'] > 0)
                      Text('Allocated: £${entry['allocated_amount']}', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                  ],
                ),
                onTap: isAllocated ? null : () => setState(() => _selectedEntry = isSelected ? null : entry),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpectedPanel() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.green.shade50,
          width: double.infinity,
          child: const Text('EXPECTED RENT PAYMENTS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        Expanded(
          child: _expectedPayments.isEmpty
            ? const Center(child: Text('No active tenancies found'))
            : ListView.builder(
                itemCount: _expectedPayments.length,
                itemBuilder: (context, index) {
                  final tenancy = _expectedPayments[index];
                  final tenants = tenancy['property']['tenants'] as List? ?? [];
                  final tenantName = tenants.isNotEmpty ? '${tenants[0]['first_name']} ${tenants[0]['last_name']}' : 'No Tenant';
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(formatPropertyAddress(tenancy['property']), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Tenant: $tenantName • Due Day: ${tenancy['due_day']}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('£${tenancy['rent_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          const Text('EXPECTED', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      onTap: () => _showAllocationDialog(tenancy),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}
