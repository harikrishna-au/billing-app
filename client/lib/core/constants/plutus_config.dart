import 'pine_terminal_config.dart';

class PlutusConfig {
  /// Master switch for Plutus App-to-App flow.
  /// Set to true to force CARD/UPI through Plutus.
  static const bool enabled = bool.fromEnvironment(
    'PLUTUS_ENABLED',
    defaultValue: true,
  );

  /// Issued by Pine Labs for your billing app.
  ///
  /// PRODUCTION app id (Laxmi, 2026-06-19, PI-7925). Builds ship to live
  /// terminals with this value.
  ///
  /// To test against the UAT terminal instead, override at build time:
  ///   --dart-define=PLUTUS_APPLICATION_ID=50269e0a955c4370a9c04c78fb111bd4
  static const String applicationId = String.fromEnvironment(
    'PLUTUS_APPLICATION_ID',
    defaultValue: '14103d3b12a444d6b5ffff15022d8a27',
  );

  /// Optional operator/user id for Pine header.
  static const String userId = String.fromEnvironment(
    'PLUTUS_USER_ID',
    // Pine Labs reference sample always sends a non-empty UserId.
    defaultValue: 'user1234',
  );

  /// Header version as per Pine docs.
  static const String apiVersion = String.fromEnvironment(
    'PLUTUS_API_VERSION',
    defaultValue: '1.0',
  );

  static bool get isConfigured => enabled && applicationId.trim().isNotEmpty;

  /// Copy-paste block for Pine Labs UAT device registration email.
  static String get pineRegistrationSummary =>
      PineTerminalConfig.registrationSummary(
        plutusApplicationId: applicationId,
      );
}

