import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner.dart';
import 'ultra_qr_scanner_test.mocks.dart';

@GenerateMocks([MethodChannel, EventChannel])
void main() {
  late MockMethodChannel mockMethodChannel;
  late MockEventChannel mockEventChannel;
  late UltraQrScanner scanner;

  setUp(() {
    mockMethodChannel = MockMethodChannel();
    mockEventChannel = MockEventChannel();
    scanner = UltraQrScanner(
      methodChannel: mockMethodChannel,
      eventChannel: mockEventChannel,
    );
  });

  test('prepareScanner should prepare scanner', () async {
    when(mockMethodChannel.invokeMethod('prepareScanner'))
        .thenAnswer((_) async => null);

    await scanner.prepareScanner();
    expect(scanner.isPrepared, isTrue);

    verify(mockMethodChannel.invokeMethod('prepareScanner')).called(1);
  });

  test('scanOnce should scan QR code', () async {
    // Prepare scanner first
    when(mockMethodChannel.invokeMethod('prepareScanner'))
        .thenAnswer((_) async => null);
    await scanner.prepareScanner();

    const testCode = 'test-qr-code';
    when(mockMethodChannel.invokeMethod('scanOnce'))
        .thenAnswer((_) async => testCode);

    final result = await scanner.scanOnce();
    expect(result, equals(testCode));

    verify(mockMethodChannel.invokeMethod('scanOnce')).called(1);
  });

  test('startScanStream should start scanning stream', () async {
    // Prepare scanner first
    when(mockMethodChannel.invokeMethod('prepareScanner'))
        .thenAnswer((_) async => null);
    await scanner.prepareScanner();

    when(mockEventChannel.receiveBroadcastStream())
        .thenAnswer((_) => Stream.value('test-qr-code'));

    final stream = scanner.startScanStream();
    expect(stream, emits('test-qr-code'));

    verify(mockEventChannel.receiveBroadcastStream()).called(1);
  });

  test('stopScanner should stop scanner', () async {
    when(mockMethodChannel.invokeMethod('stopScanner'))
        .thenAnswer((_) async => null);

    await scanner.stopScanner();
    expect(scanner.isPrepared, isFalse);

    verify(mockMethodChannel.invokeMethod('stopScanner')).called(1);
  });

  test('toggleFlash should toggle flash', () async {
    when(mockMethodChannel.invokeMethod('toggleFlash', any))
        .thenAnswer((_) async => null);

    await scanner.toggleFlash(true);
    await scanner.toggleFlash(false);

    verify(mockMethodChannel.invokeMethod('toggleFlash', captureAny)).called(2);
  });

  test('switchCamera should switch camera', () async {
    when(mockMethodChannel.invokeMethod('switchCamera', any))
        .thenAnswer((_) async => null);

    await scanner.switchCamera('front');
    await scanner.switchCamera('back');

    verify(mockMethodChannel.invokeMethod('switchCamera', captureAny)).called(2);
  });

  test('requestPermissions should request permissions', () async {
    when(mockMethodChannel.invokeMethod('requestPermissions'))
        .thenAnswer((_) async => true);

    final result = await scanner.requestPermissions();
    expect(result, isTrue);

    verify(mockMethodChannel.invokeMethod('requestPermissions')).called(1);
  });

  test('prepareScanner should throw error on failure', () async {
    when(mockMethodChannel.invokeMethod('prepareScanner'))
        .thenThrow(PlatformException(code: 'ERROR', message: 'Test error'));

    expect(scanner.prepareScanner(), throwsA(isA<UltraQrScannerException>()));
  });

  test('scanOnce should throw error on failure', () async {
    when(mockMethodChannel.invokeMethod('scanOnce'))
        .thenThrow(PlatformException(code: 'ERROR', message: 'Test error'));

    expect(scanner.scanOnce(), throwsA(isA<UltraQrScannerException>()));
  });

  test('stopScanner should throw error on failure', () async {
    when(mockMethodChannel.invokeMethod('stopScanner'))
        .thenThrow(PlatformException(code: 'ERROR', message: 'Test error'));

    expect(scanner.stopScanner(), throwsA(isA<UltraQrScannerException>()));
  });

  test('toggleFlash should throw error on failure', () async {
    when(mockMethodChannel.invokeMethod('toggleFlash', any))
        .thenThrow(PlatformException(code: 'ERROR', message: 'Test error'));

    expect(scanner.toggleFlash(true), throwsA(isA<UltraQrScannerException>()));
  });

  test('switchCamera should throw error on failure', () async {
    when(mockMethodChannel.invokeMethod('switchCamera', any))
        .thenThrow(PlatformException(code: 'ERROR', message: 'Test error'));

    expect(scanner.switchCamera('front'), throwsA(isA<UltraQrScannerException>()));
  });

  test('requestPermissions should throw error on failure', () async {
    when(mockMethodChannel.invokeMethod('requestPermissions'))
        .thenThrow(PlatformException(code: 'ERROR', message: 'Test error'));

    expect(scanner.requestPermissions(), throwsA(isA<UltraQrScannerException>()));
  });
}