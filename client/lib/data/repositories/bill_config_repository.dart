import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/bill_config_model.dart';

const _kPrefsKey = 'bill_config';

class BillConfigRepository {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;

  BillConfigRepository(this._apiClient, this._prefs);

  /// Fetch config from backend and cache it locally.
  /// Returns [BillConfig.empty] if the machine has no config set yet.
  Future<BillConfig> fetchAndCache(String machineId) async {
    final response = await _apiClient.dio.get(ApiConstants.billConfig(machineId));
    final data = response.data['data'];
    if (data == null) return BillConfig.empty;

    final config = BillConfig.fromJson(data as Map<String, dynamic>);
    await _prefs.setString(_kPrefsKey, jsonEncode(config.toJson()));
    return config;
  }

  /// Read the locally cached config (fast, no network).
  BillConfig loadCached() {
    final raw = _prefs.getString(_kPrefsKey);
    if (raw == null) return BillConfig.empty;
    try {
      return BillConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return BillConfig.empty;
    }
  }
}
