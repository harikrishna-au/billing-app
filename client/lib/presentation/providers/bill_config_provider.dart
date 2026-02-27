import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/bill_config_model.dart';
import '../../data/repositories/bill_config_repository.dart';
import '../../core/network/providers.dart';

final billConfigRepositoryProvider = Provider<BillConfigRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return BillConfigRepository(apiClient, prefs);
});

/// Holds the current bill config. Starts from the cached value so the
/// app works even if offline. Refreshed after a successful machine login.
final billConfigProvider = StateNotifierProvider<BillConfigNotifier, BillConfig>((ref) {
  final repo = ref.watch(billConfigRepositoryProvider);
  return BillConfigNotifier(repo);
});

class BillConfigNotifier extends StateNotifier<BillConfig> {
  final BillConfigRepository _repo;

  BillConfigNotifier(this._repo) : super(_repo.loadCached());

  Future<void> refresh(String machineId) async {
    try {
      final config = await _repo.fetchAndCache(machineId);
      state = config;
    } catch (_) {
      // Keep cached value on network failure — do not throw
    }
  }
}
