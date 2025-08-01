import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        useMaterial3: true,
      ),
      home: const ScannerPage(),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({Key? key}) : super(key: key);

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  String? scannedData;
  bool isScanning = false;
  ScanStats? stats;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    // Configure for maximum performance
    final config = ScanConfig(
      enableGpuAcceleration: true,
      optimizeForSpeed: true,
      previewResolution: PreviewResolution.medium,
      focusMode: FocusMode.continuous,
    );

    final initialized = await UltraQrScanner.initialize(config: config);
    if (initialized) {
      setState(() => isScanning = true);
    }
  }

  void _onScan(QrScanResult result) {
    setState(() {
      scannedData = result.data;
    });

    // Show scan result
    _showScanResult(result);

    // Get updated statistics
    _updateStats();
  }

  void _onError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _updateStats() async {
    final newStats = await UltraQrScanner.getStats();
    setState(() {
      stats = newStats;
    });
  }

  void _showScanResult(QrScanResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Code Scanned'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data: ${result.data}'),
            const SizedBox(height: 8),
            Text('Format: ${result.format.name}'),
            const SizedBox(height: 8),
            Text('Processing Time: ${result.processingTimeMs}ms'),
            const SizedBox(height: 8),
            Text('Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result.data));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ultra QR Scanner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showStats,
          ),
        ],
      ),
      body: Column(
        children: [
          // Performance banner
          if (stats != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.green.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Success Rate', '${stats!.successRate.toStringAsFixed(1)}%'),
                  _buildStatItem('Avg Time', '${stats!.averageProcessingTime.toStringAsFixed(1)}ms'),
                  _buildStatItem('FPS', '${stats!.framesPerSecond}'),
                ],
              ),
            ),

          // Scanner view
          Expanded(
            child: isScanning
                ? UltraQrScannerWidget(
              onScan: _onScan,
              onError: _onError,
              continuousScanning: false,
              formats: [BarcodeFormat.qr],
              overlay: _buildCustomOverlay(),
            )
                : const Center(
              child: CircularProgressIndicator(),
            ),
          ),

          // Last scanned data
          if (scannedData != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last Scanned:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scannedData!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFeatures,
        child: const Icon(Icons.info),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomOverlay() {
    return Stack(
      children: [
        // Dark overlay with cutout
        Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Corner brackets
                  ...List.generate(4, (index) => _buildCornerBracket(index)),

                  // Center focus dot
                  const Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Instructions
        const Positioned(
          bottom: 120,
          left: 20,
          right: 20,
          child: Column(
            children: [
              Text(
                'Ultra Fast Scanning',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Point your camera at a QR code for instant detection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCornerBracket(int corner) {
    final positions = [
      {'top': 8.0, 'left': 8.0}, // Top-left
      {'top': 8.0, 'right': 8.0}, // Top-right
      {'bottom': 8.0, 'left': 8.0}, // Bottom-left
      {'bottom': 8.0, 'right': 8.0}, // Bottom-right
    ];

    return Positioned(
      top: positions[corner]['top'],
      left: positions[corner]['left'],
      right: positions[corner]['right'],
      bottom: positions[corner]['bottom'],
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: corner < 2 ? const BorderSide(color: Colors.green, width: 4) : BorderSide.none,
            bottom: corner >= 2 ? const BorderSide(color: Colors.green, width: 4) : BorderSide.none,
            left: corner % 2 == 0 ? const BorderSide(color: Colors.green, width: 4) : BorderSide.none,
            right: corner % 2 == 1 ? const BorderSide(color: Colors.green, width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  void _showStats() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Performance Statistics'),
        content: stats != null
            ? Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Scans: ${stats!.totalScans}'),
            Text('Successful Scans: ${stats!.successfulScans}'),
            Text('Success Rate: ${stats!.successRate.toStringAsFixed(1)}%'),
            Text('Average Processing Time: ${stats!.averageProcessingTime.toStringAsFixed(1)}ms'),
            Text('Current FPS: ${stats!.framesPerSecond}'),
          ],
        )
            : const Text('No statistics available'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFeatures() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ultra QR Scanner Features'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Ultra-fast scanning like bKash app'),
            SizedBox(height: 8),
            Text('✅ Native performance optimization'),
            SizedBox(height: 8),
            Text('✅ GPU acceleration support'),
            SizedBox(height: 8),
            Text('✅ Advanced camera controls'),
            SizedBox(height: 8),
            Text('✅ Real-time performance statistics'),
            SizedBox(height: 8),
            Text('✅ Professional-grade reliability'),
            SizedBox(height: 8),
            Text('✅ Multiple barcode format support'),
            SizedBox(height: 8),
            Text('✅ Torch/flashlight control'),
            SizedBox(height: 8),
            Text('✅ Focus point control'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    UltraQrScanner.dispose();
    super.dispose();
  }
}