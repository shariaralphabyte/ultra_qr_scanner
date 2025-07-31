// lib/ultra_qr_scanner.dart
import 'dart:async';
import 'package:flutter/services.dart';

class UltraQrScanner {
  static const MethodChannel _methodChannel = MethodChannel('ultra_qr_scanner');
  static const EventChannel _eventChannel = EventChannel('ultra_qr_scanner_events');

  static Stream<String>? _scanStream;
  static bool _isPrepared = false;

  /// Preload and prepare the scanner for ultra-fast startup
  /// Call this during app initialization for best performance
  static Future<void> prepareScanner() async {
    if (_isPrepared) return;

    try {
      await _methodChannel.invokeMethod('prepareScanner');
      _isPrepared = true;
    } on PlatformException catch (e) {
      throw UltraQrScannerException(
      code: 'PREPARE_ERROR',
      message: 'Failed to prepare scanner: ${e.message}',
      details: e.message,
    );
    }
  }

  /// Perform a single QR scan and return the result
  /// Scanner automatically stops after first detection
  static Future<String?> scanOnce() async {
    if (!_isPrepared) {
      throw UltraQrScannerException('Scanner not prepared. Call prepareScanner() first.');
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