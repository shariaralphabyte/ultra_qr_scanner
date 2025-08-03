// lib/ultra_qr_scanner.dart
import 'dart:async';
import 'package:flutter/services.dart';

typedef QrCodeCallback = void Function(String? code);

class UltraQrScanner {
  static const MethodChannel _channel = MethodChannel('ultra_qr_scanner');
  static const EventChannel _eventChannel = EventChannel('ultra_qr_scanner_events');

  bool _isScanning = false;
  StreamController<String?>? _streamController;

  UltraQrScanner._();

  static final UltraQrScanner _instance = UltraQrScanner._();

  factory UltraQrScanner() => _instance;

  Stream<String?> get onCodeDetected {
    _streamController ??= StreamController<String?>(
      onListen: _startListening,
      onCancel: _stopListening,
    );
    return _streamController!.stream;
  }

  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
    } catch (e) {
      throw QrScannerException(
        code: 'INIT_ERROR',
        message: 'Failed to initialize scanner: $e',
      );
    }
  }

  Future<void> startScanning() async {
    if (_isScanning) return;

    try {
      await _channel.invokeMethod('startScanning');
      _isScanning = true;
    } catch (e) {
      throw QrScannerException(
        code: 'START_ERROR',
        message: 'Failed to start scanning: $e',
      );
    }
  }

  Future<void> stopScanning() async {
    if (!_isScanning) return;

    try {
      await _channel.invokeMethod('stopScanning');
      _isScanning = false;
    } catch (e) {
      throw QrScannerException(
        code: 'STOP_ERROR',
        message: 'Failed to stop scanning: $e',
      );
    }
  }

  void _startListening() {
    _eventChannel.receiveBroadcastStream().listen(
          (event) {
        _streamController?.add(event as String?);
      },
      onError: (error) {
        _streamController?.addError(error);
      },
    );
  }

  void _stopListening() {
    _streamController?.close();
    _streamController = null;
  }
}

/// Exception thrown by UltraQrScanner
class QrScannerException implements Exception {
  final String code;
  final String message;

  QrScannerException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => '$runtimeType: $code - $message';
}