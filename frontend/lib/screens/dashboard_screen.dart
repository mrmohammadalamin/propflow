import 'package:flutter/material.dart';
import '../widgets/main_app_bar.dart';
import 'package:provider/provider.dart';
import 'communication_centre_screen.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:file_selector/file_selector.dart';
import '../services/auth_provider.dart';
import 'package:agentic_ui/services/api_service.dart';
import 'package:agentic_ui/utils/formatters.dart';
import '../services/theme_provider.dart';
import 'a2ui_screen.dart';
import 'setup_wizard.dart';
import 'login_screen.dart';
import 'properties_screen.dart';
import 'tenants_screen.dart';
import 'landlords_screen.dart';
import 'user_management_screen.dart';
import 'service_provider_screen.dart';
import 'financial_reconciliation_screen.dart';
import 'landlord_payouts_screen.dart';
import 'advanced_report_screen.dart';
import 'payout_drill_down_screen.dart';
import 'global_settings_screen.dart';
import 'email_activity_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<Map<String, dynamic>> _emailsFuture;
  late Future<Map<String, dynamic>> _emailActivityFuture;
  bool _isSearchFocused = false;
  bool _isSearchHovered = false;
  bool _isRightColumnExpanded = true;
  
  // Collapsible AI Agent Command Center states
  bool _isAiAgentExpanded = false;
  bool _isAiAgentVisible = true;
  final TextEditingController _aiCommandController = TextEditingController();
  String _aiAgentResponse = 'Hello! I am your AI assistant. You can speak commands or upload invoices.';
  String _aiUiAction = 'none';
  bool _isAiLoading = false;
  
  // AI Add Property Form State
  final TextEditingController _aiPropertyAddressController = TextEditingController();
  final TextEditingController _aiPropertyCityController = TextEditingController();
  final TextEditingController _aiPropertyPostcodeController = TextEditingController();
  List<dynamic> _landlordsList = [];
  int? _selectedLandlordId;
  
  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  void _fetchLandlordsForAi() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final landlords = await api.fetchLandlords();
    setState(() {
      _landlordsList = landlords;
    });
  }

  void _openAiPanel() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _isAiAgentVisible = true;
      _isAiAgentExpanded = true;
      _aiUiAction = 'none';
      _aiAgentResponse = 'Welcome back ${auth.userName ?? "Agent"}! I am your AI assistant. I am listening... how can I help you today?';
    });
    _startListening();
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) => print('onStatus: $val'),
      onError: (val) => print('onError: $val'),
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) => setState(() {
          _aiCommandController.text = val.recognizedWords;
        }),
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _sendAiCommand() async {
    if (_aiCommandController.text.isEmpty) return;
    setState(() {
      _isAiLoading = true;
      _aiAgentResponse = 'Processing command...';
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.sendVoiceCommand(_aiCommandController.text);
      setState(() {
        _aiAgentResponse = 'Intent: ${result['parsed_action']['intent']}\nDetails: ${result['parsed_action']['entities']}\n\nAction: ${result['action_taken']}';
        _aiUiAction = result['ui_action'] ?? 'none';
        if (_aiUiAction == 'add_property') {
          _fetchLandlordsForAi();
        }
      });
      _aiCommandController.clear();
      _refreshStats();
    } catch (e) {
      setState(() {
        _aiAgentResponse = 'Error: $e';
      });
    } finally {
      setState(() {
        _isAiLoading = false;
      });
    }
  }

  Future<void> _uploadAiInvoice() async {
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _isAiLoading = true;
        _aiAgentResponse = 'Analyzing invoice with Gemini Vision...';
      });
      try {
        final api = Provider.of<ApiService>(context, listen: false);
        final response = await api.sendInvoiceImage(bytes, image.name);
        setState(() {
          _aiAgentResponse = 'Extracted Data:\n${response['extracted_data']}';
        });
        _refreshStats();
      } catch (e) {
        setState(() {
          _aiAgentResponse = 'Error: $e';
        });
      } finally {
        setState(() {
          _isAiLoading = false;
        });
      }
    }
  }

  Future<void> _uploadAiBankStatement() async {
    const XTypeGroup csvTypeGroup = XTypeGroup(
      label: 'CSV',
      extensions: <String>['csv'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[csvTypeGroup]);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _isAiLoading = true;
        _aiAgentResponse = 'Reconciling bank statement with Gemini...';
      });
      try {
        final api = Provider.of<ApiService>(context, listen: false);
        final response = await api.sendBankStatementCsv(bytes, file.name);
        setState(() {
          _aiAgentResponse = 'Reconciliation Report:\n\n${response['reconciliation_report']}';
        });
        _refreshStats();
      } catch (e) {
        setState(() {
          _aiAgentResponse = 'Error: $e';
        });
      } finally {
        setState(() {
          _isAiLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  void _openEmailActivity() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const EmailActivityScreen())).then((_) => _refreshStats());
  }

  void _refreshStats() {
    final api = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _statsFuture = api.fetchDashboardStats();
    _emailsFuture = api.fetchDashboardEmails();
      _emailActivityFuture = api.fetchEmailActivitySummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool canManageUsers = auth.role == 'administrator' || auth.role == 'admin';
    final bool canManageFinance = auth.role == 'administrator' || auth.role == 'accountant' || auth.role == 'admin';

    return Scaffold(
      appBar: MainAppBar(isRightColumnExpanded: _isRightColumnExpanded, onToggleLayout: () { setState(() { _isRightColumnExpanded = !_isRightColumnExpanded; }); }),
      body: Stack(
        children: [
          Column(
            children: [
              // Top Navigation Bar
              _buildTopNavigationBar(context, canManageUsers, canManageFinance),
              const Divider(height: 1),
              // Main Content
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _statsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading dashboard: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    }

                    final stats = snapshot.data!;
                    final dueProperties = stats['due_properties'] as List? ?? [];
                    
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        final borderColor = isDark 
                            ? Colors.white.withOpacity(0.08) 
                            : Colors.indigo.withOpacity(0.08);

                        if (constraints.maxWidth > 800) {
                          // Two Column Layout
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: _isRightColumnExpanded ? 3 : 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E1E2F).withOpacity(0.3) : Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: borderColor, width: 1.5),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: _buildLeftColumn(dueProperties),
                                    ),
                                  ),
                                ),
                                if (_isRightColumnExpanded) ...[
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E1E2F).withOpacity(0.3) : Colors.white,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(color: borderColor, width: 1.5),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: _buildRightColumn(stats),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        } else {
                          // Mobile Layout
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1E2F).withOpacity(0.3) : Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: borderColor, width: 1.5),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: _buildLeftColumn(dueProperties),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1E2F).withOpacity(0.3) : Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: borderColor, width: 1.5),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: _buildRightColumn(stats),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // Collapsible/Hideable Floating AI Agent Panel
          _buildFloatingAiAgentPanel(),
        ],
      ),
    );
  }

  // --- TOP NAVIGATION BAR & SEARCH ---
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
          const SizedBox(height: 12),
          // Smart Auto-suggest Search Bar
          Autocomplete<Map<String, dynamic>>(
            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<Map<String, dynamic>>.empty();
              }
              final api = Provider.of<ApiService>(context, listen: false);
              try {
                final results = await api.fetchProperties(search: textEditingValue.text);
                return results.cast<Map<String, dynamic>>();
              } catch (e) {
                return const Iterable<Map<String, dynamic>>.empty();
              }
            },
            displayStringForOption: (Map<String, dynamic> option) => formatPropertyAddress(option),
            onSelected: (Map<String, dynamic> selection) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => PropertiesScreen(initialSearchQuery: selection['address_line_1']?.toString()))).then((_) => _refreshStats());
            },
            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final showBorder = _isSearchHovered || _isSearchFocused;
              final bgColor = showBorder
                  ? (isDark ? const Color(0xFF2C2C2C) : Colors.white)
                  : (isDark ? Colors.grey.shade900 : Colors.grey.shade100);

              return Focus(
                onFocusChange: (hasFocus) {
                  setState(() {
                    _isSearchFocused = hasFocus;
                  });
                },
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isSearchHovered = true),
                  onExit: (_) => setState(() => _isSearchHovered = false),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor.withOpacity(0.60),
                      borderRadius: BorderRadius.circular(30),
                      border: showBorder
                          ? Border.all(color: Colors.blue.shade400, width: 1.5)
                          : Border.all(
                              color: isDark ? Colors.transparent : Colors.grey.shade300,
                              width: 1.5,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(showBorder ? 0.08 : 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'Search properties, landlords, or postcodes...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                          child: Icon(Icons.search, color: Colors.blue.shade400),
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (String value) {
                        onFieldSubmitted();
                        if (value.isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => PropertiesScreen(initialSearchQuery: value))).then((_) => _refreshStats());
                        }
                      },
                    ),
                  ),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Material(
                    elevation: 8.0,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 300,
                        maxWidth: MediaQuery.of(context).size.width > 800 ? MediaQuery.of(context).size.width - 32 : MediaQuery.of(context).size.width - 32,
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onSelected(option),
                              hoverColor: Colors.blue.withOpacity(0.05),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.home_work_outlined, color: Colors.blue, size: 22),
                                  ),
                                  title: Text(formatPropertyAddress(option), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  subtitle: Text(
                                    [option['city']?.toString(), option['postcode']?.toString()].where((s) => s != null && s.isNotEmpty).join(', '),
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
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
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination)).then((_) => _refreshStats());
        },
      ),
    );
  }

  // --- LEFT COLUMN: ALERT LISTS ---
  Widget _buildLeftColumn(List<dynamic> dueProperties) {
    final overdue = dueProperties.where((p) => p['status'] == 'overdue').toList();
    final upcomingAndToday = dueProperties.where((p) => p['status'] == 'due_today' || p['status'] == 'upcoming').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Attention Required', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (MediaQuery.of(context).size.width > 800)
              IconButton(
                icon: Icon(_isRightColumnExpanded ? Icons.arrow_circle_right_outlined : Icons.arrow_circle_left_outlined, size: 24),
                color: Theme.of(context).colorScheme.primary,
                tooltip: _isRightColumnExpanded ? 'Hide Right Summary' : 'Show Right Summary',
                onPressed: () {
                  setState(() {
                    _isRightColumnExpanded = !_isRightColumnExpanded;
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (overdue.isNotEmpty) ...[
          _buildAlertSection('Overdue Rent (Missed)', Icons.warning_amber_rounded, Colors.red, overdue),
          const SizedBox(height: 24),
        ],
        _buildAlertSection('Expected Rent', Icons.calendar_today, Colors.blue, upcomingAndToday),
      ],
    );
  }

  Widget _buildAlertSection(String title, IconData icon, Color color, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('All clear!', style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
          )
        else
          ...items.map((prop) {
            final landlord = prop['landlord'];
            final tenancies = prop['tenancies'] as List<dynamic>? ?? [];
            final activeTenancy = tenancies.where((t) => t['status'] == 'active').firstOrNull;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PropertiesScreen(
                        initialSearchQuery: prop['address_line_1'],
                        initialAction: 'details',
                      ),
                    ),
                  ).then((_) => _refreshStats());
                },
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
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
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
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (landlord['phone'] != null && landlord['phone'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0, left: 18.0),
                                      child: Text(
                                        landlord['phone'],
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          if (firstTenant['phone'] != null && firstTenant['phone'].toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2.0, left: 18.0),
                                              child: Text(
                                                firstTenant['phone'],
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              reverse: true,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 12),
                              if (activeTenancy != null)
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PropertiesScreen(
                                          initialSearchQuery: prop['address_line_1'],
                                          initialAction: 'lease_plan',
                                        ),
                                      ),
                                    ).then((_) => _refreshStats());
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.description_outlined, size: 14, color: Colors.blue),
                                        SizedBox(width: 4),
                                        Text('Rent Schedule', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PropertiesScreen(
                                        initialSearchQuery: prop['address_line_1'],
                                        initialAction: 'statements',
                                      ),
                                    ),
                                  ).then((_) => _refreshStats());
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.receipt_long, size: 14, color: Colors.blue),
                                      SizedBox(width: 4),
                                      Text('Statements', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (activeTenancy != null)
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PropertiesScreen(
                                          initialSearchQuery: prop['address_line_1'],
                                          initialAction: 'collect_rent',
                                        ),
                                      ),
                                    ).then((_) => _refreshStats());
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
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PropertiesScreen(
                                        initialSearchQuery: prop['address_line_1'],
                                        initialAction: 'maintenance',
                                      ),
                                    ),
                                  ).then((_) => _refreshStats());
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
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CommunicationCentreScreen(
                                        initialPropertyId: prop['id'],
                                      ),
                                    ),
                                  ).then((_) => _refreshStats());
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
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PropertiesScreen(
                                        initialSearchQuery: prop['address_line_1'],
                                        initialAction: 'details',
                                      ),
                                    ),
                                  ).then((_) => _refreshStats());
                                },
                                child: const Row(
                                  children: [
                                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blue),
                                    SizedBox(width: 4),
                                    Text('View More', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  // --- RIGHT COLUMN: SUMMARIES & ACTIONS ---
  Widget _buildRightColumn(Map<String, dynamic> stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Unified Overview Grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildSummaryCard('Properties', stats['total_properties'].toString(), Colors.blue.shade700, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PropertiesScreen())).then((_) => _refreshStats());
              }),
              _buildSummaryCard('Tenants', stats['total_tenants'].toString(), Colors.green.shade700, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TenantsScreen())).then((_) => _refreshStats());
              }),
              _buildSummaryCard('Landlords', stats['total_landlords'].toString(), Colors.orange.shade700, () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LandlordsScreen())).then((_) => _refreshStats());
              }),
              _buildSummaryCard('Expected Today', NumberFormat.currency(symbol: '£').format(stats['rent_expected_today'] ?? 0), Colors.teal.shade700, null),
              _buildSummaryCard('Overdue', NumberFormat.currency(symbol: '£').format(stats['rent_overdue'] ?? 0), Colors.red.shade700, null),
              _buildSummaryCard('Collected', NumberFormat.currency(symbol: '£').format(stats['rent_collected_total'] ?? 0), Colors.indigo.shade700, null),
              _buildSummaryCard('On Hold', NumberFormat.currency(symbol: '£').format(stats['payments_on_hold'] ?? 0), Colors.amber.shade700, null),
              _buildSummaryCard('Pending Payouts', NumberFormat.currency(symbol: '£').format(stats['pending_payouts'] ?? 0), Colors.purple.shade700, null),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Pending Distributions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: [
              _buildDrillDownCard('Agent Fee', stats['pending_agent_fees'], Colors.blue, 'agent_fee', 'pending', null),
              _buildDrillDownCard('Maintenance', stats['pending_maint_fees'], Colors.orange, 'service_provider', 'pending', null),
              _buildDrillDownCard('Landlord', stats['pending_landlord_fees'], Colors.green, 'landlord', 'pending', null),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Email Activity Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>>(
            future: _emailActivityFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
              if (snapshot.hasError) return Text('Error loading email stats', style: const TextStyle(color: Colors.red));
              final emailStats = snapshot.data ?? {};
              return GridView.count(
                crossAxisCount: 5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildSummaryCard('Sent', emailStats['total_sent_today']?.toString() ?? '0', Colors.blue, () => _openEmailActivity()),
                  _buildSummaryCard('Opened', emailStats['total_opened']?.toString() ?? '0', Colors.green, () => _openEmailActivity()),
                  _buildSummaryCard('Unopened', emailStats['total_unopened']?.toString() ?? '0', Colors.orange, () => _openEmailActivity()),
                  _buildSummaryCard('Reminders', emailStats['total_auto_reminders']?.toString() ?? '0', Colors.purple, () => _openEmailActivity()),
                  _buildSummaryCard('Failed', emailStats['total_failed']?.toString() ?? '0', Colors.red, () => _openEmailActivity()),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Today\'s Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: [
              _buildDrillDownCard('Agent Fees', stats['today_agent_fees'], Colors.blue, 'agent_fee', 'paid', 'today'),
              _buildDrillDownCard('Landlord Payouts', stats['today_landlord_fees'], Colors.green, 'landlord', 'paid', 'today'),
              _buildDrillDownCard('Maintenance', stats['today_maint_fees'], Colors.orange, 'service_provider', 'paid', 'today'),
            ],
          ),
          const SizedBox(height: 16),
          const Text('This Month', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: [
              _buildDrillDownCard('Agent Fees', stats['month_agent_fees'], Colors.blue, 'agent_fee', 'paid', 'this_month'),
              _buildDrillDownCard('Landlord Payouts', stats['month_landlord_fees'], Colors.green, 'landlord', 'paid', 'this_month'),
              _buildDrillDownCard('Maintenance', stats['month_maint_fees'], Colors.orange, 'service_provider', 'paid', 'this_month'),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Quick Actions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildActionTile('Generate Monthly Statement', Icons.receipt_long, Colors.indigo, const LandlordPayoutsScreen()),
          _buildActionTile('Customised Statement', Icons.tune, Colors.purple, const LandlordPayoutsScreen()),
          _buildActionTile('Daily Payments & Deductions', Icons.analytics, Colors.teal, const FinancialReconciliationScreen()),
            _buildActionTile('Communication Centre', Icons.email, Colors.blueGrey, const CommunicationCentreScreen()),
        ],
      ),
    );
  }

  Widget _buildDrillDownCard(String title, dynamic value, MaterialColor color, String paymentType, String status, String? timeframe) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PayoutDrillDownScreen(
              paymentType: paymentType,
              initialStatus: status,
              timeframe: timeframe,
            ),
          ),
        ).then((_) => _refreshStats());
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('£${double.parse((value ?? 0).toString()).toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }


  Widget _buildSummaryCard(String title, String value, Color color, VoidCallback? onTap) {
    Widget card = Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value, 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title, 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }
    return card;
  }

  Widget _buildMetricCard(String title, dynamic amount, Color color, IconData icon) {
    final currencyFormat = NumberFormat.currency(symbol: '£');
    final amountDouble = amount is int ? amount.toDouble() : (amount as double);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ],
          ),
          Text(
            currencyFormat.format(amountDouble),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon, Color color, Widget destination) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.2))),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => destination)).then((_) => _refreshStats());
        },
      ),
    );
  }



  Widget _buildFloatingAiAgentPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E2F).withOpacity(0.95) : Colors.white.withOpacity(0.95);
    final borderColor = isDark ? Colors.white.withOpacity(0.12) : Colors.purple.withOpacity(0.12);

    if (!_isAiAgentVisible) {
      // Hidden State: sleeker FloatingActionButton in bottom right corner
      return Positioned(
        bottom: 24,
        right: 24,
        child: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.purple.shade400,
          foregroundColor: Colors.white,
          onPressed: () {
            _openAiPanel();
          },
          tooltip: 'Show AI Command Center',
          child: const Icon(Icons.auto_awesome),
        ),
      );
    }

    if (!_isAiAgentExpanded) {
      // Collapsed State: sleek floating pill bar
      return Positioned(
        bottom: 24,
        right: 24,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purple, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI Command Center',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.expand_less, color: Colors.purple, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _isAiAgentExpanded = true;
                  });
                },
                tooltip: 'Expand',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 14),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _isAiAgentVisible = false;
                  });
                },
                tooltip: 'Hide',
              ),
            ],
          ),
        ),
      );
    }

    // Expanded State: high-fidelity, premium inline bottom card
    return Positioned(
      bottom: 24,
      right: 24,
      child: Container(
        width: 360,
        height: 480,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131320).withOpacity(0.96) : Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple.withOpacity(0.1),
                  radius: 14,
                  child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 14),
                ),
                const SizedBox(width: 10),
                const Text(
                  'AI Command Center',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.expand_more, color: Colors.grey, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _isAiAgentExpanded = false;
                    });
                  },
                  tooltip: 'Collapse',
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _isAiAgentVisible = false;
                    });
                  },
                  tooltip: 'Hide entirely',
                ),
              ],
            ),
            const Divider(height: 16),
            
            // Response Display
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                ),
                child: SingleChildScrollView(
                  child: _aiUiAction == 'add_property'
                      ? _buildInlineAddPropertyWizard()
                      : Text(
                          _aiAgentResponse,
                          style: const TextStyle(fontSize: 12.5, height: 1.45),
                        ),
                ),
              ),
            ),
            
            if (_isAiLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(color: Colors.purple),
              ),
            
            const SizedBox(height: 12),
            
            // Command input row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _aiCommandController,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Type or speak a command...',
                      hintStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.purple),
                      ),
                    ),
                    onSubmitted: (_) => _sendAiCommand(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.purple,
                  radius: 20,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 16),
                    onPressed: _sendAiCommand,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Multi-Agent tools
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (_isListening) {
                      _stopListening();
                    } else {
                      _startListening();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    backgroundColor: Colors.purple.withOpacity(0.08),
                    foregroundColor: Colors.purple,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.mic, size: 12),
                  label: const Text('Voice', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  onPressed: _uploadAiInvoice,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    backgroundColor: Colors.purple.withOpacity(0.08),
                    foregroundColor: Colors.purple,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.document_scanner, size: 12),
                  label: const Text('Scan Invoice', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  onPressed: _uploadAiBankStatement,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    backgroundColor: Colors.purple.withOpacity(0.08),
                    foregroundColor: Colors.purple,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.account_balance, size: 12),
                  label: const Text('Allocate CSV', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineAddPropertyWizard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🏠 Add New Property', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('Please provide the details below:', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Select Landlord', isDense: true),
            value: _selectedLandlordId,
            items: _landlordsList.map((ll) {
              return DropdownMenuItem<int>(
                value: ll['id'],
                child: Text('${ll['first_name']} ${ll['last_name']}'),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedLandlordId = val;
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _aiPropertyAddressController,
            decoration: const InputDecoration(labelText: 'Address Line 1', isDense: true),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _aiPropertyCityController,
            decoration: const InputDecoration(labelText: 'City', isDense: true),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _aiPropertyPostcodeController,
            decoration: const InputDecoration(labelText: 'Postcode', isDense: true),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _aiUiAction = 'none';
                    _aiAgentResponse = 'Property addition cancelled.';
                  });
                },
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_selectedLandlordId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a landlord')));
                    return;
                  }
                  if (_aiPropertyAddressController.text.isEmpty || _aiPropertyCityController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                    return;
                  }
                  
                  setState(() {
                    _isAiLoading = true;
                  });
                  try {
                    final api = Provider.of<ApiService>(context, listen: false);
                    await api.createBasicProperty(
                      _aiPropertyAddressController.text,
                      _aiPropertyCityController.text,
                      _aiPropertyPostcodeController.text,
                      _selectedLandlordId!,
                    );
                    
                    setState(() {
                      _aiUiAction = 'none';
                      _aiAgentResponse = 'Property successfully added! I have updated your dashboard.';
                      _aiPropertyAddressController.clear();
                      _aiPropertyCityController.clear();
                      _aiPropertyPostcodeController.clear();
                    });
                    _refreshStats();
                  } catch (e) {
                    setState(() {
                      _aiAgentResponse = 'Failed to create property: $e';
                    });
                  } finally {
                    setState(() {
                      _isAiLoading = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Save Property', style: TextStyle(fontSize: 12)),
              ),
            ],
          )
        ],
      ),
    );
  }
}


