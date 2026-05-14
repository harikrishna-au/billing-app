class PlutusConfig {
  /// Master switch for Plutus App-to-App flow.
  /// Set to true to force CARD/UPI through Plutus.
  static const bool enabled = bool.fromEnvironment(
    'PLUTUS_ENABLED',
    defaultValue: true,
  );

  /// Issued by Pine Labs for your billing app.
  static const String applicationId = String.fromEnvironment(
    'PLUTUS_APPLICATION_ID',
    // UAT app id shared by Pine team; can still be overridden via --dart-define.
    defaultValue: '0269e0a955c4370a9c04c78fb111bd4',
  );

  /// Optional operator/user id for Pine header.
  static const String userId = String.fromEnvironment(
    'PLUTUS_USER_ID',
    defaultValue: '',
  );

  /// Header version as per Pine docs.
  static const String apiVersion = String.fromEnvironment(
    'PLUTUS_API_VERSION',
    defaultValue: '1.0',
  );

  static bool get isConfigured => enabled && applicationId.trim().isNotEmpty;
}

