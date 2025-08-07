import 'dart:async';
import 'ultra_qr_scanner_platform_interface.dart';

/// Ultra-fast QR code scanner for Flutter with native performance optimization
class UltraQrScanner {
  static bool _isPrepared = false;
  static bool _isScanning = false;

  /// Request camera permissions
  static Future<bool> requestPermissions() async {
    try {
      return await UltraQrScannerPlatform.instance.requestPermissions();
    } catch (e) {
      return false;
    }
  }

  /// Prepare scanner for ultra-fast access
  static Future<void> prepareScanner() async {
    try {
      final success = await UltraQrScannerPlatform.instance.prepareScanner();
      if (success) {
        _isPrepared = true;
      } else {
        throw UltraQrScannerException(
          code: 'PREPARE_ERROR',
          message: 'Failed to prepare scanner',
        );
      }
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
      _isScanning = true;
      final result = await UltraQrScannerPlatform.instance.scanOnce();
      return result;
    } catch (e) {
      _isScanning = false;
      throw UltraQrScannerException(
        code: 'SCAN_ERROR',
        message: 'Failed to scan QR code: $e',
      );
    }
  }

  /// Start continuous scanning stream
  static Stream<String> scanStream() {
    try {
      return UltraQrScannerPlatform.instance.scanStream();
    } catch (e) {
      throw UltraQrScannerException(
        code: 'STREAM_ERROR',
        message: 'Failed to start scan stream: $e',
      );
    }
  }

  /// Stop scanner and release resources
  static Future<void> stopScanner() async {
    try {
      await UltraQrScannerPlatform.instance.stopScanner();
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
      await UltraQrScannerPlatform.instance.toggleFlash(enabled);
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
      await UltraQrScannerPlatform.instance.switchCamera(position);
    } catch (e) {
      throw UltraQrScannerException(
        code: 'CAMERA_ERROR',
        message: 'Failed to switch camera: $e',
      );
    }
  }

  /// Get platform version (for testing)
  static Future<String?> getPlatformVersion() async {
    try {
      return await UltraQrScannerPlatform.instance.getPlatformVersion();
    } catch (e) {
      return null;
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