import 'package:dropdown_search/dropdown_search.dart';
import '../widgets/top_navigation_pills.dart';
import '../widgets/main_app_bar.dart';
import 'package:flutter/material.dart';
import '../services/auth_provider.dart';
import '../services/theme_provider.dart';
import 'login_screen.dart';
import 'global_settings_screen.dart';
import 'properties_screen.dart';
import 'tenants_screen.dart';
import 'landlords_screen.dart';
import 'user_management_screen.dart';
import 'service_provider_screen.dart';
import 'financial_reconciliation_screen.dart';
import 'landlord_payouts_screen.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:agentic_ui/services/api_service.dart';
import 'package:agentic_ui/utils/formatters.dart';

class AdvancedReportScreen extends StatefulWidget {
  const AdvancedReportScreen({super.key});

  @override
  State<AdvancedReportScreen> createState() => _AdvancedReportScreenState();
}

class _AdvancedReportScreenState extends State<AdvancedReportScreen> {
  String _reportType = 'agency_summary'; // landlord_invoice_single, landlord_invoice_multi, tenant_invoice, agency_summary
  DateTime _dateFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateTo = DateTime.now();
  
  String? _selectedPropertyId;
  String? _selectedLandlordId;
  String? _selectedTenantId;
  
  List<dynamic> _properties = [];
  List<dynamic> _landlords = [];
  List<dynamic> _tenants = [];
  
  bool _isLoading = false;
  Map<String, dynamic>? _previewData;

