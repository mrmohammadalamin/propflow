import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class AdvancedPropertySetupScreen extends StatefulWidget {
  const AdvancedPropertySetupScreen({super.key});

  @override
  State<AdvancedPropertySetupScreen> createState() => _AdvancedPropertySetupScreenState();
}

class _AdvancedPropertySetupScreenState extends State<AdvancedPropertySetupScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Data
  List<dynamic> _landlords = [];
  List<dynamic> _tenants = [];
  List<dynamic> _users = [];
  
  // Property
  int? _selectedManagerId;
  final _roomNoController = TextEditingController();
  final _addr1Controller = TextEditingController();
  final _addr2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _countyController = TextEditingController();
  final _postController = TextEditingController();
  
  // Landlord
  int? _selectedLandlordId;
  final _llFirstController = TextEditingController();
  final _llLastController = TextEditingController();
  final _llCoController = TextEditingController();
  final _llAddr1Controller = TextEditingController();
  final _llAddr2Controller = TextEditingController();
  final _llCityController = TextEditingController();
  final _llCountyController = TextEditingController();
  final _llPostController = TextEditingController();
  final _llEmailController = TextEditingController();
  final _llPhoneController = TextEditingController();
  
  // Tenants (Multi-tenant support)
  List<int> _selectedTenantIds = [];
  List<Map<String, String>> _newTenants = [];
  
  // Tenancy
  final _rentController = TextEditingController();
  final _dueDayController = TextEditingController();
  final _depositController = TextEditingController(text: "0.00");
  final _managementFeeController = TextEditingController(text: '10.00');
  DateTime _startDate = DateTime.now();

  final _formKey = GlobalKey<FormState>();

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(value) ? null : 'Enter a valid email';
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return null;
    // UK Phone regex: 07 (mobile), 01/02 (landline)
    final regex = RegExp(r'^(((\+44\s?\d{4}|\(?0\d{4}\)?)\s?\d{3}\s?\d{3})|((\+44\s?\d{2}|\(?0\d{2}\)?)\s?\d{4}\s?\d{4}))$');
    return regex.hasMatch(value) ? null : 'Enter a valid UK phone number';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.green, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final ll = await api.fetchLandlords();
      final t = await api.fetchTenants();
      final u = await api.fetchUsers();
      setState(() {
        _landlords = ll;
        _tenants = t;
        _users = u;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fix validation errors')));
      return;
    }
    
    if (_newTenants.isEmpty && _selectedTenantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one tenant')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      
      final data = {
        "room_no": _roomNoController.text,
        "address_line_1": _addr1Controller.text,
        "address_line_2": _addr2Controller.text,
        "city": _cityController.text,
        "county": _countyController.text,
        "postcode": _postController.text,
        "landlord_id": _selectedLandlordId,
        "landlord_first_name": _selectedLandlordId == null ? _llFirstController.text : null,
        "landlord_last_name": _selectedLandlordId == null ? _llLastController.text : null,
        "landlord_co": _selectedLandlordId == null ? _llCoController.text : null,
        "landlord_address_line_1": _selectedLandlordId == null ? _llAddr1Controller.text : null,
        "landlord_address_line_2": _selectedLandlordId == null ? _llAddr2Controller.text : null,
        "landlord_city": _selectedLandlordId == null ? _llCityController.text : null,
        "landlord_county": _selectedLandlordId == null ? _llCountyController.text : null,
        "landlord_postcode": _selectedLandlordId == null ? _llPostController.text : null,
        "landlord_email": _selectedLandlordId == null ? _llEmailController.text : null,
        "landlord_phone": _selectedLandlordId == null ? _llPhoneController.text : null,
        "existing_tenant_ids": _selectedTenantIds,
        "new_tenants": _newTenants,
        "rent_amount": double.tryParse(_rentController.text) ?? 0,
        "management_fee_percentage": double.tryParse(_managementFeeController.text) ?? 10.00,
        "due_day": int.tryParse(_dueDayController.text) ?? 1,
        "start_date": DateFormat('yyyy-MM-dd').format(_startDate),
        "assigned_manager_id": _selectedManagerId
      };
      
      await api.advancedSetup(data);
      if (mounted) {
        Navigator.pop(context, true); // Return true to signal success
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 3 && !_isLoading, // simplified condition
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool shouldPop = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Setup?'),
            content: const Text('The property setup process is not complete. Are you sure you want to cancel? Any unsaved information may be lost.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No, continue setup')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes, cancel')),
            ],
          ),
        ) ?? false;
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(title: const Text('Advanced Property Setup')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 2) {
                  if (_selectedTenantIds.isEmpty && _newTenants.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please add a tenant before proceeding to the Plan section.'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                }
                if (_currentStep == 0) {
                  // Property Step
                  if (_addr1Controller.text.isEmpty || _postController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address and Postcode required')));
                    return;
                  }
                }
                if (_currentStep == 1 && _selectedLandlordId == null) {
                  // Landlord Creation Step (if creating new)
                  if (_llFirstController.text.isNotEmpty && _llLastController.text.isEmpty) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Landlord Last Name required')));
                     return;
                  }
                }
                
                if (_currentStep < 3) {
                  setState(() => _currentStep += 1);
                } else {
                  _submit();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep -= 1);
                }
              },
              steps: [
                Step(
                  title: const Text('Property'),
                  isActive: _currentStep >= 0,
                  content: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _selectedManagerId,
                        decoration: const InputDecoration(labelText: 'Assigned Manager (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.assignment_ind)),
                        items: _users.map((u) {
                          return DropdownMenuItem<int>(
                            value: u['id'],
                            child: Text('${u['name']} (${u['role'].toString().replaceAll('_', ' ')})'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedManagerId = val),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(controller: _roomNoController, decoration: const InputDecoration(labelText: 'Room or Flat NO', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addr1Controller, 
                        decoration: const InputDecoration(labelText: 'Address Line 1', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _addr2Controller, decoration: const InputDecoration(labelText: 'Address 2', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cityController, 
                        decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _countyController, decoration: const InputDecoration(labelText: 'County', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _postController, 
                        decoration: const InputDecoration(labelText: 'Post Code', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Landlord'),
                  isActive: _currentStep >= 1,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Existing Landlord (Searchable):'),
                      const SizedBox(height: 8),
                      Autocomplete<Object>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<Object>.empty();
                          }
                          final Iterable<dynamic> options = _landlords.where((dynamic option) {
                            final fullName = '${option['first_name']} ${option['last_name']}'.toLowerCase();
                            return fullName.contains(textEditingValue.text.toLowerCase());
                          });
                          return options.cast<Object>();
                        },
                        displayStringForOption: (Object option) {
                          final map = option as Map<String, dynamic>;
                          return '${map['first_name']} ${map['last_name']}';
                        },
                        onSelected: (Object selection) {
                          final map = selection as Map<String, dynamic>;
                          setState(() => _selectedLandlordId = map['id']);
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Search Landlord...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                          );
                        },
                      ),
                      if (_selectedLandlordId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 4),
                              Text('Selected ID: $_selectedLandlordId'),
                              const Spacer(),
                              TextButton(onPressed: () => setState(() => _selectedLandlordId = null), child: const Text('Clear'))
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (_selectedLandlordId == null) ...[
                        const Divider(height: 32),
                        const Text('Or Create New Landlord:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        TextFormField(controller: _llCoController, decoration: const InputDecoration(labelText: 'c/o', border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: TextFormField(
                              controller: _llFirstController, 
                              decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                              validator: (v) => (_selectedLandlordId == null && _llLastController.text.isNotEmpty && v!.isEmpty) ? 'Required' : null,
                            )),
                            const SizedBox(width: 16),
                            Expanded(child: TextFormField(
                              controller: _llLastController, 
                              decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                              validator: (v) => (_selectedLandlordId == null && _llFirstController.text.isNotEmpty && v!.isEmpty) ? 'Required' : null,
                            )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(controller: _llAddr1Controller, decoration: const InputDecoration(labelText: 'Address 1', border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        TextFormField(controller: _llAddr2Controller, decoration: const InputDecoration(labelText: 'Address 2', border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: TextFormField(controller: _llCityController, decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()))),
                            const SizedBox(width: 16),
                            Expanded(child: TextFormField(controller: _llCountyController, decoration: const InputDecoration(labelText: 'County', border: OutlineInputBorder()))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(controller: _llPostController, decoration: const InputDecoration(labelText: 'Post Code', border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _llPhoneController, 
                          decoration: const InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder()),
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _llEmailController, 
                          decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                          validator: _validateEmail,
                        ),
                      ]
                    ],
                  ),
                ),
                Step(
                  title: const Text('Tenants'),
                  isActive: _currentStep >= 2,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Add Tenants to this Property:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      if (_newTenants.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text('No tenants added yet. Use the button below to add the first tenant.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                      ..._newTenants.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final nt = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.blue.shade100, child: Text('${idx + 1}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                            title: Text('${nt['first_name']} ${nt['last_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(nt['email'] ?? 'No email provided'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => setState(() => _newTenants.removeAt(idx)),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.person_add_alt_1),
                          label: Text(_newTenants.isEmpty ? 'Add Tenant' : 'Add Additional Tenant (Joint Tenancy)'),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue),
                          onPressed: () {
                            final fCtrl = TextEditingController();
                            final lCtrl = TextEditingController();
                            final a1Ctrl = TextEditingController();
                            final a2Ctrl = TextEditingController();
                            final cCtrl = TextEditingController();
                            final coCtrl = TextEditingController();
                            final pCtrl = TextEditingController();
                            final phCtrl = TextEditingController();
                            final eCtrl = TextEditingController();
                            
                            final _dialogFormKey = GlobalKey<FormState>();
                            
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('New Tenant Details'),
                                content: SingleChildScrollView(
                                  child: Form(
                                    key: _dialogFormKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: TextFormField(
                                              controller: fCtrl, 
                                              decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                                              validator: (v) => v!.isEmpty ? 'Required' : null,
                                            )),
                                            const SizedBox(width: 16),
                                            Expanded(child: TextFormField(
                                              controller: lCtrl, 
                                              decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                                              validator: (v) => v!.isEmpty ? 'Required' : null,
                                            )),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(controller: a1Ctrl, decoration: const InputDecoration(labelText: 'Address 1', border: OutlineInputBorder())),
                                        const SizedBox(height: 16),
                                        TextFormField(controller: a2Ctrl, decoration: const InputDecoration(labelText: 'Address 2', border: OutlineInputBorder())),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(child: TextFormField(controller: cCtrl, decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()))),
                                            const SizedBox(width: 16),
                                            Expanded(child: TextFormField(controller: coCtrl, decoration: const InputDecoration(labelText: 'County', border: OutlineInputBorder()))),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(controller: pCtrl, decoration: const InputDecoration(labelText: 'Post Code', border: OutlineInputBorder())),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: phCtrl, 
                                          decoration: const InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder()),
                                          validator: _validatePhone,
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: eCtrl, 
                                          decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                                          validator: _validateEmail,
                                        ),
                                        const SizedBox(height: 24),
                                        const Text('Note: Proof of ID can be uploaded in the Tenant Profile screen after creation.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (_dialogFormKey.currentState!.validate()) {
                                        setState(() {
                                          _newTenants.add({
                                            'first_name': fCtrl.text, 
                                            'last_name': lCtrl.text,
                                            'address_line_1': a1Ctrl.text,
                                            'address_line_2': a2Ctrl.text,
                                            'city': cCtrl.text,
                                            'county': coCtrl.text,
                                            'postcode': pCtrl.text,
                                            'phone': phCtrl.text,
                                            'email': eCtrl.text,
                                          });
                                        });
                                        Navigator.pop(ctx);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                                    child: const Text('Add Tenant'),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
                Step(
                  title: const Text('Plan'),
                  isActive: _currentStep >= 3,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tenancy Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tenancy Start Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(_startDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _rentController, 
                        decoration: const InputDecoration(labelText: 'Monthly Rent (£)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _depositController,
                        decoration: const InputDecoration(labelText: 'Tenant Deposit Amount (£)', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _managementFeeController, 
                        decoration: const InputDecoration(labelText: 'Management Fees (%)', border: OutlineInputBorder()), 
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dueDayController, 
                        decoration: const InputDecoration(labelText: 'Due Day (1-28)', border: OutlineInputBorder()), 
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v!.isEmpty) return 'Required';
                          final day = int.tryParse(v);
                          if (day == null || day < 1 || day > 28) return 'Enter 1-28';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
