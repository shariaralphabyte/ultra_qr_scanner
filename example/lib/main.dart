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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize scanner: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start scanning: $e')),
      );
    }
  }

  Future<void> _stopScanning() async {
    if (!_isScanning) return;
    try {
      await UltraQrScanner().stopScanning();
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop scan: $e')),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (!_hasPermission) return;

    try {
      await UltraQrScanner().toggleFlash();
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle flash: $e')),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (!_hasPermission) return;

    try {
      await UltraQrScanner().switchCamera();
      setState(() {
        _currentCamera = _currentCamera == 'back' ? 'front' : 'back';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to switch camera: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
          ),
          IconButton(
            icon: Icon(_currentCamera == 'back' ? Icons.camera_rear : Icons.camera_front),
            onPressed: _switchCamera,
          ),
        ],
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
              child: TextField(
                controller: _qrCodeController,
                decoration: const InputDecoration(
                  labelText: 'Scanned QR Code',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_isScanning) {
            _stopScan();
          } else {
            _startScan();
          }
            });
          },
        ),
      ),
    );
  }
}

class ContinuousScannerPage extends StatelessWidget {
  final Function(String) onQrDetected;

  const ContinuousScannerPage({
    Key? key,
    required this.onQrDetected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: UltraQrScannerWidget(
        onQrDetected: (qrCode) {
          onQrDetected(qrCode);
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scanned: $qrCode'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }
}