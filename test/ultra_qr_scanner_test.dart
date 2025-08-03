import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner.dart';
import 'ultra_qr_scanner_test.mocks.dart';

@GenerateMocks([MethodChannel])
void main() {
  late MockMethodChannel mockMethodChannel;
  late UltraQrScanner scanner;

  setUp(() {
    mockMethodChannel = MockMethodChannel();
    MethodChannel.channelName = null; // Reset channel name
    MethodChannel.channelName = 'ultra_qr_scanner';
    EventChannel.channelName = 'ultra_qr_scanner_events';
    
    // Mock the channel methods
    when(mockMethodChannel.invokeMethod('initialize'))
        .thenAnswer((_) async => null);
    when(mockMethodChannel.invokeMethod('startScanning'))
        .thenAnswer((_) async => null);
    when(mockMethodChannel.invokeMethod('stopScanning'))
        .thenAnswer((_) async => null);
    
    scanner = UltraQrScanner();
  });

  test('initialize should initialize scanner', () async {
    await scanner.initialize();
    verify(mockMethodChannel.invokeMethod('initialize')).called(1);
  });

  test('startScanning should start scanning', () async {
    // Initialize first
    await scanner.initialize();
    
    await scanner.startScanning();
    expect(scanner._isScanning, isTrue);
    verify(mockMethodChannel.invokeMethod('startScanning')).called(1);
  });

  test('stopScanning should stop scanning', () async {
    // Initialize and start scanning first
    await scanner.initialize();
    await scanner.startScanning();
    
    await scanner.stopScanning();
    expect(scanner._isScanning, isFalse);
    verify(mockMethodChannel.invokeMethod('stopScanning')).called(1);
  });

  test('onCodeDetected should stream QR codes', () async {
    // Initialize first
    await scanner.initialize();
    
    // Mock event channel stream
    final streamController = StreamController<String?>();
    when(mockMethodChannel.invokeMethod('startScanning'))
        .thenAnswer((_) async {
          streamController.add('test-code-1');
          streamController.add('test-code-2');
          streamController.close();
        });
    
    final codes = await scanner.onCodeDetected.take(2).toList();
    expect(codes, equals(['test-code-1', 'test-code-2']));
  });

  test('initialize should throw QrScannerException on error', () async {
    when(mockMethodChannel.invokeMethod('initialize'))
        .thenThrow(PlatformException(code: 'ERROR', message: 'Test error'));
    
    expect(scanner.initialize(), throwsA(isA<QrScannerException>()));
  });

  test('startScanning should throw QrScannerException on error', () async {
    // Initialize first
    await scanner.initialize();
    
    when(mockMethodChannel.invokeMethod('startScanning'))
        .thenThrow(PlatformException(code: 'ERROR', message: 'Test error'));
    
    expect(scanner.startScanning(), throwsA(isA<QrScannerException>()));
  });

  test('stopScanning should throw QrScannerException on error', () async {
    // Initialize first
    await scanner.initialize();
    
    when(mockMethodChannel.invokeMethod('stopScanning'))
        .thenThrow(PlatformException(code: 'ERROR', message: 'Test error'));
    
    expect(scanner.stopScanning(), throwsA(isA<QrScannerException>()));
  });
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