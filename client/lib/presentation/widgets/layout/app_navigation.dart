import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// import 'package:google_fonts/google_fonts.dart';
import '../../../config/theme/app_colors.dart';

class AppBottomNavigation extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppBottomNavigation({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.primary.withOpacity(0.1),
          height: 70,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          elevation: 0,
          destinations: [
            _buildDestination(
              icon: Icons.add_shopping_cart_outlined,
              selectedIcon: Icons.add_shopping_cart_rounded,
              label: 'New Order',
            ),
            _buildDestination(
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long_rounded,
              label: 'Orders',
            ),
            _buildDestination(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  NavigationDestination _buildDestination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    return NavigationDestination(
      icon: Icon(icon, color: AppColors.textSecondary),
      selectedIcon: Icon(selectedIcon, color: AppColors.primary),
      label: label,
    );
  }
}
