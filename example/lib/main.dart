import 'package:flutter/material.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request camera permission and prepare scanner during app startup
  final hasPermission = await UltraQrScanner.requestPermissions();
  if (hasPermission) {
    await UltraQrScanner.prepareScanner();
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ultra QR Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _lastScannedCode;
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ultra QR Scanner'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Scan QR code to see results below',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            // Show scanner widget
            SizedBox(
              width: 300,
              height: 300,
              child: UltraQrScannerWidget(
                onQrDetected: (code) {
                  setState(() {
                    _lastScannedCode = code;
                    _isScanning = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Scanned: $code'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                showFlashToggle: true,
                autoStop: true,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _lastScannedCode ?? 'No QR code scanned yet',
              style: const TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
