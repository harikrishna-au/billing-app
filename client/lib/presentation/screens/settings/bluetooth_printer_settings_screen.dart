import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme/app_colors.dart';
import '../../../services/smart_pos_printer_service.dart';

class AttachedPrinterSettingsScreen extends StatefulWidget {
  const AttachedPrinterSettingsScreen({super.key});

  @override
  State<AttachedPrinterSettingsScreen> createState() =>
      _AttachedPrinterSettingsScreenState();
}

class _AttachedPrinterSettingsScreenState
    extends State<AttachedPrinterSettingsScreen> {
  bool _busy = false;

  Future<void> _testPrint() async {
    setState(() => _busy = true);
    try {
      final printer = SmartPosPrinterService();
      await printer.initSdk();
      await printer.printText(
        text: 'Attached printer test OK',
        size: 20,
        isBold: true,
        align: 1,
      );
      await printer.cutPaper();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Test sent to attached printer',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Attached printer',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'This machine uses the built-in attached printer. No Bluetooth pairing is required.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Printer mode',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Native SmartPOS attached printer',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The app sends print jobs directly to the device printer bridge.',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _testPrint,
            icon: const Icon(Icons.print_rounded, size: 18),
            label: Text(
              'Test attached printer',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use this screen to confirm the embedded printer is responding. Orders will print through the same native bridge.',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
