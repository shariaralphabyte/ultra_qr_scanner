import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.showFlashToggle = false,
    this.autoStop = true,
  }) : super(key: key);

  @override
  State<UltraQrScannerWidget> createState() => _UltraQrScannerWidgetState();
}

class _UltraQrScannerWidgetState extends State<UltraQrScannerWidget> {
  bool _isScanning = false;
  bool _isPrepared = false;
  bool _hasPermission = false;
  bool _isFlashOn = false;
  String _currentCamera = 'back';
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      _hasPermission = await UltraQrScanner.requestPermissions();
      if (_hasPermission) {
        await UltraQrScanner.prepareScanner();
        setState(() {
          _isPrepared = true;
        });
      } else {
        // Handle permission denied
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize scanner: $e')),
        );
      }
    }
  }

  Future<void> _startScanning() async {
    if (!_isPrepared || !_hasPermission) return;

    try {
      setState(() {
        _isScanning = true;
      });

      // Start continuous scanning stream
      _scanSubscription = UltraQrScanner.scanStream().listen(
        (qrCode) {
          if (mounted) {
            widget.onQrDetected(qrCode);
            if (widget.autoStop) {
              _stopScanning();
            }
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
      );

      // Start the scanner
      await UltraQrScanner.scanOnce();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanner error: $e')),
        );
      }
    }
  }

  Future<void> _stopScanning() async {
    if (!_isScanning) return;
    try {
      await _scanSubscription?.cancel();
      await UltraQrScanner.stopScanner();
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stop error: $e')),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    try {
      await UltraQrScanner.toggleFlash(!_isFlashOn);
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Flash error: $e')),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    try {
      final newPosition = _currentCamera == 'back' ? 'front' : 'back';
      await UltraQrScanner.switchCamera(newPosition);
      setState(() {
        _currentCamera = newPosition;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera switch error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Camera preview placeholder - in a real implementation this would be a platform view
          Container(
            color: Colors.black,
            child: Center(
              child: _isPrepared && _hasPermission
                  ? const Text(
                      'Camera Preview',
                      style: TextStyle(color: Colors.white),
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
          
          // Overlay
          if (widget.overlay != null)
            widget.overlay!
          else
            _buildDefaultOverlay(),
          
          // Controls
          if (_isPrepared && _hasPermission)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.showFlashToggle)
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                        ),
                        onPressed: _toggleFlash,
                      ),
                    IconButton(
                      icon: Icon(
                        _currentCamera == 'back' ? Icons.camera_rear : Icons.camera_front,
                        color: Colors.white,
                      ),
                      onPressed: _switchCamera,
                    ),
                  ],
                ),
              ),
            ),
          
          // Start/Stop button
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _isScanning ? _stopScanning : _startScanning,
                child: Text(_isScanning ? 'Stop' : 'Start Scan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDefaultOverlay() {
    return Stack(
      children: [
        // Semi-transparent background
        Container(color: Colors.black54),
        
        // Scanning area cutout
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        
        // Instructions
        const Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Text(
            'Align QR code within the frame',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    if (_isScanning) {
      _stopScanning();
    }
    super.dispose();
  }
}