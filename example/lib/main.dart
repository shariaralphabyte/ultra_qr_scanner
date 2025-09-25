import 'package:flutter/material.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner.dart';
import 'package:ultra_qr_scanner/ultra_qr_scanner_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  bool _useAutoStart = true; // Toggle this to test different modes
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _testPermissionsAndScanner();
  }

  Future<void> _testPermissionsAndScanner() async {
    try {
      setState(() {
        _debugInfo = 'Testing permissions...';
      });
      
      final hasPermission = await UltraQrScanner.requestPermissions();
      setState(() {
        _debugInfo = 'Permission result: $hasPermission';
      });
      
      if (hasPermission) {
        setState(() {
          _debugInfo = 'Preparing scanner...';
        });
        
        await UltraQrScanner.prepareScanner();
        setState(() {
          _debugInfo = 'Scanner prepared successfully!';
        });
      }
    } catch (e) {
      setState(() {
        _debugInfo = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ultra QR Scanner'),
        actions: [
          // Toggle button to switch between auto-start and manual start modes
          IconButton(
            icon: Icon(_useAutoStart ? Icons.play_circle_filled : Icons.play_circle_outline),
            onPressed: () {
              setState(() {
                _useAutoStart = !_useAutoStart;
              });
            },
            tooltip: _useAutoStart ? 'Switch to Manual Mode' : 'Switch to Auto Mode',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _useAutoStart
                  ? 'Auto-start mode: Scanning begins automatically'
                  : 'Manual mode: Tap Start Scan button to begin',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Mode indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _useAutoStart ? Colors.green.shade100 : Colors.blue.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _useAutoStart ? Colors.green : Colors.blue,
                  width: 1,
                ),
              ),
              child: Text(
                _useAutoStart ? '🚀 AUTO START' : '👆 MANUAL START',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _useAutoStart ? Colors.green.shade800 : Colors.blue.shade800,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Debug info display
            if (_debugInfo.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: _debugInfo.contains('Error') ? Colors.red.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _debugInfo.contains('Error') ? Colors.red : Colors.blue,
                    width: 1,
                  ),
                ),
                child: Text(
                  'Debug: $_debugInfo',
                  style: TextStyle(
                    fontSize: 12,
                    color: _debugInfo.contains('Error') ? Colors.red.shade800 : Colors.blue.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 20),

            // Show scanner widget
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: UltraQrScannerWidget(
                onCodeDetected: (code , type) {
                  setState(() {
                    _lastScannedCode = code;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Scanned: $code'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                showFlashToggle: true,
                autoStop: true,
                // NEW PARAMETERS:
                showStartStopButton: !_useAutoStart, // Hide button in auto mode
                autoStart: _useAutoStart,             // Auto-start in auto mode
              ),
            ),

            const SizedBox(height: 20),

            // Results display
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Text(
                    'Last Scanned Code:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lastScannedCode ?? 'No QR code scanned yet',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Usage examples
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 Usage Modes:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('🚀 Auto-start: Scanning begins immediately'),
                  const Text('👆 Manual: User controls start/stop'),
                  const Text('⚡ Both modes auto-stop after detection'),
                  const SizedBox(height: 8),
                  Text(
                    'Current: ${_useAutoStart ? "Auto-start mode" : "Manual mode"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Example of different usage scenarios:

class AutoStartScannerPage extends StatelessWidget {
  const AutoStartScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto Scanner')),
      body: UltraQrScannerWidget(
        onCodeDetected: (code , type) {
          Navigator.pop(context, code);
        },
        showFlashToggle: true,
        autoStop: true,
        showStartStopButton: false, // Hide button
        autoStart: true,            // Auto-start scanning
      ),
    );
  }
}

class ManualScannerPage extends StatelessWidget {
  const ManualScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Scanner')),
      body: UltraQrScannerWidget(
        onCodeDetected: (code, type) {
          Navigator.pop(context, code);
        },
        showFlashToggle: true,
        autoStop: true,
        showStartStopButton: true, // Show button
        autoStart: false,          // Manual start
      ),
    );
  }
}