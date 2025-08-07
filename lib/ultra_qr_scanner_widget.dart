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
  final bool showStartStopButton;
  final bool autoStart;

  const UltraQrScannerWidget({
    super.key,
    required this.onQrDetected,
    this.overlay,
    this.showFlashToggle = false,
    this.autoStop = true,
    this.showStartStopButton = true,
    this.autoStart = false,
  });

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
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      setState(() {
        _isInitializing = true;
      });

      _hasPermission = await UltraQrScanner.requestPermissions();
      if (_hasPermission) {
        await UltraQrScanner.prepareScanner();

        // Wait a moment for the platform view to be ready
        await Future.delayed(const Duration(milliseconds: 300));

        setState(() {
          _isPrepared = true;
          _isInitializing = false;
        });

        // Auto-start scanning if enabled, with additional delay
        if (widget.autoStart) {
          await Future.delayed(const Duration(milliseconds: 200));
          await _startScanning();
        }
      } else {
        setState(() {
          _isInitializing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isInitializing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize scanner: $e')),
        );
      }
    }
  }

  Future<void> _startScanning() async {
    if (!_isPrepared || !_hasPermission || _isScanning) return;

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
    // Show loading state while initializing
    if (_isInitializing || !_isPrepared || !_hasPermission) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Initializing camera...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
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
        layoutDirection: TextDirection.ltr,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        onPlatformViewCreated: (int id) {
          // Platform view is created, camera should be visible now
          if (kDebugMode) {
            print('Platform view created with id: $id');
          }
        },
      );
    } else if (Platform.isIOS) {
      platformView = UiKitView(
        viewType: 'ultra_qr_camera_view',
        creationParams: const <String, dynamic>{},
        creationParamsCodec: const StandardMessageCodec(),
        layoutDirection: TextDirection.ltr,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        onPlatformViewCreated: (int id) {
          // Platform view is created, camera should be visible now
          if (kDebugMode) {
            print('Platform view created with id: $id');
          }
        },
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

    return ClipRect(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black, // Ensure black background
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

            // Show overlay only when camera is ready
            if (_isPrepared && _hasPermission && !_isInitializing) ...[
              if (widget.overlay != null)
                widget.overlay!
              else
                _buildDefaultOverlay(),

              // Controls
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

              // Start/Stop button - only show if showStartStopButton is true
              if (widget.showStartStopButton)
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
                            color: Colors.black.withValues(alpha: 0.3),
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
          color: Colors.black.withValues(alpha: 0.5),
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
          ),
        ),


        // Status indicator
        if (_isScanning)
          Positioned(
            bottom: widget.showStartStopButton ? 80 : 40,
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