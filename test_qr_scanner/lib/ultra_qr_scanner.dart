// lib/ultra_qr_scanner.dart
import 'dart:async';
import 'package:flutter/services.dart';

/// Ultra-fast QR code scanner for Flutter with native performance optimization
class UltraQrScanner {
  static const MethodChannel _channel = MethodChannel('ultra_qr_scanner');
  static const EventChannel _eventChannel = EventChannel('ultra_qr_scanner_events');

  static bool _isPrepared = false;
  static bool _isScanning = false;

  /// Request camera permissions
  static Future<bool> requestPermissions() async {
    try {
      final result = await _channel.invokeMethod('requestPermissions');
      return result as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Prepare scanner for ultra-fast access
  static Future<void> prepareScanner() async {
    try {
      await _channel.invokeMethod('prepareScanner');
      _isPrepared = true;
    } catch (e) {
      throw UltraQrScannerException(
        code: 'PREPARE_ERROR',
        message: 'Failed to prepare scanner: $e',
      );
    }
  }

  /// Scan QR code once and return result
  static Future<String?> scanOnce() async {
    if (!_isPrepared) {
      await prepareScanner();
    }

    try {
      final result = await _channel.invokeMethod('scanOnce');
      return result as String?;
    } catch (e) {
      throw UltraQrScannerException(
        code: 'SCAN_ERROR',
        message: 'Failed to scan QR code: $e',
      );
    }
  }

  /// Start continuous scanning stream
  static Stream<String> scanStream() {
    return _eventChannel.receiveBroadcastStream().map((event) => event as String);
  }

  /// Stop scanner and release resources
  static Future<void> stopScanner() async {
    try {
      await _channel.invokeMethod('stopScanner');
      _isScanning = false;
    } catch (e) {
      throw UltraQrScannerException(
        code: 'STOP_ERROR',
        message: 'Failed to stop scanner: $e',
      );
    }
  }

  /// Toggle flash on/off
  static Future<void> toggleFlash(bool enabled) async {
    try {
      await _channel.invokeMethod('toggleFlash', {'enabled': enabled});
    } catch (e) {
      throw UltraQrScannerException(
        code: 'FLASH_ERROR',
        message: 'Failed to toggle flash: $e',
      );
    }
  }

  /// Switch camera (front/back)
  static Future<void> switchCamera(String position) async {
    try {
      await _channel.invokeMethod('switchCamera', {'position': position});
    } catch (e) {
      throw UltraQrScannerException(
        code: 'CAMERA_ERROR',
        message: 'Failed to switch camera: $e',
      );
    }
  }

  /// Check if scanner is prepared
  static bool get isPrepared => _isPrepared;

  /// Check if scanner is currently scanning
  static bool get isScanning => _isScanning;
}

/// Exception thrown by UltraQrScanner
class UltraQrScannerException implements Exception {
  final String code;
  final String message;

  UltraQrScannerException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'UltraQrScannerException: $code - $message';
}