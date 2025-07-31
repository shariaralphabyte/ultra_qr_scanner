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
      throw UltraQrScannerException('Failed to prepare scanner: ${e.message}');
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
      throw UltraQrScannerException('Scan failed: ${e.message}');
    }
  }

  /// Start continuous QR scanning stream
  /// Returns a stream that emits detected QR codes
  static Stream<String> scanStream() {
    if (!_isPrepared) {
      throw UltraQrScannerException('Scanner not prepared. Call prepareScanner() first.');
    }

    _scanStream ??= _eventChannel.receiveBroadcastStream().map((event) => event as String);

    // Start the scanning
    _methodChannel.invokeMethod('startScanStream');

    return _scanStream!;
  }

  /// Stop the scanner and release camera resources
  static Future<void> stopScanner() async {
    try {
      await _methodChannel.invokeMethod('stopScanner');
      _scanStream = null;
    } on PlatformException catch (e) {
      throw UltraQrScannerException('Failed to stop scanner: ${e.message}');
    }
  }

  /// Toggle flashlight on/off
  static Future<void> toggleFlash(bool enabled) async {
    try {
      await _methodChannel.invokeMethod('toggleFlash', {'enabled': enabled});
    } on PlatformException catch (e) {
      throw UltraQrScannerException('Failed to toggle flash: ${e.message}');
    }
  }

  /// Pause QR detection without stopping camera
  static Future<void> pauseDetection() async {
    try {
      await _methodChannel.invokeMethod('pauseDetection');
    } on PlatformException catch (e) {
      throw UltraQrScannerException('Failed to pause detection: ${e.message}');
    }
  }

  /// Resume QR detection
  static Future<void> resumeDetection() async {
    try {
      await _methodChannel.invokeMethod('resumeDetection');
    } on PlatformException catch (e) {
      throw UltraQrScannerException('Failed to resume detection: ${e.message}');
    }
  }

  /// Request camera permissions
  static Future<bool> requestPermissions() async {
    try {
      final granted = await _methodChannel.invokeMethod('requestPermissions');
      return granted as bool;
    } on PlatformException catch (e) {
      throw UltraQrScannerException('Permission request failed: ${e.message}');
    }
  }

  /// Check if scanner is prepared and ready
  static bool get isPrepared => _isPrepared;
}

/// Exception thrown by UltraQrScanner
class UltraQrScannerException implements Exception {
  final String message;

  const UltraQrScannerException(this.message);

  @override
  String toString() => 'UltraQrScannerException: $message';
}