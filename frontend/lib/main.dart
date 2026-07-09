import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/auth_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/landlord_dashboard.dart';
import 'services/theme_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ProxyProvider<AuthProvider, ApiService>(
          update: (_, auth, __) => ApiService(
            baseUrl: 'http://127.0.0.1:8000',
            agencyId: auth.agencyId ?? 1,
            token: auth.token,
          ),
        ),
      ],
      child: const AgenticApp(),
    ),
  );
}

class AgenticApp extends StatelessWidget {
  const AgenticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'A2UI Property Management',
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.light,
            ),
            fontFamily: 'Inter',
            cardTheme: CardTheme(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.indigo, width: 2.0),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2A2D34),
              brightness: Brightness.dark,
            ),
            fontFamily: 'Inter',
            cardTheme: CardTheme(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.green, width: 2.0),
              ),
            ),
          ),
          home: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return AppWrapper(auth: auth);
            },
          ),
        );
      },
    );
  }
}

class AppWrapper extends StatefulWidget {
  final AuthProvider auth;
  const AppWrapper({super.key, required this.auth});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _isCheckingMagicLink = true;

  @override
  void initState() {
    super.initState();
    _checkMagicLink();
  }

  Future<void> _checkMagicLink() async {
    // Check if running on web and has a token in URL
    String? token;
    try {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('token')) {
        token = uri.queryParameters['token'];
      }
    } catch (e) {
      // Ignored if Uri.base fails (non-web without proper handling)
    }

    if (token != null && !widget.auth.isAuthenticated) {
      final success = await widget.auth.loginWithMagicLink(token);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid or expired magic link.')),
          );
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _isCheckingMagicLink = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingMagicLink) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!widget.auth.isAuthenticated) {
      return const LoginScreen();
    }

    if (widget.auth.role == 'landlord') {
      final apiService = Provider.of<ApiService>(context, listen: false);
      return LandlordDashboard(apiService: apiService);
    }

    // Default to estate agent/admin dashboard
    return const DashboardScreen();
  }
}
