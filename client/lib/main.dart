import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/router/app_router.dart';
import 'config/theme/app_theme.dart';
import 'core/network/providers.dart';
import 'core/network/token_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SharedPreferences: used for non-sensitive data (sync queue, cache, etc.)
  final sharedPreferences = await SharedPreferences.getInstance();

  // Secure storage: tokens stored in Android Keystore.
  // encryptedSharedPreferences = true uses EncryptedSharedPreferences on Android.
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final tokenManager = TokenManager(secureStorage);
  await tokenManager.initialize(); // warm in-memory cache from Keystore

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        tokenManagerProvider.overrideWithValue(tokenManager),
      ],
      child: const MitApp(),
    ),
  );
}

class MitApp extends ConsumerWidget {
  const MitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MIT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
