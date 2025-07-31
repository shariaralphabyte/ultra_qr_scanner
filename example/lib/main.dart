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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: UltraQrScannerWidget(
              onQRDetected: _onQRDetected,
              continuousScan: true,
              autoStop: true,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastScannedCode!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('Front Camera'),
                    trailing: Switch(
                      value: _isFrontCamera,
                      onChanged: (value) async {
                        if (_permissionGranted) {
                          try {
                            await UltraQrScanner.switchCamera(value ? 'front' : 'back');
                            setState(() => _isFrontCamera = value);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('Flash'),
                    trailing: Switch(
                      value: _isFlashOn,
                      onChanged: (value) async {
                        if (_permissionGranted) {
                          try {
                            await UltraQrScanner.toggleFlash(value);
                            setState(() => _isFlashOn = value);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _scanOnce,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan Once'),
                ),
                ElevatedButton.icon(
                  onPressed: _openContinuousScanner,
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: const Text('Continuous Scan'),
                ),
              ],
            ),
          ),
        ],
      )
          : const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Camera permission required'),
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