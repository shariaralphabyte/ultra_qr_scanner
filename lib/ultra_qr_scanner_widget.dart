import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ultra_qr_scanner.dart';

class UltraQrScannerWidget extends StatefulWidget {
  final Function(String) onQRDetected;
  final bool continuousScan;
  final bool autoStop;

  const UltraQrScannerWidget({
    Key? key,
    required this.onQRDetected,
    this.continuousScan = false,
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
  PlatformViewLink? _platformViewLink;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    try {
      _hasPermission = await UltraQrScanner.requestPermissions();
      if (_hasPermission) {
        await UltraQrScanner.prepareScanner();
        setState(() {
          _isPrepared = true;
        });
      }
    } catch (e) {
      print('Permission error: $e');
    }
  }

  Future<void> _startScanner() async {
    if (!_isPrepared || !_hasPermission) return;

    try {
      setState(() {
        _isScanning = true;
      });

      if (widget.continuousScan) {
        final stream = UltraQrScanner.startScanStream();
        stream.listen(
          (qrCode) {
            if (mounted) {
              setState(() {
                _isScanning = widget.autoStop ? false : true;
              });
              widget.onQRDetected(qrCode);
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _isScanning = false;
              });
              print('Scan error: $error');
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
      } else {
        final qrCode = await UltraQrScanner.scanOnce();
        if (qrCode != null && mounted) {
          widget.onQRDetected(qrCode);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
      print('Scanner error: $e');
    }
  }

  Future<void> _stopScanner() async {
    if (!_isScanning) return;
    try {
      await UltraQrScanner.stopScanner();
      setState(() {
        _isScanning = false;
      });
    } catch (e) {
      print('Stop error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    try {
      await UltraQrScanner.toggleFlash(!_isFlashOn);
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      print('Flash error: $e');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await UltraQrScanner.switchCamera(_currentCamera == 'back' ? 'front' : 'back');
      setState(() {
        _currentCamera = _currentCamera == 'back' ? 'front' : 'back';
      });
    } catch (e) {
      print('Camera switch error: $e');
    }
  }

  Widget _buildCameraPreview() {
    if (!_isPrepared || !_hasPermission) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_platformViewLink == null) {
      _platformViewLink = PlatformViewLink(
        viewType: 'ultra_qr_scanner_preview',
        surfaceFactory: (
          BuildContext context,
          PlatformViewController controller,
        ) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (PlatformViewCreationParams params) {
          return PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: 'ultra_qr_scanner_preview',
            layoutDirection: TextDirection.ltr,
            creationParams: <String, dynamic>{
              'cameraPosition': _currentCamera,
            },
            creationParamsCodec: const StandardMessageCodec(),
          )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..create();
        },
      );
    }

    return PlatformViewLinkWidget(link: _platformViewLink!);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          _buildCameraPreview(),
          if (_isPrepared && _hasPermission)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _isScanning ? _stopScanner : _startScanner,
                child: Text(_isScanning ? 'Stop' : 'Start Scan'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _platformViewLink?.dispose();
    if (_isScanning) {
      _stopScanner();
    }
    super.dispose();
  }
}