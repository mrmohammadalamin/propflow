import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import 'dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _agencyNameController = TextEditingController();
  final _subdomainController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _isLoading = false;

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.register(
      _agencyNameController.text.trim(),
      _subdomainController.text.trim(),
      _adminNameController.text.trim(),
      _adminEmailController.text.trim(),
      _adminPasswordController.text.trim(),
    );
    
    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      // Navigate to dashboard and clear stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed. Subdomain or Email might be taken.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Agency')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Company Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _agencyNameController,
                    decoration: const InputDecoration(labelText: 'Agency Name', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _subdomainController,
                    decoration: const InputDecoration(labelText: 'Subdomain (e.g. citylettings)', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 32),
                  const Text('Admin Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _adminNameController,
                    decoration: const InputDecoration(labelText: 'Admin Name', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _adminEmailController,
                    decoration: const InputDecoration(labelText: 'Admin Email', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _adminPasswordController,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    obscureText: true,
                    validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
                  ),
                  const SizedBox(height: 32),
                  if (_isLoading) const Center(child: CircularProgressIndicator())
                  else ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Create Agency & Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
