import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner.dart';
import 'package:flutter/services.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([MethodChannel, EventChannel])
import 'ultra_qr_scanner_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UltraQrScanner', () {
    late MockMethodChannel mockMethodChannel;
    late MockEventChannel mockEventChannel;

    setUp(() {
      mockMethodChannel = MockMethodChannel();
      mockEventChannel = MockEventChannel();

      // Reset static state
      UltraQrScanner._isPrepared = false;
    });

    test('prepareScanner calls native method', () async {
      when(mockMethodChannel.invokeMethod('prepareScanner'))
          .thenAnswer((_) async => null);

      await UltraQrScanner.prepareScanner();

      verify(mockMethodChannel.invokeMethod('prepareScanner')).called(1);
      expect(UltraQrScanner.isPrepared, isTrue);
    });

    test('scanOnce throws exception when not prepared', () async {
      expect(
            () => UltraQrScanner.scanOnce(),
        throwsA(isA<UltraQrScannerException>()),
      );
    });

    test('scanOnce returns scanned result', () async {
      // Prepare first
      when(mockMethodChannel.invokeMethod('prepareScanner'))
          .thenAnswer((_) async => null);
      await UltraQrScanner.prepareScanner();

      // Mock scan result
      when(mockMethodChannel.invokeMethod('scanOnce'))
          .thenAnswer((_) async => 'https://example.com');

      final result = await UltraQrScanner.scanOnce();

      expect(result, equals('https://example.com'));
      verify(mockMethodChannel.invokeMethod('scanOnce')).called(1);
    });

    test('toggleFlash calls native method with correct parameter', () async {
      when(mockMethodChannel.invokeMethod('toggleFlash', {'enabled': true}))
          .thenAnswer((_) async => null);

      await UltraQrScanner.toggleFlash(true);

      verify(mockMethodChannel.invokeMethod('toggleFlash', {'enabled': true}))
          .called(1);
    });

    test('handles platform exceptions correctly', () async {
      when(mockMethodChannel.invokeMethod('prepareScanner'))
          .thenThrow(PlatformException(code: 'ERROR', message: 'Test error'));

      expect(
            () => UltraQrScanner.prepareScanner(),
        throwsA(isA<UltraQrScannerException>()),
      );
    });
  });

  group('Performance Tests', () {
    test('multiple prepare calls should be idempotent', () async {
      when(mockMethodChannel.invokeMethod('prepareScanner'))
          .thenAnswer((_) async => null);

      await UltraQrScanner.prepareScanner();
      await UltraQrScanner.prepareScanner();
      await UltraQrScanner.prepareScanner();

      // Should only call native method once
      verify(mockMethodChannel.invokeMethod('prepareScanner')).called(1);
    });
  });
}