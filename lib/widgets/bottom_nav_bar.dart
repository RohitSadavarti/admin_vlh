import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      elevation: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            context,
            icon: Icons.notifications_active,
            label: 'Orders',
            index: 0,
            route: '/admin-orders',
          ),
          _buildNavItem(
            context,
            icon: Icons.bar_chart,
            label: 'Analytics',
            index: 1,
            route: '/admin-analytics',
          ),
          _buildNavItem(
            context,
            icon: Icons.dashboard,
            label: 'Dashboard',
            index: 2,
            route: '/admin-dashboard',
          ),
          _buildNavItem(
            context,
            icon: Icons.menu_book,
            label: 'Menu',
            index: 3,
            route: '/menu-management',
          ),
          _buildNavItem(
            context,
            icon: Icons.receipt_long,
            label: 'POS',
            index: 4,
            route: '/take-order',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
    required String route,
  }) {
    final isActive = currentIndex == index;
    final theme = Theme.of(context);

    return Expanded(
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (ModalRoute.of(context)?.settings.name != route) {
                Navigator.pushReplacementNamed(context, route);
              }
              onTap(index);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
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
