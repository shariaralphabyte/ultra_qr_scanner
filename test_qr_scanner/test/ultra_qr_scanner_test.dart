import 'package:flutter_test/flutter_test.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner_platform_interface.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockUltraQrScannerPlatform extends MethodChannelUltraQrScanner {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final UltraQrScannerPlatform initialPlatform = UltraQrScannerPlatform.instance;

  test('$MethodChannelUltraQrScanner is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelUltraQrScanner>());
  });

  test('getPlatformVersion', () async {
    UltraQrScannerPlatform.instance = MockUltraQrScannerPlatform();
    expect(await UltraQrScanner().getPlatformVersion(), '42');
  });
  
  test('UltraQrScanner methods exist', () {
    // Test that the API methods exist
    expect(UltraQrScanner.prepareScanner, isA<Function>());
    expect(UltraQrScanner.scanOnce, isA<Function>());
    expect(UltraQrScanner.scanStream, isA<Function>());
    expect(UltraQrScanner.stopScanner, isA<Function>());
    expect(UltraQrScanner.toggleFlash, isA<Function>());
    expect(UltraQrScanner.switchCamera, isA<Function>());
    expect(UltraQrScanner.requestPermissions, isA<Function>());
  });
}