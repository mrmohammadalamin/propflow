import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../screens/properties_screen.dart';
import '../screens/landlord_payouts_screen.dart';
import '../screens/advanced_report_screen.dart';
import '../screens/landlords_screen.dart';
import '../screens/tenants_screen.dart';
import '../screens/service_provider_screen.dart';
import '../screens/user_management_screen.dart';

class TopNavigationPills extends StatelessWidget {
  const TopNavigationPills({Key? key}) : super(key: key);

  Widget _navButton(BuildContext context, String title, IconData icon, Color color, Widget destination) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => destination));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bool canManageUsers = auth.role == 'administrator' || auth.role == 'admin';
    final bool canManageFinance = auth.role == 'administrator' || auth.role == 'accountant' || auth.role == 'admin';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Theme.of(context).cardColor,
      child: SizedBox(
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
    );
  }
}