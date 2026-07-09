import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class AgencyReportsScreen extends StatefulWidget {
  const AgencyReportsScreen({super.key});

  @override
  State<AgencyReportsScreen> createState() => _AgencyReportsScreenState();
}

class _AgencyReportsScreenState extends State<AgencyReportsScreen> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _reports = [];
  bool _isLoadingList = true;
  bool _isGenerating = false;
  Map<String, dynamic>? _activeReportBreakdown;

  @override
  void initState() {
    super.initState();
    _loadReportsAndAutoGenerate();
  }

  Future<void> _loadReportsAndAutoGenerate() async {
    await _loadReports();
    await _autoGenerateTodayReport();
  }

  Future<void> _autoGenerateTodayReport() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final today = DateTime.now();
      final formattedDate = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final result = await api.generateDailyReport(formattedDate);
      
      // Quietly set the active breakdown to today's statement so they immediately see today's live stats
      if (mounted && _activeReportBreakdown == null) {
        setState(() {
          _activeReportBreakdown = result;
        });
      }
      
      // Reload the history quietly so today's statement is listed in the ledger DataGrid
      final data = await api.fetchDailyReports();
      if (mounted) {
        setState(() {
          _reports = data;
        });
      }
    } catch (e) {
      // Quietly pass background issues to allow standard execution
      debugPrint("Silent background report generation pass: $e");
    }
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingList = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.fetchDailyReports();
      setState(() {
        _reports = data;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report history: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final formattedDate = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final result = await api.generateDailyReport(formattedDate);
      
      setState(() {
        _activeReportBreakdown = result;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily statement generated successfully!')),
        );
      }
      _loadReports();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _viewReportBreakdown(dynamic report) async {
    final filename = report['filename'] as String? ?? '';
    String? reportDateStr;
    if (filename.startsWith("DailyReport_") && filename.length >= 20) {
      final datePart = filename.substring(12, 20); // 20260517
      if (datePart.length == 8) {
        reportDateStr = "${datePart.substring(0, 4)}-${datePart.substring(4, 6)}-${datePart.substring(6, 8)}";
      }
    }

    setState(() => _isGenerating = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.generateDailyReport(reportDateStr);
      setState(() {
        _activeReportBreakdown = result;
      });
    } catch (e) {
      setState(() {
        _activeReportBreakdown = {
          "date": report['date'],
          "total_received": 0.0,
          "payments_count": 0,
          "total_management_fees": 0.0,
          "total_maintenance_costs": 0.0,
          "payments_details": [],
          "management_details": [],
          "maintenance_details": [],
          "pdf_url": report['url'],
          "filename": report['filename']
        };
      });
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E2F).withOpacity(0.3) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.indigo.withOpacity(0.08);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agency Reports & Statements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh History',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 950;

          if (isLargeScreen) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel: Generator & List
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildLeftPanel(cardColor, borderColor, isDark),
                  ),
                ),
                VerticalDivider(width: 1, color: borderColor),
                // Right Panel: Active breakdown details
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildRightPanel(cardColor, borderColor, isDark),
                  ),
                ),
              ],
            );
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildLeftPanel(cardColor, borderColor, isDark),
                  const SizedBox(height: 24),
                  _buildRightPanel(cardColor, borderColor, isDark),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildLeftPanel(Color cardColor, Color borderColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Generator Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.cyan.withOpacity(0.1),
                    child: const Icon(Icons.assessment_outlined, color: Colors.cyan),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Daily Statement Builder',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Generate today\'s statement or select a custom date to compile administrative Daily Transaction Reports including all payments, fee commissions, and maintenance cost deductions.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: Colors.indigo.shade400),
                          const SizedBox(width: 12),
                          Text(
                            "${_selectedDate.day.toString().padLeft(2, '0')} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _selectDate(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    child: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.analytics_outlined),
                  label: const Text(
                    'Generate Daily Statement',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.grid_on, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Text(
                  'Daily Statements Ledger (DataGrid)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _loadReports,
              tooltip: 'Refresh History',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _isLoadingList
            ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
            : _reports.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.grid_off_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No daily statements generated yet.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 24,
                          headingRowColor: MaterialStateProperty.all(isDark ? Colors.white.withOpacity(0.05) : Colors.indigo.shade50),
                          columns: const [
                            DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('TIME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('STATEMENT FILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          ],
                          rows: _reports.map((report) {
                            final filename = report['filename'] as String? ?? 'N/A';
                            final shortFilename = filename.length > 25
                                ? "${filename.substring(0, 12)}...${filename.substring(filename.length - 8)}"
                                : filename;
                            
                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(report['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    ],
                                  )
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(report['time'] ?? '', style: const TextStyle(fontSize: 12)),
                                    ],
                                  )
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.picture_as_pdf, size: 13, color: Colors.red),
                                      const SizedBox(width: 6),
                                      Text(shortFilename, style: const TextStyle(fontSize: 11, fontFamily: 'Courier')),
                                    ],
                                  )
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _viewReportBreakdown(report),
                                        icon: const Icon(Icons.bar_chart, size: 14, color: Colors.cyan),
                                        label: const Text('View', style: TextStyle(color: Colors.cyan, fontSize: 11)),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.download, color: Colors.indigo, size: 16),
                                        onPressed: () async {
                                          final Uri url = Uri.parse(report['url']);
                                          if (!await launchUrl(url)) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Could not open document')),
                                              );
                                            }
                                          }
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  )
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
      ],
    );
  }

  Widget _buildRightPanel(Color cardColor, Color borderColor, bool isDark) {
    if (_activeReportBreakdown == null) {
      return Container(
        width: double.infinity,
        height: 450,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No Report Selected',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Select a daily statement from the history panel or pick a date and click generate to view the transactional details here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final rep = _activeReportBreakdown!;
    final payments = rep['payments_details'] as List<dynamic>? ?? [];
    final fees = rep['management_details'] as List<dynamic>? ?? [];
    final maintenance = rep['maintenance_details'] as List<dynamic>? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Daily Transaction Details",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Statement Date: ${rep['date']}",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final Uri url = Uri.parse(rep['pdf_url']);
                  if (!await launchUrl(url)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open statement PDF')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: _statMetricBox(
                  'Payments Today',
                  "£${(rep['total_received'] as num).toStringAsFixed(2)}",
                  "${rep['payments_count']} payments",
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statMetricBox(
                  'Management Fees',
                  "£${(rep['total_management_fees'] as num).toStringAsFixed(2)}",
                  "Agency share",
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statMetricBox(
                  'Maintenance Fees',
                  "£${(rep['total_maintenance_costs'] as num).toStringAsFixed(2)}",
                  "Deducted costs",
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '1. Payments Received Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (payments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No payments received on this date.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              itemBuilder: (context, idx) {
                final p = payments[idx];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.blue.withOpacity(0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.blue.withOpacity(0.1)),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
                    title: Text(p['property'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Tenant: ${p['tenant']}"),
                    trailing: Text(
                      "£${(p['amount'] as num).toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          const Text(
            '2. Management Fees Earned Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (fees.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No management fees processed on this date.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: fees.length,
              itemBuilder: (context, idx) {
                final f = fees[idx];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.orange.withOpacity(0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.orange.withOpacity(0.1)),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.percent, color: Colors.orange),
                    title: Text(f['property'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Fee Percentage: ${f['fee_percentage']}%"),
                    trailing: Text(
                      "£${(f['amount'] as num).toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          const Text(
            '3. Maintenance Deductions Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (maintenance.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No maintenance deductions processed on this date.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: maintenance.length,
              itemBuilder: (context, idx) {
                final mt = maintenance[idx];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.red.withOpacity(0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red.withOpacity(0.1)),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.build_outlined, color: Colors.red),
                    title: Text(mt['property'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Type: ${mt['type']} (Contractor: ${mt['provider']})"),
                    trailing: Text(
                      "£${(mt['cost'] as num).toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _statMetricBox(String title, String val, String subtitle, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: themeColor)),
          const SizedBox(height: 6),
          Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeColor)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
