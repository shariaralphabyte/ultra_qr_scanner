import 'package:flutter/material.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ultra QR Scanner Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _lastScannedCode;
  bool _permissionGranted = false;
  bool _isFrontCamera = false;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final granted = await UltraQrScanner.requestPermissions();
    setState(() {
      _permissionGranted = granted;
    });

    if (granted) {
      await UltraQrScanner.prepareScanner();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ultra QR Scanner Demo'),
        centerTitle: true,
      ),
      body: _permissionGranted
          ? Column(
              children: [
                if (_lastScannedCode != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last Scanned QR Code:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
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
                      const SizedBox(height: 16),
                      Row(
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
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last Scanned QR Code:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
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