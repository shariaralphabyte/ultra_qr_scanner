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
      title: 'Ultra QR Scanner Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Ultra QR Scanner Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _qrCodeController = TextEditingController();
  bool _isScanning = false;
  bool _isFlashOn = false;
  String _currentCamera = 'back';
  late UltraQrScanner _scanner;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _qrCodeController.addListener(() {
      if (_qrCodeController.text.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanned: ${_qrCodeController.text}')),
        );
      }
    });
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      _scanner = UltraQrScanner(
        methodChannel: MethodChannel('ultra_qr_scanner'),
        eventChannel: EventChannel('ultra_qr_scanner_events'),
      );
      _hasPermission = await _scanner.requestPermissions();
      if (_hasPermission) {
        await _scanner.prepareScanner();
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize scanner: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _qrCodeController.dispose();
    super.dispose();
  }

  void _onQRDetected(String qrCode) {
    setState(() {
      _qrCodeController.text = qrCode;
    });
  }

  Future<void> _startScan() async {
    if (!_hasPermission) return;

    try {
      setState(() {
        _isScanning = true;
      });

      final stream = _scanner.startScanStream();
      stream.listen(
        (qrCode) {
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
            _onQRDetected(qrCode);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Scan error: $error')),
            );
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start scan: $e')),
        );
      }
    }
  }

  Future<void> _stopScan() async {
    if (!_isScanning) return;
    try {
      await _scanner.stopScanner();
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
      await _scanner.toggleFlash(!_isFlashOn);
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
      await _scanner.switchCamera(_currentCamera == 'back' ? 'front' : 'back');
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
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Camera permission required'),
              ElevatedButton.icon(
                onPressed: _initializeScanner,
                icon: Icon(Icons.refresh),
                label: Text('Request Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('Camera preview will be shown here'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _qrCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Scanned QR Code',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  readOnly: true,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isScanning ? _stopScan : _startScan,
                      icon: Icon(_isScanning ? Icons.stop : Icons.qr_code_scanner_outlined),
                      label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _toggleFlash,
                      icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
                      label: Text(_isFlashOn ? 'Flash On' : 'Flash Off'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _switchCamera,
                      icon: Icon(Icons.switch_camera),
                      label: Text(_currentCamera == 'back' ? 'Front Camera' : 'Back Camera'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
          ],
        ),
      ),
    );
  }

  Future<void> _scanOnce() async {
    try {
      final result = await UltraQrScanner.scanOnce();
      if (result != null) {
        setState(() {
          _lastScannedCode = result;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  void _openContinuousScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ContinuousScannerPage(
          onQrDetected: (qrCode) {
            setState(() {
              _lastScannedCode = qrCode;
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