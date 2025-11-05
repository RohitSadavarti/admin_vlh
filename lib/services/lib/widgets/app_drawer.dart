// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  // Helper to navigate
  void _navigateTo(BuildContext context, String routeName) {
    Navigator.pop(context); // Close drawer
    if (ModalRoute.of(context)?.settings.name != routeName) {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Text(
              'Vanita Lunch Home',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          
          // --- NEW ADMIN LINKS ---
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => _navigateTo(context, '/admin-dashboard'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Order Management'),
            onTap: () => _navigateTo(context, '/admin-orders'),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Analytics'),
            onTap: () => _navigateTo(context, '/admin-analytics'),
          ),
          // ListTile(
          //   leading: const Icon(Icons.menu_book),
          //   title: const Text('Menu Management'),
          //   onTap: () => _navigateTo(context, '/admin-menu'),
          // ),
          
          const Divider(),

          // --- POS LINK ---
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Point of Sale', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Take Order'),
            onTap: () => _navigateTo(context, '/take-order'),
          ),

          const Divider(),

          // --- LOGOUT ---
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}