import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'ultra_qr_scanner_platform_interface.dart';

/// An implementation of [UltraQrScannerPlatform] that uses method channels.
class MethodChannelUltraQrScanner extends UltraQrScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ultra_qr_scanner');

  /// The event channel used for continuous scanning stream.
  @visibleForTesting
  final eventChannel = const EventChannel('ultra_qr_scanner_events');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<bool> prepareScanner() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('prepareScanner');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> scanOnce() async {
    try {
      final result = await methodChannel.invokeMethod<String?>('scanOnce');
      return result;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> stopScanner() async {
    try {
      await methodChannel.invokeMethod<void>('stopScanner');
    } catch (e) {
      // Handle error silently or throw custom exception
    }
  }

  @override
  Future<void> toggleFlash(bool enabled) async {
    try {
      await methodChannel.invokeMethod<void>('toggleFlash', {'enabled': enabled});
    } catch (e) {
      throw Exception('Failed to toggle flash: $e');
    }
  }

  @override
  Future<void> switchCamera(String position) async {
    try {
      await methodChannel.invokeMethod<void>('switchCamera', {'position': position});
    } catch (e) {
      throw Exception('Failed to switch camera: $e');
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<String> scanStream() {
    return eventChannel.receiveBroadcastStream().map((event) => event as String);
  }
}