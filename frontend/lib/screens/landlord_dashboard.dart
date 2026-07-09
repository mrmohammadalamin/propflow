import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class LandlordDashboard extends StatefulWidget {
  final ApiService apiService;
  
  const LandlordDashboard({Key? key, required this.apiService}) : super(key: key);

  @override
  _LandlordDashboardState createState() => _LandlordDashboardState();
}

class _LandlordDashboardState extends State<LandlordDashboard> {
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Audit log the login
    widget.apiService.logLandlordAudit('LOGIN', 'system', null, 'Landlord logged in to portal');
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen())
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      _PropertiesView(apiService: widget.apiService),
      _FinancialsView(apiService: widget.apiService),
      _CommunicationsView(apiService: widget.apiService),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Landlord Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          )
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Properties',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Financials',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Communications',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class _PropertiesView extends StatelessWidget {
  final ApiService apiService;
  const _PropertiesView({required this.apiService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: apiService.fetchLandlordProperties(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
           return Center(child: Text('Error: ${snapshot.error}'));
        }
        final properties = snapshot.data ?? [];
        if (properties.isEmpty) {
          return const Center(child: Text('No properties assigned to you.'));
        }
        
        return ListView.builder(
          itemCount: properties.length,
          itemBuilder: (context, index) {
            final p = properties[index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: const Icon(Icons.house, size: 40),
                title: Text('${p['address_line_1']}, ${p['city']}'),
                subtitle: Text('Status: ${p['status']} | Rent: £${p['rent_amount']} (${p['payment_frequency']})'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  apiService.logLandlordAudit('VIEW_PROPERTY', 'property', p['id'], 'Viewed property details');
                  // Expand or push property details
                },
              ),
            );
          }
        );
      }
    );
  }
}

class _FinancialsView extends StatelessWidget {
  final ApiService apiService;
  const _FinancialsView({required this.apiService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: apiService.fetchLandlordInvoices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
           return Center(child: Text('Error: ${snapshot.error}'));
        }
        final invoices = snapshot.data ?? [];
        if (invoices.isEmpty) {
          return const Center(child: Text('No financial records found.'));
        }
        
        return ListView.builder(
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            final inv = invoices[index];
            return ListTile(
              leading: Icon(inv['type'] == 'expense' ? Icons.money_off : Icons.attach_money),
              title: Text('${inv['type'].toUpperCase()} - £${inv['amount']}'),
              subtitle: Text(inv['description'] ?? 'No description'),
              trailing: Text(inv['status']),
              onTap: () {
                if (inv['document_url'] != null) {
                  apiService.logLandlordAudit('DOWNLOAD_INVOICE', 'invoice', inv['id'], 'Downloaded invoice document');
                  // Open document URL
                }
              },
            );
          }
        );
      }
    );
  }
}

class _CommunicationsView extends StatelessWidget {
  final ApiService apiService;
  const _CommunicationsView({required this.apiService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: apiService.fetchLandlordCommunications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
           return Center(child: Text('Error: ${snapshot.error}'));
        }
        final comms = snapshot.data ?? [];
        if (comms.isEmpty) {
          return const Center(child: Text('No communications found.'));
        }
        
        return ListView.builder(
          itemCount: comms.length,
          itemBuilder: (context, index) {
            final msg = comms[index];
            return ListTile(
              leading: const Icon(Icons.email),
              title: Text(msg['subject'] ?? 'No Subject'),
              subtitle: Text(msg['status']),
              onTap: () {
                apiService.logLandlordAudit('VIEW_COMMUNICATION', 'communication', msg['id'], 'Viewed communication message');
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(msg['subject'] ?? ''),
                    content: SingleChildScrollView(child: Text(msg['body_text'] ?? msg['body_html'] ?? '')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
                    ],
                  )
                );
              },
            );
          }
        );
      }
    );
  }
}
