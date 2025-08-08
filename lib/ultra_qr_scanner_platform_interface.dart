import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'ultra_qr_scanner_method_channel.dart';

abstract class UltraQrScannerPlatform extends PlatformInterface {
  /// Constructs a UltraQrScannerPlatform.
  UltraQrScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static UltraQrScannerPlatform _instance = MethodChannelUltraQrScanner();

  /// The default instance of [UltraQrScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelUltraQrScanner].
  static UltraQrScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [UltraQrScannerPlatform] when
  /// they register themselves.
  static set instance(UltraQrScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> prepareScanner() {
    throw UnimplementedError('prepareScanner() has not been implemented.');
  }

  Future<String?> scanOnce() {
    throw UnimplementedError('scanOnce() has not been implemented.');
  }

  Future<void> stopScanner() {
    throw UnimplementedError('stopScanner() has not been implemented.');
  }

  Future<void> toggleFlash(bool enabled) {
    throw UnimplementedError('toggleFlash() has not been implemented.');
  }

  Future<void> switchCamera(String position) {
    throw UnimplementedError('switchCamera() has not been implemented.');
  }

  Future<bool> requestPermissions() {
    throw UnimplementedError('requestPermissions() has not been implemented.');
  }

  Stream<String> scanStream() {
    throw UnimplementedError('scanStream() has not been implemented.');
  }

  Stream<Map<String, dynamic>> scanStreamWithType() {
    throw UnimplementedError('scanStreamWithType() has not been implemented.');
  }

}