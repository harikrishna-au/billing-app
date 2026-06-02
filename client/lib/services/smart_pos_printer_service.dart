import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// SmartPOS native printer service using the Android MethodChannel bridge.
class SmartPosPrinterService {
  static const MethodChannel _channel =
      MethodChannel('com.smartpos.sdk/printer');

  static Future<String?> getSavedPrinterAddress() async {
    return null;
  }

  static Future<void> savePrinterAddress(String? address) async {
    return;
  }

  /// Connects to the native attached printer bridge.
  Future<bool> initSdk() async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('SmartPosPrinterService: printing is Android-only');
      return false;
    }
    try {
      await _channel.invokeMethod('initSdk');
      return true;
    } on PlatformException catch (e) {
      throw StateError('SmartPOS SDK init failed: ${e.message ?? e.code}');
    }
  }

  /// No-op for SDK printers, kept for call-site compatibility.
  Future<void> resetPrintSession() async {}

  /// Print one styled line on the attached printer.
  Future<bool> printText({
    required String text,
    int size = 24,
    bool isBold = false,
    int align = 0,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw StateError('Printing is only supported on Android.');
    }
    await initSdk();
    try {
      await _channel.invokeMethod('printText', {
        'text': text,
        'size': size,
        'isBold': isBold,
        'align': align,
      });
      return true;
    } on PlatformException catch (e) {
      throw StateError('Print failed: ${e.message ?? e.code}');
    }
  }

  Future<bool> printLines(List<Map<String, Object?>> lines) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw StateError('Printing is only supported on Android.');
    }
    await initSdk();
    try {
      await _channel.invokeMethod('printLines', {'lines': lines});
      return true;
    } on MissingPluginException catch (e) {
      debugPrint(
        'SmartPosPrinterService: printLines missing, falling back to printText: $e',
      );
      for (final line in lines) {
        await printText(
          text: (line['text'] as String?) ?? '',
          size: (line['size'] as int?) ?? 24,
          isBold: (line['isBold'] as bool?) ?? false,
          align: (line['align'] as int?) ?? 0,
        );
      }
      return true;
    } on PlatformException catch (e) {
      throw StateError('Print failed: ${e.message ?? e.code}');
    }
  }

  Future<void> cutPaper() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cutPaper');
    } catch (e) {
      debugPrint('SmartPosPrinterService: cutPaper failed: $e');
    }
  }
}
