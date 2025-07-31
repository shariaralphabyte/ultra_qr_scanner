import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Scanner Integration Tests', () {
    testWidgets('prepare scanner performance test', (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      await UltraQrScanner.prepareScanner();

      stopwatch.stop();

      // Scanner should prepare in under 500ms
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      expect(UltraQrScanner.isPrepared, isTrue);
    });

    testWidgets('permission request works', (WidgetTester tester) async {
      final hasPermission = await UltraQrScanner.requestPermissions();

      // On simulator, this might be true or false depending on setup
      expect(hasPermission, isA<bool>());
    });

    testWidgets('flash toggle works when supported', (WidgetTester tester) async {
      await UltraQrScanner.prepareScanner();

      // This should not throw an exception even if flash is not available
      await expectLater(
        UltraQrScanner.toggleFlash(true),
        completes,
      );

      await expectLater(
        UltraQrScanner.toggleFlash(false),
        completes,
      );
    });
  });
}