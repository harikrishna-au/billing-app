import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThermalPrintSettings {
  final int titleSize;
  final int orgNameSize;
  final int unitNameSize;
  final int bodySize;
  final int headerSize;
  final int metadataSize;

  ThermalPrintSettings({
    this.titleSize = 52,
    this.orgNameSize = 39,
    this.unitNameSize = 29,
    this.bodySize = 34,
    this.headerSize = 42,
    this.metadataSize = 34,
  });

  ThermalPrintSettings copyWith({
    int? titleSize,
    int? orgNameSize,
    int? unitNameSize,
    int? bodySize,
    int? headerSize,
    int? metadataSize,
  }) {
    return ThermalPrintSettings(
      titleSize: titleSize ?? this.titleSize,
      orgNameSize: orgNameSize ?? this.orgNameSize,
      unitNameSize: unitNameSize ?? this.unitNameSize,
      bodySize: bodySize ?? this.bodySize,
      headerSize: headerSize ?? this.headerSize,
      metadataSize: metadataSize ?? this.metadataSize,
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
  }

  static Future<ThermalPrintSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ThermalPrintSettings(
      titleSize: prefs.getInt('thermal_title_size') ?? 52,
      orgNameSize: prefs.getInt('thermal_org_size') ?? 39,
      unitNameSize: prefs.getInt('thermal_unit_size') ?? 29,
      bodySize: prefs.getInt('thermal_body_size') ?? 34,
      headerSize: prefs.getInt('thermal_header_size') ?? 42,
      metadataSize: prefs.getInt('thermal_metadata_size') ?? 34,
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

  void resetToDefaults() {
    state = ThermalPrintSettings();
    state.save();
  }
}
