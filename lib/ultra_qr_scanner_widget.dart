import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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

  Widget _buildCameraPreview() {
    if (!_isPrepared || !_hasPermission) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Use platform view for Android, UiKitView for iOS
    Widget platformView;
    if (Platform.isAndroid) {
      platformView = AndroidView(
        viewType: 'ultra_qr_camera_view',
        creationParams: const <String, dynamic>{},
        creationParamsCodec: const StandardMessageCodec(),
        // Add layout direction and gesture recognizers
        layoutDirection: TextDirection.ltr,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      );
    } else if (Platform.isIOS) {
      platformView = UiKitView(
        viewType: 'ultra_qr_camera_view',
        creationParams: const <String, dynamic>{},
        creationParamsCodec: const StandardMessageCodec(),
        // Add layout direction and gesture recognizers
        layoutDirection: TextDirection.ltr,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      );
    } else {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Platform not supported',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // Wrap the platform view in proper constraints
    return ClipRect(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: platformView,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Camera preview - positioned to fill the entire container
            Positioned.fill(
              child: _buildCameraPreview(),
            ),

            // Overlay
            if (widget.overlay != null)
              widget.overlay!
            else
              _buildDefaultOverlay(),

            // Controls
            if (_isPrepared && _hasPermission)
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.showFlashToggle)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: _toggleFlash,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _currentCamera == 'back' ? Icons.camera_rear : Icons.camera_front,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: _switchCamera,
                      ),
                    ),
                  ],
                ),
              ),

            // Start/Stop button
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? _stopScanning : _startScanning,
                    icon: Icon(
                      _isScanning ? Icons.stop : Icons.play_arrow,
                      size: 20,
                    ),
                    label: Text(
                      _isScanning ? 'Stop Scan' : 'Start Scan',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScanning ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultOverlay() {
    return Stack(
      children: [
        // Semi-transparent background
        Container(
          color: Colors.black.withOpacity(0.5),
        ),

        // Scanning area cutout
        Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(
                color: _isScanning ? Colors.green : Colors.white,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _isScanning
                ? Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent),
                borderRadius: BorderRadius.circular(13),
              ),
            )
                : null,
          ),
        ),

        // Instructions
        Positioned(
          top: 40,
          left: 16,
          right: 16,
          child: Text(
            'Position QR code within the frame',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.8),
                  offset: const Offset(1, 1),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),

        // Status indicator
        if (_isScanning)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade400),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Scanning...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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