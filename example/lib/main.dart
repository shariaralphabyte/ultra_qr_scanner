import 'package:flutter/material.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner.dart';

void main() {
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
  final UltraQrScanner _scanner = UltraQrScanner();
  bool _isScanning = false;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      await _scanner.initialize();
      _scanner.onCodeDetected.listen((code) {
        if (code != null) {
          setState(() {
            _lastScannedCode = code;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize scanner: $e')),
        );
      }
    }
  }

  Future<void> _startScanning() async {
    if (_isScanning) return;
    try {
      await _scanner.startScanning();
      setState(() {
        _isScanning = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start scanning: $e')),
        );
      }
    }
  }

  Future<void> _stopScanning() async {
    if (!_isScanning) return;
    try {
      await _scanner.stopScanning();
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop scanning: $e')),
        );
      }
    }
  }

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
            Text(
              'Scan QR code to see results below',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _lastScannedCode ?? 'No QR code scanned yet',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_isScanning) {
            await _stopScanning();
          } else {
            await _startScanning();
          }
        },
        child: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}
