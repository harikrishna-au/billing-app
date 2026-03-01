import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/providers.dart';

class UpiSettings {
  final String upiId;
  final String merchantName;

  const UpiSettings({required this.upiId, required this.merchantName});

  bool get isConfigured => upiId.trim().isNotEmpty;

  UpiSettings copyWith({String? upiId, String? merchantName}) => UpiSettings(
        upiId: upiId ?? this.upiId,
        merchantName: merchantName ?? this.merchantName,
      );
}

class UpiSettingsNotifier extends StateNotifier<UpiSettings> {
  static const _keyUpiId = 'upi_id';
  static const _keyMerchantName = 'upi_merchant_name';

  final SharedPreferences _prefs;

  UpiSettingsNotifier(this._prefs)
      : super(UpiSettings(
          upiId: _prefs.getString(_keyUpiId) ?? '',
          merchantName: _prefs.getString(_keyMerchantName) ?? '',
        ));

  Future<void> save({required String upiId, required String merchantName}) async {
    await _prefs.setString(_keyUpiId, upiId.trim());
    await _prefs.setString(_keyMerchantName, merchantName.trim());
    state = UpiSettings(upiId: upiId.trim(), merchantName: merchantName.trim());
  }
}

final upiSettingsProvider =
    StateNotifierProvider<UpiSettingsNotifier, UpiSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UpiSettingsNotifier(prefs);
});
