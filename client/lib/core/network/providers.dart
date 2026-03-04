import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_manager.dart';
import 'api_client.dart';
import '../services/printer_service.dart';
import '../services/paytm_pos_service.dart';
import '../services/sync_queue_service.dart';
import '../services/cache_service.dart';
import '../utils/bill_number_generator.dart';
import '../utils/printed_bills_tracker.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

// TokenManager is overridden in main.dart after initialization.
final tokenManagerProvider = Provider<TokenManager>((ref) {
  throw UnimplementedError('TokenManager not initialized — override in main.dart');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenManager = ref.watch(tokenManagerProvider);
  return ApiClient(tokenManager);
});

final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService();
});

final paytmPosServiceProvider = Provider<PaytmPosService>((ref) {
  return PaytmPosService();
});

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SyncQueueService(prefs);
});

final cacheServiceProvider = Provider<CacheService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CacheService(prefs);
});

final billNumberServiceProvider = Provider<BillNumberGenerator>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BillNumberGenerator(prefs);
});

final printedBillsTrackerProvider = Provider<PrintedBillsTracker>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PrintedBillsTracker(prefs);
});