  bool _isSearchFocused = false;
  bool _isSearchHovered = false;
  bool _isRightColumnExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final props = await api.fetchProperties();
      final lls = await api.fetchLandlords();
      final tens = await api.fetchTenants();
      if (mounted) {
        setState(() {
          _properties = props;
          _landlords = lls;
          _tenants = tens;
        });
      }
    } catch (e) {
      debugPrint("Error loading filters: $e");
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom,
      firstDate: DateTime(2020),
      lastDate: _dateTo,
    );
    if (picked != null) setState(() => _dateFrom = picked);
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo,
      firstDate: _dateFrom,
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dateTo = picked);
  }

  Future<void> _previewReport() async {
    if ((_reportType == 'landlord_invoice_single' || _reportType == 'agency_property_statement') && _selectedPropertyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a property.')));
      return;
    }
    if (_reportType == 'landlord_invoice_multi' && _selectedLandlordId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a landlord.')));
      return;
    }
    if (_reportType == 'tenant_invoice' && _selectedTenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a tenant.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final requestData = {
        "report_type": _reportType,
        "date_from": DateFormat('yyyy-MM-dd').format(_dateFrom),
        "date_to": DateFormat('yyyy-MM-dd').format(_dateTo),
        "property_id": _selectedPropertyId != null ? int.parse(_selectedPropertyId!) : null,
        "landlord_id": _selectedLandlordId != null ? int.parse(_selectedLandlordId!) : null,
        "tenant_id": _selectedTenantId != null ? int.parse(_selectedTenantId!) : null,
        "statuses": ["paid"]
      };
      
      final data = await api.previewReport(requestData);
      setState(() {
        _previewData = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePdf() async {
    if (_previewData == null) return;
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.generateReportPdf(_previewData!);
      if (result['pdf_url'] != null) {
        final url = Uri.parse(result['pdf_url']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        } else {
          throw 'Could not launch PDF URL';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTopNavigationBar(BuildContext context, bool canManageUsers, bool canManageFinance) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _navButton(context, 'Properties', Icons.home, Colors.blue, const PropertiesScreen()),
                if (canManageFinance) _navButton(context, 'Payouts', Icons.payments_outlined, Colors.blue, const LandlordPayoutsScreen()),
                _navButton(context, 'Reports', Icons.assessment_outlined, Colors.blue, const AdvancedReportScreen()),
                _navButton(context, 'Landlords', Icons.business_center, Colors.blue, const LandlordsScreen()),
                _navButton(context, 'Tenants', Icons.person, Colors.blue, const TenantsScreen()),
                _navButton(context, 'Services', Icons.build_circle, Colors.blue, const ServiceProviderScreen()),
                if (canManageUsers) _navButton(context, 'Users', Icons.people_alt, Colors.blue, const UserManagementScreen()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(BuildContext context, String title, IconData icon, Color color, Widget destination) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5)),
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


  String _getReportTitle() {
    switch (_reportType) {
      case 'landlord_statement': return 'Landlord Statement Preview';
      case 'landlord_invoice_multi': return 'Landlord Invoice Preview';
      case 'tenant_invoice': return 'Tenant Invoice Preview';
      case 'agency_property_statement': return 'Property Statement Preview';
      case 'agency_summary': default: return 'Agency Summary Preview';
    }
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
        children: [
          const TopNavigationPills(),
          const Divider(height: 1),
          AppBar(
            title: const Text('Report'),
            primary: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Filters
                Container(
                  width: 350,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Report Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _reportType,
                        decoration: const InputDecoration(labelText: 'Report Type', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'agency_summary', child: Text('Agency Summary Report')),
                    DropdownMenuItem(value: 'agency_property_statement', child: Text('Statement of Account (Property)')),
                    DropdownMenuItem(value: 'landlord_invoice_single', child: Text('Landlord Invoice (Single Property)')),
                    DropdownMenuItem(value: 'landlord_invoice_multi', child: Text('Landlord Invoice (Multiple Properties)')),
                    DropdownMenuItem(value: 'tenant_invoice', child: Text('Tenant Invoice')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _reportType = val!;
                      _previewData = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('Date Range', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectStartDate(context),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(DateFormat('MMM dd, yyyy').format(_dateFrom), style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('to'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _selectEndDate(context),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(DateFormat('MMM dd, yyyy').format(_dateTo), style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_reportType == 'landlord_invoice_single' || _reportType == 'agency_property_statement')
                  DropdownSearch<String>(
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    items: (filter, props) {
                      return _properties.where((p) {
                        if (filter.isEmpty) return true;
                        final address = formatPropertyAddress(p);
                        return address.toLowerCase().contains(filter.toLowerCase());
                      }).map((p) => p['id'].toString()).toList();
                    },
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(labelText: 'Select Property', border: OutlineInputBorder()),
                    ),
                    onChanged: (val) => setState(() => _selectedPropertyId = val),
                    selectedItem: _selectedPropertyId,
                    itemAsString: (String? id) {
                      if (id == null) return '';
                      var p = _properties.firstWhere((e) => e['id'].toString() == id, orElse: () => {});
                      return formatPropertyAddress(p);
                    },
                  ),
                if (_reportType == 'landlord_invoice_multi')
                  DropdownSearch<String>(
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    items: (filter, props) {
                      return _landlords.where((l) {
                        if (filter.isEmpty) return true;
                        final name = '${l['first_name']} ${l['last_name']}';
                        return name.toLowerCase().contains(filter.toLowerCase());
                      }).map((l) => l['id'].toString()).toList();
                    },
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(labelText: 'Select Landlord', border: OutlineInputBorder()),
                    ),
                    onChanged: (val) => setState(() => _selectedLandlordId = val),
                    selectedItem: _selectedLandlordId,
                    itemAsString: (String? id) {
                      if (id == null) return '';
                      var l = _landlords.firstWhere((e) => e['id'].toString() == id, orElse: () => {});
                      if (l.isEmpty) return 'Unknown';
                      return '${l['first_name']} ${l['last_name']}';
                    },
                  ),
                if (_reportType == 'tenant_invoice')
                  DropdownSearch<String>(
                    popupProps: const PopupProps.menu(showSearchBox: true),
                    items: (filter, props) {
                      return _tenants.where((t) {
                        if (filter.isEmpty) return true;
                        final name = '${t['first_name']} ${t['last_name']}';
                        return name.toLowerCase().contains(filter.toLowerCase());
                      }).map((t) => t['id'].toString()).toList();
                    },
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(labelText: 'Select Tenant', border: OutlineInputBorder()),
                    ),
                    onChanged: (val) => setState(() => _selectedTenantId = val),
                    selectedItem: _selectedTenantId,
                    itemAsString: (String? id) {
                      if (id == null) return '';
                      var t = _tenants.firstWhere((e) => e['id'].toString() == id, orElse: () => {});
                      if (t.isEmpty) return 'Unknown';
                      return '${t['first_name']} ${t['last_name']}';
                    },
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _previewReport,
                  icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.preview),
                  label: const Text('Preview Report'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ],
            ),
          ),
          // Right side: Preview
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.grey.shade50,
              child: _previewData == null
                  ? const Center(child: Text('Select configuration and click Preview Report to view data here.', style: TextStyle(color: Colors.black)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_getReportTitle(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _generatePdf,
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('Download PDF'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: Colors.grey.shade300,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                              child: Center(
                                child: Container(
                                  width: 800, // Print layout width approximation
                                  constraints: const BoxConstraints(minHeight: 1130), // A4 height approximation
                                  padding: const EdgeInsets.all(48.0), // Margin simulation
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 2, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dataTableTheme: const DataTableThemeData(
                                        dataTextStyle: TextStyle(color: Colors.black),
                                        headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                    ),
                                    child: DefaultTextStyle(
                                      style: const TextStyle(color: Colors.black),
                                      child: _buildPreviewContent(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            ),
          ],
        ),
      ),
    ],
  ),
);
}

  Widget _buildPreviewContent() {
    final totals = _previewData!['totals'] ?? {};
    
    final agency = _previewData!['agency_info'];
    
    List<Widget> rows = [];
    
    final bool isInvoice = _previewData!['report_type'] != null && 
        (_previewData!['report_type'].contains('invoice') || _previewData!['report_type'] == 'agency_property_statement' || _previewData!['report_type'] == 'landlord_statement');

    if (agency != null) {
      String logoUrl = agency['logo_url'] ?? '';
      
      if (isInvoice) {
        if (_previewData!['report_type'] == 'agency_property_statement' || _previewData!['report_type'] == 'landlord_statement') {
          rows.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Agency Name & Tagline
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agency['name']?.toUpperCase() ?? 'ALLEN GOLDSTEIN',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 2.0, color: Colors.black87),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'BESPOKE PROPERTY MANAGEMENT',
                            style: TextStyle(fontSize: 9, color: Colors.grey, letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),
                    // Right: Agency Logo & Contact
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (logoUrl.isNotEmpty)
                            Image.network('http://127.0.0.1:8000$logoUrl', height: 45, fit: BoxFit.contain),
                          const SizedBox(height: 8),
                          Text((agency['address'] ?? '104 Cromer Street, London, WC1H 8BZ').replaceAll('\n', ', '), textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          Text(agency['contact_number'] ?? '+44 (0) 207 183 4101', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          Text(agency['email'] ?? 'accounts@allengoldstein.com', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          Text('www.allengoldstein.com', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.grey, thickness: 0.5),
                const SizedBox(height: 32),
                
                // Statement Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Statement of Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const SizedBox(width: 80, child: Text('LANDLORD', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
                              Expanded(child: Text(_previewData!['landlord_name']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(width: 80, child: Text('PROPERTY', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
                              Expanded(child: Text(_previewData!['property']?['address']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(width: 80, child: Text('PERIOD', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
                              Expanded(child: Text('${_previewData!['date_from']} to ${_previewData!['date_to']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('DATE OF ISSUE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(DateFormat('dd MMMM yyyy').format(DateTime.now()), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Summary Boxes
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            const Text('TOTAL RENTAL INCOME', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text('£${(_previewData!['total_rental_income'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            const Text('EXPENSES & FEES', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text('£${(_previewData!['total_expenses'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1a1a1a),
                        ),
                        child: Column(
                          children: [
                            const Text('NET LANDLORD PAYOUT', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text('£${(_previewData!['net_landlord_payout'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ]
            )
          );
        } else {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Client Details
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_previewData!['landlord'] != null) ...[
                          Text(_previewData!['landlord']['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (_previewData!['landlord']['address'] != null) Text(_previewData!['landlord']['address']),
                          if (_previewData!['landlord']['email'] != null) Text('Email: ${_previewData!['landlord']['email']}'),
                          if (_previewData!['landlord']['mobile_number'] != null) Text('Tel: ${_previewData!['landlord']['mobile_number']}'),
                        ],
                        if (_previewData!['tenant'] != null) ...[
                          Text(_previewData!['tenant']['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (_previewData!['tenant']['email'] != null) Text('Email: ${_previewData!['tenant']['email']}'),
                          if (_previewData!['tenant']['phone'] != null) Text('Tel: ${_previewData!['tenant']['phone']}'),
                        ],
                      ],
                    ),
                  ),
                  // Middle Column: INVOICE title
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: const Text(
                        'INVOICE', 
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // Right Column: Agency Details
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (logoUrl.isNotEmpty) 
                          Image.network('http://127.0.0.1:8000$logoUrl', height: 60, fit: BoxFit.contain),
                        if (logoUrl.isNotEmpty) const SizedBox(height: 8),
                        Text(agency['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(agency['address'] ?? '', textAlign: TextAlign.right),
                        Text('Email: ${agency['email'] ?? ''}'),
                        Text('Tel: ${agency['contact_number'] ?? ''}'),
                      ],
                    ),
                  ),
                ],
              ),
            )
          );
          rows.add(const Divider());
          rows.add(const SizedBox(height: 16));
          
          // Add invoice specific metadata below header
          rows.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice Number: INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Invoice Date: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (_previewData!['property'] != null) Text('Property: ${_previewData!['property']['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Date Range: ${_previewData!['date_from']} to ${_previewData!['date_to']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            )
          );
          rows.add(const SizedBox(height: 24));
        }
      } else {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date Range: ${_previewData!['date_from']} to ${_previewData!['date_to']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (_previewData!['landlord'] != null) Text('Landlord: ${_previewData!['landlord']['name']}'),
                      if (_previewData!['tenant'] != null) Text('Tenant: ${_previewData!['tenant']['name']}'),
                      if (_previewData!['property'] != null) Text('Property: ${_previewData!['property']['name']}'),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (logoUrl.isNotEmpty) 
                      Image.network('http://127.0.0.1:8000$logoUrl', height: 60, fit: BoxFit.contain),
                    if (logoUrl.isNotEmpty) const SizedBox(height: 8),
                    Text(agency['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(agency['address'] ?? ''),
                    Text('Email: ${agency['email'] ?? ''}'),
                    Text('Tel: ${agency['contact_number'] ?? ''}'),
                  ],
                ),
              ],
            ),
          ),
        );
        rows.add(const Divider());
        rows.add(const SizedBox(height: 16));
      }
    } else {
      rows.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date Range: ${_previewData!['date_from']} to ${_previewData!['date_to']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (_previewData!['landlord'] != null) Text('Landlord: ${_previewData!['landlord']['name']}'),
                if (_previewData!['tenant'] != null) Text('Tenant: ${_previewData!['tenant']['name']}'),
                if (_previewData!['property'] != null) Text('Property: ${_previewData!['property']['name']}'),
              ],
            ),
          ),
        ),
      );
      rows.add(const SizedBox(height: 16));
    }
    
    if (_previewData!['report_type'] == 'agency_summary') {
      rows.add(const Text('Totals Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
      rows.add(const SizedBox(height: 8));
      
      rows.add(DataTable(
        headingRowHeight: 0,
        columns: const [DataColumn(label: Text('')), DataColumn(label: Text(''))],
        rows: totals.entries.map<DataRow>((e) {
          final val = double.tryParse(e.value?.toString() ?? '');
          return DataRow(cells: [
            DataCell(Text(e.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black))),
            DataCell(Text('£${val != null ? val.toStringAsFixed(2) : '0.00'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
          ]);
        }).toList(),
      ));
    } else if (_previewData!['report_type'] == 'tenant_invoice') {
      rows.add(const Text('Totals Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
      rows.add(const SizedBox(height: 8));
      
      final totalRentDue = double.tryParse(totals['total_rent_due']?.toString() ?? '0') ?? 0;
      final totalRentPaid = double.tryParse(totals['total_rent_paid']?.toString() ?? '0') ?? 0;
      final outstandingBalance = double.tryParse(totals['outstanding_balance']?.toString() ?? '0') ?? 0;
      
      rows.add(DataTable(
        headingRowHeight: 0,
        columns: const [DataColumn(label: Text('')), DataColumn(label: Text(''))],
        rows: [
          DataRow(cells: [const DataCell(Text('TOTAL RENT DUE', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black))), DataCell(Text('£${totalRentDue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))]),
          DataRow(cells: [const DataCell(Text('TOTAL RENT PAID', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black))), DataCell(Text('£${totalRentPaid.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))]),
          DataRow(cells: [const DataCell(Text('OUTSTANDING BALANCE', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black))), DataCell(Text('£${outstandingBalance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))]),
        ],
      ));
    } else if (isInvoice && _previewData!['report_type'] != 'agency_property_statement') {
      rows.add(const Text('Financial Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5))));
      rows.add(const SizedBox(height: 8));
      
      final grossTotal = double.tryParse(totals['net_payout']?.toString() ?? '0') ?? 0;
      final netTotal = grossTotal / 1.2;
      final vat = grossTotal - netTotal;
      
      rows.add(DataTable(
        headingRowHeight: 0,
        columns: const [DataColumn(label: Text('')), DataColumn(label: Text(''))],
        rows: [
          DataRow(cells: [const DataCell(Text('Net Total', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black))), DataCell(Text('£${netTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))]),
          DataRow(cells: [const DataCell(Text('VAT (20%)', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black))), DataCell(Text('£${vat.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))]),
          DataRow(cells: [const DataCell(Text('Total Gross Amount', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black))), DataCell(Text('£${grossTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))]),
        ],
      ));
    }

    if (_previewData!['report_type'] == 'tenant_invoice') {
      if (_previewData!['rent_schedule'] != null && (_previewData!['rent_schedule'] as List).isNotEmpty) {
        rows.add(const SizedBox(height: 24));
        rows.add(const Text('Rent Schedule Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
        rows.add(const SizedBox(height: 8));
        rows.add(SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.resolveWith<Color>((states) {
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
              DataColumn(label: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Expected', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Paid', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: (_previewData!['rent_schedule'] as List).map<DataRow>((rs) {
              return DataRow(cells: [
                DataCell(Text(rs['due_date'].toString())),
                DataCell(Text('£${rs['expected_amount']}')),
                DataCell(Text('£${rs['paid_amount']}')),
                DataCell(Text(rs['status'].toString().toUpperCase())),
              ]);
            }).toList(),
          ),
        ));
      }
      
      if (_previewData!['transactions'] != null && (_previewData!['transactions'] as List).isNotEmpty) {
        rows.add(const SizedBox(height: 24));
        rows.add(const Text('Payments Received', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
        rows.add(const SizedBox(height: 8));
        rows.add(SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.resolveWith<Color>((states) {
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
              DataColumn(label: Text('Payment Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Reference', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: (_previewData!['transactions'] as List).map<DataRow>((tx) {
              return DataRow(cells: [
                DataCell(Text(tx['date'].toString())),
                DataCell(Text(tx['reference'].toString())),
                DataCell(Text('£${tx['amount']}')),
                DataCell(Text(tx['status'].toString().toUpperCase())),
              ]);
            }).toList(),
          ),
        ));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
    }

    if (_previewData!['details'] != null && (_previewData!['details'] as List).isNotEmpty) {
      rows.add(const SizedBox(height: 24));
      rows.add(const Text('Property Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
      rows.add(const SizedBox(height: 8));
      
      rows.add(SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.resolveWith<Color>((states) {
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
            DataColumn(label: Text('Property', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tenant', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Rent Recv', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Maintenance', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Agent Fee', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Landlord Payout', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: (_previewData!['details'] as List).map<DataRow>((d) {
            return DataRow(cells: [
              DataCell(Text(d['property_name'].toString())),
              DataCell(Text(d['tenant_name'].toString())),
              DataCell(Text('£${d['rent_payments_received']}')),
              DataCell(Text('£${d['maintenance_fees'] ?? 0}')),
              DataCell(Text('£${d['management_fee_amount'] ?? 0}')),
              DataCell(Text('£${d['landlord_payments_made']}')),
            ]);
          }).toList(),
        ),
      ));
    }
    
    if (_previewData!['properties_breakdown'] != null) {
      rows.add(const SizedBox(height: 24));
      rows.add(const Text('Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
      rows.add(const SizedBox(height: 8));
      
      rows.add(SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.resolveWith<Color>((states) {
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
            DataColumn(label: Text('Property', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Rent Collected', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Maintenance', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Agent Fees', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Net Payout', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: (_previewData!['properties_breakdown'] as List).map<DataRow>((p) {
            return DataRow(cells: [
              DataCell(Text(p['property_name'].toString())),
              DataCell(Text('£${p['rent_collected'] ?? 0}')),
              DataCell(Text('£${p['maintenance_fees']}')),
              DataCell(Text('£${p['agent_fees']}')),
              DataCell(Text('£${p['landlord_payment']}')),
            ]);
          }).toList(),
        ),
      ));
    }
    if (_previewData!['report_type'] == 'agency_property_statement') {
      if (_previewData!['ledger'] != null && (_previewData!['ledger'] as List).isNotEmpty) {
        rows.add(const SizedBox(height: 24));
        rows.add(const Text('Financial Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)));
        rows.add(const SizedBox(height: 16));
        
        List<DataRow> ledgerRows = [];
        for (var row in (_previewData!['ledger'] as List)) {
          final isPayout = row['description'].toString().contains('Landlord Payment');
          final creditStr = (row['credit'] as num) > 0 ? '£${(row['credit'] as num).toStringAsFixed(2)}' : '—';
          
          String expStr = '—';
          String payoutStr = '—';
          if ((row['charge'] as num) > 0) {
            if (isPayout) {
              payoutStr = '£${(row['charge'] as num).toStringAsFixed(2)}';
            } else {
              expStr = '£${(row['charge'] as num).toStringAsFixed(2)}';
            }
          }

          ledgerRows.add(DataRow(cells: [
            DataCell(Text(row['date'].toString(), style: const TextStyle(fontSize: 11, color: Colors.black87))),
            DataCell(Text(row['description'].toString(), style: const TextStyle(fontSize: 11, color: Colors.black87))),
            DataCell(Text(creditStr, style: TextStyle(fontSize: 11, color: creditStr == '—' ? Colors.grey : Colors.green.shade700))),
            DataCell(Text(expStr, style: TextStyle(fontSize: 11, color: expStr == '—' ? Colors.grey : Colors.red))),
            DataCell(Text(payoutStr, style: TextStyle(fontSize: 11, color: payoutStr == '—' ? Colors.grey : Colors.blue.shade700))),
          ]));
        }

        // Totals Row
        ledgerRows.add(DataRow(
          color: WidgetStateProperty.resolveWith<Color>((states) => Colors.transparent),
          cells: [
            const DataCell(Text('TOTALS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            const DataCell(Text('')),
            DataCell(Text('£${(_previewData!['total_rental_income'] ?? 0).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green.shade700))),
            DataCell(Text('£${(_previewData!['total_expenses'] ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red))),
            DataCell(Text('£${(_previewData!['net_landlord_payout'] ?? 0).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue.shade700))),
        ]));

        rows.add(SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            dataRowMinHeight: 35,
            dataRowMaxHeight: 40,
            columnSpacing: 35,
            dividerThickness: 0.5,
            headingRowColor: WidgetStateProperty.resolveWith<Color>((states) {
              return Colors.transparent;
            }),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: Colors.grey,
              letterSpacing: 1.0,
            ),
            columns: const [
              DataColumn(label: Text('DATE')),
              DataColumn(label: Text('DESCRIPTION')),
              DataColumn(label: Text('INCOME')),
              DataColumn(label: Text('EXPENSES')),
              DataColumn(label: Text('LANDLORD PAYOUT')),
            ],
            rows: ledgerRows,
          ),
        ));
      }
      
      // Footer
      rows.add(const SizedBox(height: 60));
      rows.add(
        Center(
          child: Column(
            children: [
              Text(
                'Confidential Document © ${DateTime.now().year} ${agency['name'] ?? 'Allen Goldstein'} Limited. All rights reserved.',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              const Text(
                'Registered in England & Wales. Authorized and Regulated by the Property Redress Scheme.',
                style: TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        )
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}





