import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_config_provider.dart';
import '../../providers/catalogue_provider.dart';
import '../../providers/service_provider.dart';
import 'settings_tiles.dart';
import 'settings_sheets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isReloading = false;

  Future<void> _reloadAll() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _isReloading = true);
    try {
      await Future.wait([
        ref.read(billConfigProvider.notifier).refresh(user.id),
        ref.read(catalogueProvider.notifier).fetchItems(),
        ref.read(serviceProvider.notifier).loadAllServices(),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('App data refreshed',
                style: GoogleFonts.dmSans(color: Colors.white)),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Some data failed to refresh',
                style: GoogleFonts.dmSans(color: Colors.white)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null) ...[
              SettingsUserCard(username: user.username),
              const SizedBox(height: 28),
            ],
            const SettingsSectionLabel('Business'),
            const SizedBox(height: 10),
            SettingsNavTile(
              icon: Icons.bar_chart_rounded,
              iconBg: const Color(0xFFD1FAE5),
              iconColor: AppColors.success,
              title: 'Day Summary',
              subtitle: 'View and print daily sales report',
              onTap: () => context.push('/settings/day-summary'),
            ),
            const SizedBox(height: 8),
            SettingsNavTile(
              icon: Icons.print_rounded,
              iconBg: const Color(0xFFE0E7FF),
              iconColor: const Color(0xFF4F46E5),
              title: 'Attached printer',
              subtitle: 'Use the built-in SmartPOS printer',
              onTap: () => context.push('/settings/printer'),
            ),
            const SizedBox(height: 28),
            const SettingsSectionLabel('Data'),
            const SizedBox(height: 10),
            SettingsReloadTile(
              isReloading: _isReloading,
              onTap: _isReloading ? null : _reloadAll,
            ),
            const SizedBox(height: 28),
            const SettingsSectionLabel('Account'),
            const SizedBox(height: 10),
            SettingsNavTile(
              icon: Icons.person_outline_rounded,
              iconBg: AppColors.primaryLight,
              iconColor: AppColors.primary,
              title: 'Profile',
              subtitle: 'Manage your account details',
              onTap: () => showSettingsProfileSheet(
                context,
                username: user?.username ?? '—',
                machineId: user?.id ?? '—',
              ),
            ),
            const SizedBox(height: 8),
            SettingsNavTile(
              icon: Icons.notifications_outlined,
              iconBg: const Color(0xFFFEF3C7),
              iconColor: AppColors.warning,
              title: 'Notifications',
              subtitle: 'Configure alerts and sounds',
              onTap: () => showSettingsNotificationsSheet(context),
            ),
            const SizedBox(height: 28),
            const SettingsSectionLabel('About'),
            const SizedBox(height: 10),
            SettingsNavTile(
              icon: Icons.info_outline_rounded,
              iconBg: const Color(0xFFF0FFFE),
              iconColor: const Color(0xFF0D9488),
              title: 'App Info',
              subtitle: 'Version 1.0.0',
              onTap: () {},
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: Text('Sign out?',
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700, fontSize: 17)),
                      content: Text('You will need to sign in again.',
                          style: GoogleFonts.dmSans(
                              color: AppColors.textSecondary, fontSize: 14)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel',
                              style: GoogleFonts.dmSans(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Sign out',
                              style: GoogleFonts.dmSans(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    ref.read(authProvider.notifier).logout();
                  }
                },
                icon: const Icon(Icons.logout_rounded,
                    color: AppColors.error, size: 20),
                label: Text(
                  'Sign Out',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
