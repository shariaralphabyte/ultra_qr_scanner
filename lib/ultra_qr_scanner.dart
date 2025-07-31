// lib/ultra_qr_scanner.dart
import 'dart:async';
import 'package:flutter/services.dart';

class UltraQrScanner {
  static const MethodChannel _channel = MethodChannel('ultra_qr_scanner');
  static const EventChannel _eventChannel = EventChannel('ultra_qr_scanner_stream');
  static bool _isPrepared = false;

  /// Preloads the scanner without starting the preview.
  /// This should be called before showing the scanner UI.
  static Future<void> prepareScanner() async {
    try {
      await _channel.invokeMethod('prepareScanner');
      _isPrepared = true;
    } catch (e) {
      throw UltraQrScannerException(
        code: 'PREPARE_ERROR',
        message: 'Failed to prepare scanner: ${e.toString()}',
        details: e,
      );
    }
  }

  /// Starts the scanner and returns the first detected QR code.
  /// Automatically stops the scanner after first detection.
  static Future<String?> scanOnce() async {
    }

    try {
      final result = await _methodChannel.invokeMethod('scanOnce');
      return result as String?;
    } on PlatformException catch (e) {
      throw UltraQrScannerException(
        code: 'SCAN_ERROR',
        message: 'Failed to scan QR code: ${e.message}',
        details: e.message,
      );
    }
  }

  /// Starts continuous scanning stream.
  /// Returns a stream of detected QR codes.
  /// Automatically stops after first detection if [autoStop] is true.
  static Stream<String> startScanStream({bool autoStop = true}) {
    return _eventChannel.receiveBroadcastStream().map((event) => event.toString());
  }

  /// Stops the scanner and releases resources.
  static Future<void> stopScanner() async {
    try {
      await _channel.invokeMethod('stopScanner');
    } catch (e) {
      throw UltraQrScannerException(
        message: 'Failed to stop scanner: ${e.toString()}',
        code: 'STOP_ERROR',
        details: e,
      );
    }
  }

  /// Toggles the camera flash.
  static Future<void> toggleFlash(bool enabled) async {
    try {
      await _channel.invokeMethod('toggleFlash', {'enabled': enabled});
    } catch (e) {
      throw UltraQrScannerException(
        message: 'Failed to toggle flash: ${e.toString()}',
        code: 'FLASH_ERROR',
        details: e,
      );
    }
  }

  /// Switches between front and back camera.
  static Future<void> switchCamera(String position) async {
    try {
      await _channel.invokeMethod('switchCamera', {'position': position});
    } catch (e) {
      throw UltraQrScannerException(
        message: 'Failed to switch camera: ${e.toString()}',
        code: 'CAMERA_SWITCH_ERROR',
        details: e,
      );
    }
  }

  /// Requests camera permissions.
  /// Returns true if permissions are granted.
  static Future<bool> requestPermissions() async {
    try {
      return await _channel.invokeMethod('requestPermissions');
    } catch (e) {
      throw UltraQrScannerException(
        message: 'Failed to request permissions: ${e.toString()}',
        code: 'PERMISSION_ERROR',
        details: e,
      );
    }
  }
  static bool get isPrepared => _isPrepared;
}

/// Exception thrown by UltraQrScanner
class UltraQrScannerException implements Exception {
  final String code;
  final String message;
  final dynamic details;

  UltraQrScannerException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'UltraQrScannerException: $message (code: $code)';
}