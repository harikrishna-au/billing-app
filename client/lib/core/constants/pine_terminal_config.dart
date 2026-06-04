/// Watersports / PI-7925 Pine Labs UAT terminal (A910S PayDroid).
/// Hardware serial must be registered on Pine UAT against [PlutusConfig.applicationId].
class PineTerminalConfig {
  static const String jiraId = 'PI-7925';
  static const String merchantName = 'WATERSPORTS SIMPLE INDIA PRIVATE LIMITED';
  static const String storeName = 'WATERSPORTS SIMPLE';

  /// Pine prerequest / Chetan mapping.
  static const String posId = '1014596';

  /// Device label from PayDroid About screen (register this with Pine Labs UAT).
  static const String hardwareSerial = '2842079646';

  static const String merchantUniqueId = 'WATE4933VIJ';
  static const String model = 'A910S';
  static const String partNumber = 'A910S-3AW-RL6-F0EH';
  static const String paydroidVersion =
      'PayDroid_14.0.0_Acacia_V13.1.00_20250915';
  static const String securityFirmware = '1.00';

  /// Email body snippet for Pine Labs (copy from Settings → Terminal).
  static String registrationSummary({required String plutusApplicationId}) {
    return '''
JIRA: $jiraId
Merchant: $merchantName
Store: $storeName
POS ID: $posId
Hardware S/N: $hardwareSerial
IMEI / Unique ID: $merchantUniqueId
Model: $model
PN: $partNumber
PayDroid: $paydroidVersion
MIT package: com.mit
UAT Application ID: $plutusApplicationId
'''.trim();
  }
}
