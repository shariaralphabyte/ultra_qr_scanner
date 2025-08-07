import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ultra_qr_scanner_platform_interface.dart';

/// An implementation of [UltraQrScannerPlatform] that uses method channels.
class MethodChannelUltraQrScanner extends UltraQrScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ultra_qr_scanner');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<bool> prepareScanner() async {
    final result = await methodChannel.invokeMethod<bool>('prepareScanner');
    return result ?? false;
  }

  @override
  Future<String?> scanOnce() async {
    final result = await methodChannel.invokeMethod<String?>('scanOnce');
    return result;
  }

  @override
  Future<void> stopScanner() async {
    await methodChannel.invokeMethod<void>('stopScanner');
  }

  @override
  Future<void> toggleFlash(bool enabled) async {
    await methodChannel.invokeMethod<void>('toggleFlash', {'enabled': enabled});
  }

  @override
  Future<void> switchCamera(String position) async {
    await methodChannel.invokeMethod<void>('switchCamera', {'position': position});
  }

  @override
  Future<bool> requestPermissions() async {
    final result = await methodChannel.invokeMethod<bool>('requestPermissions');
    return result ?? false;
  }
}
