import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SmartPosPrinterService {
  static const MethodChannel _channel =
      MethodChannel('com.smartpos.sdk/printer');
  
  static bool _sdkInitialized = false;

  /// Initialize the SmartPos SDK (cached - only initializes once)
  Future<bool> initSdk() async {
    if (_sdkInitialized) return true;
    
    try {
      final String result = await _channel.invokeMethod('initSdk');
      _sdkInitialized = result == "SDK Initialized Successfully";
      return _sdkInitialized;
    } on PlatformException catch (e) {
      debugPrint("Failed to init SDK: '${e.message}'.");
      _sdkInitialized = false;
      return false;
    }
  }

  /// Print text with optional formatting
  Future<bool> printText({
    required String text,
    int size = 24,
    bool isBold = false,
    int align = 0, // 0: Left, 1: Center, 2: Right
  }) async {
    try {
      final String result = await _channel.invokeMethod('printText', {
        'text': text,
        'size': size,
        'isBold': isBold,
        'align': align,
      });
      return result == "Printed Successfully";
    } on PlatformException catch (e) {
      debugPrint("Failed to print text: '${e.message}'.");
      return false;
    }
  }

  /// Cut paper (if cutter is available)
  Future<void> cutPaper() async {
    try {
      await _channel.invokeMethod('cutPaper');
    } on PlatformException catch (e) {
      debugPrint("Failed to cut paper: '${e.message}'.");
    }
  }
}
