import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';
import 'landlord_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLandlordLogin = false;

  void _login() async {
    setState(() => _isLoading = true);
    if (_isLandlordLogin) {
      // Magic Link Flow
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        await apiService.requestMagicLink(_emailController.text.trim());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('If registered, a magic link has been sent to your email.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: \$e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      // Standard Agent Login
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      setState(() => _isLoading = false);

      if (success) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed. Check credentials.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/allen_goldstein_logo.png', height: 100),
                const SizedBox(height: 16),
                ToggleButtons(
                  isSelected: [!_isLandlordLogin, _isLandlordLogin],
                  onPressed: (index) {
                    setState(() {
                      _isLandlordLogin = index == 1;
                    });
                  },
                  children: const [
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Agent Login")),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Landlord Login")),
                  ],
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                if (!_isLandlordLogin)
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    obscureText: true,
                  ),
                const SizedBox(height: 24),
                if (_isLoading) const CircularProgressIndicator()
                else ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: Text(_isLandlordLogin ? 'Send Magic Link' : 'Login'),
                ),
                if (!_isLandlordLogin)
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: const Text('New Agency? Register Here'),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

