import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart'; // adjust path if needed

class VatSettingsScreen extends StatefulWidget {
  const VatSettingsScreen({super.key});

  @override
  State<VatSettingsScreen> createState() => _VatSettingsScreenState();
}

class _VatSettingsScreenState extends State<VatSettingsScreen> {
  bool _isLoading = true;
  bool _vatEnabled = false;
  double _defaultVatRate = 20.0;
  bool _vatRegistered = false;
  final TextEditingController _vatNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.getAgencyProfile();

      setState(() {
        _vatEnabled = data['vat_enabled'] ?? false;
        _defaultVatRate = (data['default_vat_rate'] ?? 20.0).toDouble();
        _vatRegistered = data['vat_registered'] ?? false;
        _vatNumberController.text = data['vat_registration_number'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load settings')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      
      // We need to fetch the existing data first to preserve it since it's a PUT
      final getResponse = await api.getAgencyProfile();
      
      await api.updateAgencyVatSettings(
        agencyName: getResponse['name'] ?? 'My Agency',
        vatEnabled: _vatEnabled,
        defaultVatRate: _defaultVatRate,
        vatRegistered: _vatRegistered,
        vatRegistrationNumber: _vatNumberController.text,
      );

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('VAT settings updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax & VAT Settings'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                SwitchListTile(
                  title: const Text('Enable VAT in System'),
                  subtitle: const Text('Allow VAT calculations on maintenance and management fees.'),
                  value: _vatEnabled,
                  onChanged: (val) => setState(() => _vatEnabled = val),
                  activeColor: Colors.indigo.shade900,
                ),
                if (_vatEnabled) ...[
                  const Divider(),
                  ListTile(
                    title: const Text('Default VAT Rate (%)'),
                    subtitle: Text('Current Rate: $_defaultVatRate%'),
                    trailing: SizedBox(
                      width: 100,
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          if (double.tryParse(val) != null) {
                            _defaultVatRate = double.parse(val);
                          }
                        },
                        controller: TextEditingController(text: _defaultVatRate.toString())
                          ..selection = TextSelection.collapsed(offset: _defaultVatRate.toString().length),
                      ),
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Agency VAT Registered'),
                    subtitle: const Text('If yes, VAT will be applied to your management fees.'),
                    value: _vatRegistered,
                    onChanged: (val) => setState(() => _vatRegistered = val),
                    activeColor: Colors.indigo.shade900,
                  ),
                  if (_vatRegistered)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: TextField(
                        controller: _vatNumberController,
                        decoration: const InputDecoration(
                          labelText: 'VAT Registration Number',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. GB123456789',
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.indigo.shade900,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Settings', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
    );
  }
}
