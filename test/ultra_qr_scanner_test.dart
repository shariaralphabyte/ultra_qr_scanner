import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner.dart';

void main() {
  group('UltraQrScanner Tests', () {
    test('QrScanResult creation and properties', () {
      final timestamp = DateTime.now();
      final corners = [
        const Point(0, 0),
        const Point(100, 0),
        const Point(100, 100),
        const Point(0, 100),
      ];

      final result = QrScanResult(
        data: 'https://example.com',
        format: BarcodeFormat.qr,
        corners: corners,
        timestamp: timestamp,
        confidence: 0.95,
        processingTimeMs: 45,
      );

      expect(result.data, equals('https://example.com'));
      expect(result.format, equals(BarcodeFormat.qr));
      expect(result.corners.length, equals(4));
      expect(result.timestamp, equals(timestamp));
      expect(result.confidence, equals(0.95));
      expect(result.processingTimeMs, equals(45));
    });

    test('QrScanResult fromMap conversion', () {
      final map = {
        'data': 'test_data',
        'format': 'qr',
        'corners': [
          {'x': 10.0, 'y': 20.0},
          {'x': 30.0, 'y': 40.0},
        ],
        'timestamp': 1634567890000,
        'confidence': 0.8,
        'processingTimeMs': 50,
      };

      final result = QrScanResult.fromMap(map);

      expect(result.data, equals('test_data'));
      expect(result.format, equals(BarcodeFormat.qr));
      expect(result.corners.length, equals(2));
      expect(result.corners[0].x, equals(10.0));
      expect(result.corners[0].y, equals(20.0));
      expect(result.confidence, equals(0.8));
      expect(result.processingTimeMs, equals(50));
    });

    test('Point creation and properties', () {
      const point = Point(15.5, 25.3);

      expect(point.x, equals(15.5));
      expect(point.y, equals(25.3));
    });

    test('Point fromMap conversion', () {
      final map = {'x': 100.0, 'y': 200.0};
      final point = Point.fromMap(map);

      expect(point.x, equals(100.0));
      expect(point.y, equals(200.0));
    });

    test('ScanConfig default values', () {
      const config = ScanConfig();

      expect(config.enableGpuAcceleration, isTrue);
      expect(config.optimizeForSpeed, isTrue);
      expect(config.previewResolution, equals(PreviewResolution.medium));
      expect(config.focusMode, equals(FocusMode.auto));
      expect(config.enableMultiScanning, isFalse);
      expect(config.torchEnabled, isFalse);
    });

    test('ScanConfig custom values', () {
      const config = ScanConfig(
        enableGpuAcceleration: false,
        optimizeForSpeed: false,
        previewResolution: PreviewResolution.high,
        focusMode: FocusMode.continuous,
        enableMultiScanning: true,
        torchEnabled: true,
      );

      expect(config.enableGpuAcceleration, isFalse);
      expect(config.optimizeForSpeed, isFalse);
      expect(config.previewResolution, equals(PreviewResolution.high));
      expect(config.focusMode, equals(FocusMode.continuous));
      expect(config.enableMultiScanning, isTrue);
      expect(config.torchEnabled, isTrue);
    });

    test('ScanStats creation and properties', () {
      const stats = ScanStats(
        totalScans: 100,
        successfulScans: 95,
        averageProcessingTime: 42.5,
        successRate: 95.0,
        framesPerSecond: 30,
      );

      expect(stats.totalScans, equals(100));
      expect(stats.successfulScans, equals(95));
      expect(stats.averageProcessingTime, equals(42.5));
      expect(stats.successRate, equals(95.0));
      expect(stats.framesPerSecond, equals(30));
    });

    test('ScanStats fromMap conversion', () {
      final map = {
        'totalScans': 50,
        'successfulScans': 48,
        'averageProcessingTime': 35.2,
        'successRate': 96.0,
        'framesPerSecond': 25,
      };

      final stats = ScanStats.fromMap(map);

      expect(stats.totalScans, equals(50));
      expect(stats.successfulScans, equals(48));
      expect(stats.averageProcessingTime, equals(35.2));
      expect(stats.successRate, equals(96.0));
      expect(stats.framesPerSecond, equals(25));
    });

    test('BarcodeFormat enum values', () {
      expect(BarcodeFormat.values.length, greaterThan(5));
      expect(BarcodeFormat.values.contains(BarcodeFormat.qr), isTrue);
      expect(BarcodeFormat.values.contains(BarcodeFormat.dataMatrix), isTrue);
      expect(BarcodeFormat.values.contains(BarcodeFormat.code128), isTrue);
    });

    test('PreviewResolution enum values', () {
      expect(PreviewResolution.values.length, equals(3));
      expect(PreviewResolution.values.contains(PreviewResolution.low), isTrue);
      expect(PreviewResolution.values.contains(PreviewResolution.medium), isTrue);
      expect(PreviewResolution.values.contains(PreviewResolution.high), isTrue);
    });

    test('FocusMode enum values', () {
      expect(FocusMode.values.length, equals(4));
      expect(FocusMode.values.contains(FocusMode.auto), isTrue);
      expect(FocusMode.values.contains(FocusMode.continuous), isTrue);
      expect(FocusMode.values.contains(FocusMode.manual), isTrue);
      expect(FocusMode.values.contains(FocusMode.fixed), isTrue);
    });
  });
}