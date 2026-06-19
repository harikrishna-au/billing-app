import 'pine_terminal_config.dart';

class PlutusConfig {
  /// Master switch for Plutus App-to-App flow.
  /// Disabled by default on this branch (PhonePe P1000 device — no Pine Labs).
  static const bool enabled = bool.fromEnvironment(
    'PLUTUS_ENABLED',
    defaultValue: false,
  );

  /// Issued by Pine Labs for your billing app.
  static const String applicationId = String.fromEnvironment(
    'PLUTUS_APPLICATION_ID',
    // UAT app id shared by Pine team (corrected 32-char value; earlier email
    // dropped the leading "5"). Can still be overridden via --dart-define.
    defaultValue: '50269e0a955c4370a9c04c78fb111bd4',
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

