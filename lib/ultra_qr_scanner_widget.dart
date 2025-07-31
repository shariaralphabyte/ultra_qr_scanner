import 'dart:async';
import 'package:flutter/material.dart';
import 'ultra_qr_scanner.dart';

class UltraQrScannerWidget extends StatefulWidget {
  final Function(String) onQrDetected;
  final Widget? overlay;
  final bool showFlashToggle;
  final bool autoStop;

  const UltraQrScannerWidget({
    Key? key,
    required this.onQrDetected,
    this.overlay,
    this.showFlashToggle = true,
    this.autoStop = true,
  }) : super(key: key);

  @override
  State<UltraQrScannerWidget> createState() => _UltraQrScannerWidgetState();
}

class _UltraQrScannerWidgetState extends State<UltraQrScannerWidget> {
  bool _isFlashOn = false;
  bool _isScanning = false;
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      if (!UltraQrScanner.isPrepared) {
        await UltraQrScanner.prepareScanner();
      }
      _startScanning();
    } catch (e) {
      debugPrint('Failed to initialize scanner: $e');
    }
  }

  void _startScanning() {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
    });

    _scanSubscription = UltraQrScanner.scanStream().listen(
          (qrCode) {
        widget.onQrDetected(qrCode);
        if (widget.autoStop) {
          _stopScanning();
        }
      },
      onError: (error) {
        debugPrint('Scan error: $error');
        setState(() {
          _isScanning = false;
        });
      },
    );
  }

  void _stopScanning() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    UltraQrScanner.stopScanner();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _toggleFlash() async {
    try {
      final newState = !_isFlashOn;
      await UltraQrScanner.toggleFlash(newState);
      setState(() {
        _isFlashOn = newState;
      });
    } catch (e) {
      debugPrint('Failed to toggle flash: $e');
    }
  }

  @override
  void dispose() {
    _stopScanning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera preview (handled natively)
        Container(
          color: Colors.black,
          child: const Center(
            child: Text(
              'Camera Preview',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),

        // Overlay
        if (widget.overlay != null) widget.overlay!,

        // Default overlay with scanning indicator
        if (widget.overlay == null) _buildDefaultOverlay(),

        // Flash toggle button
        if (widget.showFlashToggle)
          Positioned(
            top: 50,
            right: 20,
            child: IconButton(
              onPressed: _toggleFlash,
              icon: Icon(
                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
      ),
      child: Stack(
        children: [
          // Scanning frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isScanning ? Colors.green : Colors.white,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isScanning
                  ? const Center(
                child: Text(
                  'Scanning...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              )
                  : null,
            ),
          ),

          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Text(
              'Point your camera at a QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                backgroundColor: Colors.black.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}