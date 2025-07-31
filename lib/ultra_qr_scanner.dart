// lib/ultra_qr_scanner.dart
import 'dart:async';
import 'package:flutter/services.dart';

class UltraQrScanner {
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  bool _isPrepared = false;

  UltraQrScanner({
    required MethodChannel methodChannel,
    required EventChannel eventChannel,
  })  : _methodChannel = methodChannel,
        _eventChannel = eventChannel;

  /// Preloads the scanner without starting the preview.
  /// This should be called before showing the scanner UI.
  Future<void> prepareScanner() async {
    try {
      await _methodChannel.invokeMethod('prepareScanner');
      _isPrepared = true;
    } on PlatformException catch (e) {
      throw UltraQrScannerException(
        code: e.code,
        message: e.message ?? 'Failed to prepare scanner',
        details: e.details,
      );
    }
  }

  /// Starts the scanner and returns the first detected QR code.
  /// Automatically stops the scanner after first detection.
  Future<String?> scanOnce() async {
    if (!_isPrepared) {
      throw UltraQrScannerException(
        code: 'NOT_PREPARED',
        message: 'Scanner not prepared. Call prepareScanner() first.',
      );
    }
    try {
      return await _methodChannel.invokeMethod('scanOnce');
    } catch (e) {
      throw UltraQrScannerException(
        code: 'SCAN_ERROR',
        message: 'Failed to scan QR code: ${e.toString()}',
        details: e,
      );
    }
  }

  /// Starts continuous scanning stream.
  /// Returns a stream of detected QR codes.
  /// Automatically stops after first detection if autoStop is true.
  Stream<String> startScanStream({bool autoStop = true}) {
    if (!_isPrepared) {
      throw UltraQrScannerException(
        code: 'NOT_PREPARED',
        message: 'Scanner not prepared. Call prepareScanner() first.',
      );
    }
    return _eventChannel.receiveBroadcastStream().map((event) => event.toString());
  }

  /// Stops the scanner and releases resources.
  Future<void> stopScanner() async {
    try {
      await _methodChannel.invokeMethod('stopScanner');
      _isPrepared = false;
    } catch (e) {
      throw UltraQrScannerException(
        code: 'STOP_ERROR',
        message: 'Failed to stop scanner: ${e.toString()}',
        details: e,
      );
    }
  }

  /// Toggles the camera flash.
  Future<void> toggleFlash(bool enabled) async {
    try {
      await _methodChannel.invokeMethod('toggleFlash', {'enabled': enabled});
    } catch (e) {
      throw UltraQrScannerException(
        code: 'FLASH_ERROR',
        message: 'Failed to toggle flash: ${e.toString()}',
        details: e,
      );
    }
  }

  /// Switches between front and back camera.
  Future<void> switchCamera(String position) async {
    try {
      await _methodChannel.invokeMethod('switchCamera', {'position': position});
    } catch (e) {
      throw UltraQrScannerException(
        code: 'CAMERA_SWITCH_ERROR',
        message: 'Failed to switch camera: ${e.toString()}',
        details: e,
      );
    }
  }

  /// Requests camera permissions.
  /// Returns true if permissions are granted.
  Future<bool> requestPermissions() async {
    try {
      return await _methodChannel.invokeMethod('requestPermissions');
    } catch (e) {
      throw UltraQrScannerException(
        code: 'PERMISSION_ERROR',
        message: 'Failed to request permissions: ${e.toString()}',
        details: e,
      );
    }
  }

  /// Checks if scanner is prepared and ready.
  bool get isPrepared => _isPrepared;
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