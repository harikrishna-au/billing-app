import 'package:flutter/services.dart';

class SmartPosPrinterService {
  static const MethodChannel _channel =
      MethodChannel('com.smartpos.sdk/printer');

  /// Initialize the SmartPos SDK
  Future<bool> initSdk() async {
    try {
      final String result = await _channel.invokeMethod('initSdk');
      return result == "SDK Initialized Successfully";
    } on PlatformException catch (e) {
      print("Failed to init SDK: '${e.message}'.");
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
      print("Failed to print text: '${e.message}'.");
      return false;
    }
  }

  /// Cut paper (if cutter is available)
  Future<void> cutPaper() async {
    try {
      await _channel.invokeMethod('cutPaper');
    } on PlatformException catch (e) {
      print("Failed to cut paper: '${e.message}'.");
    }
  }
}
