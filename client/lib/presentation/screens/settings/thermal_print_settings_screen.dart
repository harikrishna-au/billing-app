import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/thermal_print_settings_provider.dart';

class ThermalPrintSettingsScreen extends ConsumerWidget {
  const ThermalPrintSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(thermalPrintSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thermal Print Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'What to Print',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Invoice',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Full slip with GSTIN and tax breakup'),
            value: settings.printInvoice,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => ref
                .read(thermalPrintSettingsProvider.notifier)
                .updatePrintInvoice(v),
          ),
          SwitchListTile(
            title: const Text('Ticket',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Short slip without tax details'),
            value: settings.printTicket,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => ref
                .read(thermalPrintSettingsProvider.notifier)
                .updatePrintTicket(v),
          ),
          if (!settings.printInvoice && !settings.printTicket)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Both are off — nothing will print on checkout.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600),
              ),
            ),
          const Divider(height: 32),
          Text(
            'Adjust Font Sizes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          _SizeSlider(
            label: 'Title Size (INVOICE/TICKET)',
            value: settings.titleSize.toDouble(),
            onChanged: (value) => ref.read(thermalPrintSettingsProvider.notifier).updateTitleSize(value.toInt()),
          ),
          const SizedBox(height: 16),
          _SizeSlider(
            label: 'Organization Name Size',
            value: settings.orgNameSize.toDouble(),
            onChanged: (value) => ref.read(thermalPrintSettingsProvider.notifier).updateOrgNameSize(value.toInt()),
          ),
          const SizedBox(height: 16),
          _SizeSlider(
            label: 'Unit/Location Name Size',
            value: settings.unitNameSize.toDouble(),
            onChanged: (value) => ref.read(thermalPrintSettingsProvider.notifier).updateUnitNameSize(value.toInt()),
          ),
          const SizedBox(height: 16),
          _SizeSlider(
            label: 'Body Text Size',
            value: settings.bodySize.toDouble(),
            onChanged: (value) => ref.read(thermalPrintSettingsProvider.notifier).updateBodySize(value.toInt()),
          ),
          const SizedBox(height: 16),
          _SizeSlider(
            label: 'Header/Total Size',
            value: settings.headerSize.toDouble(),
            onChanged: (value) => ref.read(thermalPrintSettingsProvider.notifier).updateHeaderSize(value.toInt()),
          ),
          const SizedBox(height: 16),
          _SizeSlider(
            label: 'Metadata (Bill, Date, Time) Size',
            value: settings.metadataSize.toDouble(),
            onChanged: (value) => ref.read(thermalPrintSettingsProvider.notifier).updateMetadataSize(value.toInt()),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              ref.read(thermalPrintSettingsProvider.notifier).resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reset to default sizes')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Reset to Defaults'),
          ),
        ],
      ),
    );
  }
}

class _SizeSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _SizeSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${value.toInt()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: 16,
          max: 60,
          divisions: 44,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
