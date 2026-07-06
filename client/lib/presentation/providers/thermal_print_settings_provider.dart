import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThermalPrintSettings {
  final int titleSize;
  final int orgNameSize;
  final int unitNameSize;
  final int bodySize;
  final int headerSize;
  final int metadataSize;

  /// Which slips print on checkout. Both default ON; turning one off
  /// skips that slip entirely.
  final bool printInvoice;
  final bool printTicket;

  ThermalPrintSettings({
    this.titleSize = 24,
    this.orgNameSize = 20,
    this.unitNameSize = 20,
    this.bodySize = 20,
    this.headerSize = 24,
    this.metadataSize = 20,
    this.printInvoice = true,
    this.printTicket = true,
  });

  ThermalPrintSettings copyWith({
    int? titleSize,
    int? orgNameSize,
    int? unitNameSize,
    int? bodySize,
    int? headerSize,
    int? metadataSize,
    bool? printInvoice,
    bool? printTicket,
  }) {
    return ThermalPrintSettings(
      titleSize: titleSize ?? this.titleSize,
      orgNameSize: orgNameSize ?? this.orgNameSize,
      unitNameSize: unitNameSize ?? this.unitNameSize,
      bodySize: bodySize ?? this.bodySize,
      headerSize: headerSize ?? this.headerSize,
      metadataSize: metadataSize ?? this.metadataSize,
      printInvoice: printInvoice ?? this.printInvoice,
      printTicket: printTicket ?? this.printTicket,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('thermal_title_size', titleSize);
    await prefs.setInt('thermal_org_size', orgNameSize);
    await prefs.setInt('thermal_unit_size', unitNameSize);
    await prefs.setInt('thermal_body_size', bodySize);
    await prefs.setInt('thermal_header_size', headerSize);
    await prefs.setInt('thermal_metadata_size', metadataSize);
    await prefs.setBool('thermal_print_invoice', printInvoice);
    await prefs.setBool('thermal_print_ticket', printTicket);
  }

  static Future<ThermalPrintSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ThermalPrintSettings(
      titleSize: prefs.getInt('thermal_title_size') ?? 24,
      orgNameSize: prefs.getInt('thermal_org_size') ?? 20,
      unitNameSize: prefs.getInt('thermal_unit_size') ?? 20,
      bodySize: prefs.getInt('thermal_body_size') ?? 20,
      headerSize: prefs.getInt('thermal_header_size') ?? 24,
      metadataSize: prefs.getInt('thermal_metadata_size') ?? 20,
      printInvoice: prefs.getBool('thermal_print_invoice') ?? true,
      printTicket: prefs.getBool('thermal_print_ticket') ?? true,
    );
  }
}

final thermalPrintSettingsProvider = StateNotifierProvider<ThermalPrintSettingsNotifier, ThermalPrintSettings>((ref) {
  return ThermalPrintSettingsNotifier();
});

class ThermalPrintSettingsNotifier extends StateNotifier<ThermalPrintSettings> {
  ThermalPrintSettingsNotifier() : super(ThermalPrintSettings()) {
    _init();
  }

  Future<void> _init() async {
    state = await ThermalPrintSettings.load();
  }

  Future<void> updateTitleSize(int size) async {
    state = state.copyWith(titleSize: size);
    await state.save();
  }

  Future<void> updateOrgNameSize(int size) async {
    state = state.copyWith(orgNameSize: size);
    await state.save();
  }

  Future<void> updateUnitNameSize(int size) async {
    state = state.copyWith(unitNameSize: size);
    await state.save();
  }

  Future<void> updateBodySize(int size) async {
    state = state.copyWith(bodySize: size);
    await state.save();
  }

  Future<void> updateHeaderSize(int size) async {
    state = state.copyWith(headerSize: size);
    await state.save();
  }

  Future<void> updateMetadataSize(int size) async {
    state = state.copyWith(metadataSize: size);
    await state.save();
  }

  Future<void> updatePrintInvoice(bool value) async {
    state = state.copyWith(printInvoice: value);
    await state.save();
  }

  Future<void> updatePrintTicket(bool value) async {
    state = state.copyWith(printTicket: value);
    await state.save();
  }

  void resetToDefaults() {
    state = ThermalPrintSettings();
    state.save();
  }
}
