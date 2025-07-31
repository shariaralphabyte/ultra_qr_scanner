import 'dart:async';
import 'package:flutter/material.dart';
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
  _UltraQrScannerWidgetState createState() => _UltraQrScannerWidgetState();
}

class _UltraQrScannerWidgetState extends State<UltraQrScannerWidget> {
  bool _isScanning = false;
  bool _isPrepared = false;
  bool _hasPermission = false;
  bool _isFlashOn = false;
  String _currentCamera = 'back';

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
                _isScanning = false;
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

  @override
  Widget build(BuildContext context) {
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