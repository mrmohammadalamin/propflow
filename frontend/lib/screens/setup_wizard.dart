import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/auth_provider.dart';

class SetupWizard extends StatefulWidget {
  const SetupWizard({super.key});

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Landlord Data
  final _llFirstName = TextEditingController();
  final _llLastName = TextEditingController();
  int? _createdLandlordId;

  // Property Data
  final _propAddress = TextEditingController();
  final _propCity = TextEditingController();
  final _propPostcode = TextEditingController();
  int? _createdPropertyId;

  // Tenant Data
  final _tntFirstName = TextEditingController();
  final _tntLastName = TextEditingController();
  int? _createdTenantId;

  // Tenancy Data
  final _rentAmount = TextEditingController();
  final _dueDay = TextEditingController(text: "1");
  final _depositController = TextEditingController(text: "0.00");
  final _managementFee = TextEditingController(text: "10.00");
  final _startDate = TextEditingController(text: "2024-01-01");

  Future<int?> _postData(String endpoint, Map<String, dynamic> body) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final response = await http.post(
        Uri.parse('${auth.baseUrl}/$endpoint/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}'
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['id'];
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }

  Future<void> _submitStep() async {
    setState(() => _isLoading = true);
    bool success = false;

    if (_currentStep == 0) {
      _createdLandlordId = await _postData('landlords', {
        'first_name': _llFirstName.text,
        'last_name': _llLastName.text,
      });
      success = _createdLandlordId != null;
    } else if (_currentStep == 1) {
      _createdPropertyId = await _postData('properties', {
        'address_line_1': _propAddress.text,
        'city': _propCity.text,
        'postcode': _propPostcode.text,
        'landlord_id': _createdLandlordId,
      });
      success = _createdPropertyId != null;
    } else if (_currentStep == 2) {
      _createdTenantId = await _postData('tenants', {
        'first_name': _tntFirstName.text,
        'last_name': _tntLastName.text,
      });
      success = _createdTenantId != null;
    } else if (_currentStep == 3) {
      final tid = await _postData('tenancies', {
        'property_id': _createdPropertyId,
        'rent_amount': double.parse(_rentAmount.text),
        'deposit_amount': double.tryParse(_depositController.text) ?? 0.0,
        'management_fee_percentage': double.parse(_managementFee.text),
        'due_day': int.parse(_dueDay.text),
        'start_date': _startDate.text,
      });
      success = tid != null;
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setup Complete!')));
        Navigator.pop(context);
      }
    }

    setState(() => _isLoading = false);

    if (success && _currentStep < 3) {
      setState(() => _currentStep += 1);
    } else if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save data.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 3 && !_isLoading,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool shouldPop = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Setup?'),
            content: const Text('The property setup process is not complete. Are you sure you want to cancel? Any unsaved information may be lost.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
            ],
          ),
        ) ?? false;
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(title: const Text('Manual Setup Wizard')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stepper(
            currentStep: _currentStep,
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_currentStep == 3 ? 'Finish' : 'Continue'),
                      ),
                      const SizedBox(width: 12),
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                    ],
                  ),
                );
              },
            onStepContinue: _submitStep,
            onStepCancel: () {
              if (_currentStep > 0) setState(() => _currentStep -= 1);
            },
            steps: [
              Step(
                title: const Text('Add Landlord'),
                isActive: _currentStep >= 0,
                content: Column(
                  children: [
                    TextField(controller: _llFirstName, decoration: const InputDecoration(labelText: 'First Name')),
                    TextField(controller: _llLastName, decoration: const InputDecoration(labelText: 'Last Name')),
                  ],
                ),
              ),
              Step(
                title: const Text('Add Property'),
                isActive: _currentStep >= 1,
                content: Column(
                  children: [
                    TextField(controller: _propAddress, decoration: const InputDecoration(labelText: 'Address')),
                    TextField(controller: _propCity, decoration: const InputDecoration(labelText: 'City')),
                    TextField(controller: _propPostcode, decoration: const InputDecoration(labelText: 'Postcode')),
                  ],
                ),
              ),
              Step(
                title: const Text('Add Tenant'),
                isActive: _currentStep >= 2,
                content: Column(
                  children: [
                    TextField(controller: _tntFirstName, decoration: const InputDecoration(labelText: 'First Name')),
                    TextField(controller: _tntLastName, decoration: const InputDecoration(labelText: 'Last Name')),
                  ],
                ),
              ),
              Step(
                title: const Text('Create Tenancy'),
                isActive: _currentStep >= 3,
                content: Column(
                  children: [
                    TextField(controller: _depositController, decoration: const InputDecoration(labelText: 'Tenant Deposit Amount (£)'), keyboardType: TextInputType.number),
                    TextField(controller: _rentAmount, decoration: const InputDecoration(labelText: 'Rent Amount (£)'), keyboardType: TextInputType.number),
                    TextField(controller: _managementFee, decoration: const InputDecoration(labelText: 'Management Fees (%)'), keyboardType: TextInputType.number),
                    TextField(controller: _dueDay, decoration: const InputDecoration(labelText: 'Due Day (1-28)'), keyboardType: TextInputType.number),
                    TextField(controller: _startDate, decoration: const InputDecoration(labelText: 'Start Date (YYYY-MM-DD)')),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
  }
}
