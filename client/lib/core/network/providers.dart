import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_manager.dart';
import 'api_client.dart';
import '../services/printer_service.dart';
import '../services/sync_queue_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final tokenManagerProvider = Provider<TokenManager>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TokenManager(prefs);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenManager = ref.watch(tokenManagerProvider);
  return ApiClient(tokenManager);
});



final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService();
});

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  return SyncQueueService();
});
