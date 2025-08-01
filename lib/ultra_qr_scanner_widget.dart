library ultra_qr_scanner;

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Ultra-fast QR scanner plugin with native performance optimizations
class UltraQrScanner {
  static const MethodChannel _channel = MethodChannel('ultra_qr_scanner');
  static const EventChannel _scanChannel = EventChannel('ultra_qr_scanner/scan');

  static StreamSubscription<String>? _scanSubscription;
  static StreamController<QrScanResult>? _resultController;

  /// Initialize the scanner with optimized settings
  static Future<bool> initialize({
    ScanConfig? config,
  }) async {
    try {
      final result = await _channel.invokeMethod('initialize', {
        'enableGpuAcceleration': config?.enableGpuAcceleration ?? true,
        'optimizeForSpeed': config?.optimizeForSpeed ?? true,
        'previewResolution': config?.previewResolution?.name ?? 'medium',
        'focusMode': config?.focusMode?.name ?? 'auto',
        'enableMultiScanning': config?.enableMultiScanning ?? false,
        'torchEnabled': config?.torchEnabled ?? false,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Start scanning with ultra-fast detection
  static Stream<QrScanResult> startScanning({
    List<BarcodeFormat>? formats,
    bool continuousScanning = false,
  }) {
    _resultController?.close();
    _resultController = StreamController<QrScanResult>.broadcast();

    _scanSubscription?.cancel();
    _scanSubscription = _scanChannel.receiveBroadcastStream({
      'formats': formats?.map((f) => f.name).toList() ?? ['qr'],
      'continuous': continuousScanning,
    }).listen(
          (data) {
        if (data is Map<dynamic, dynamic>) {
          final result = QrScanResult.fromMap(Map<String, dynamic>.from(data));
          _resultController?.add(result);
        }
      },
      onError: (error) {
        _resultController?.addError(error);
      },
    );

    return _resultController!.stream;
  }

  /// Stop scanning and release resources
  static Future<void> stopScanning() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _resultController?.close();
    _resultController = null;
    await _channel.invokeMethod('stopScanning');
  }

  /// Toggle torch/flashlight
  static Future<bool> toggleTorch() async {
    try {
      final result = await _channel.invokeMethod('toggleTorch');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if device has torch capability
  static Future<bool> hasTorch() async {
    try {
      final result = await _channel.invokeMethod('hasTorch');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Focus camera at specific point
  static Future<bool> focusAt(double x, double y) async {
    try {
      final result = await _channel.invokeMethod('focusAt', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get scanning statistics for performance monitoring
  static Future<ScanStats?> getStats() async {
    try {
      final result = await _channel.invokeMethod('getStats');
      if (result != null) {
        return ScanStats.fromMap(Map<String, dynamic>.from(result));
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  /// Dispose and cleanup resources
  static Future<void> dispose() async {
    await stopScanning();
    await _channel.invokeMethod('dispose');
  }
}

/// QR scan result with detailed information
class QrScanResult {
  final String data;
  final BarcodeFormat format;
  final List<Point> corners;
  final DateTime timestamp;
  final double confidence;
  final int processingTimeMs;

  const QrScanResult({
    required this.data,
    required this.format,
    required this.corners,
    required this.timestamp,
    required this.confidence,
    required this.processingTimeMs,
  });

  factory QrScanResult.fromMap(Map<String, dynamic> map) {
    return QrScanResult(
      data: map['data'] ?? '',
      format: BarcodeFormat.values.firstWhere(
            (f) => f.name == map['format'],
        orElse: () => BarcodeFormat.qr,
      ),
      corners: (map['corners'] as List<dynamic>?)
          ?.map((c) => Point.fromMap(Map<String, dynamic>.from(c)))
          .toList() ?? [],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      processingTimeMs: map['processingTimeMs'] ?? 0,
    );
  }
}

/// Point coordinates for barcode corners
class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);

  factory Point.fromMap(Map<String, dynamic> map) {
    return Point(
      (map['x'] ?? 0.0).toDouble(),
      (map['y'] ?? 0.0).toDouble(),
    );
  }
}

/// Supported barcode formats
enum BarcodeFormat {
  qr,
  dataMatrix,
  code128,
  code39,
  code93,
  ean8,
  ean13,
  upca,
  upce,
  pdf417,
  aztec,
}

/// Scanner configuration for optimization
class ScanConfig {
  final bool enableGpuAcceleration;
  final bool optimizeForSpeed;
  final PreviewResolution previewResolution;
  final FocusMode focusMode;
  final bool enableMultiScanning;
  final bool torchEnabled;

  const ScanConfig({
    this.enableGpuAcceleration = true,
    this.optimizeForSpeed = true,
    this.previewResolution = PreviewResolution.medium,
    this.focusMode = FocusMode.auto,
    this.enableMultiScanning = false,
    this.torchEnabled = false,
  });
}

/// Preview resolution options
enum PreviewResolution {
  low,    // 480p - fastest
  medium, // 720p - balanced
  high,   // 1080p - highest quality
}

/// Camera focus modes
enum FocusMode {
  auto,
  continuous,
  manual,
  fixed,
}

/// Scanning performance statistics
class ScanStats {
  final int totalScans;
  final int successfulScans;
  final double averageProcessingTime;
  final double successRate;
  final int framesPerSecond;

  const ScanStats({
    required this.totalScans,
    required this.successfulScans,
    required this.averageProcessingTime,
    required this.successRate,
    required this.framesPerSecond,
  });

  factory ScanStats.fromMap(Map<String, dynamic> map) {
    return ScanStats(
      totalScans: map['totalScans'] ?? 0,
      successfulScans: map['successfulScans'] ?? 0,
      averageProcessingTime: (map['averageProcessingTime'] ?? 0.0).toDouble(),
      successRate: (map['successRate'] ?? 0.0).toDouble(),
      framesPerSecond: map['framesPerSecond'] ?? 0,
    );
  }
}