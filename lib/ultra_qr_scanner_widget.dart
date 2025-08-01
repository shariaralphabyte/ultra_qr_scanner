import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ultra_qr_scanner.dart';

/// Ultra-fast QR scanner widget with native camera preview
class UltraQrScannerWidget extends StatefulWidget {
  final Function(QrScanResult result) onScan;
  final Function(String error)? onError;
  final ScanConfig? config;
  final List<BarcodeFormat>? formats;
  final bool continuousScanning;
  final Widget? overlay;
  final bool showTorchButton;
  final bool showFocusIndicator;

  const UltraQrScannerWidget({
    Key? key,
    required this.onScan,
    this.onError,
    this.config,
    this.formats,
    this.continuousScanning = false,
    this.overlay,
    this.showTorchButton = true,
    this.showFocusIndicator = true,
  }) : super(key: key);

  @override
  State<UltraQrScannerWidget> createState() => _UltraQrScannerWidgetState();
}

class _UltraQrScannerWidgetState extends State<UltraQrScannerWidget>
    with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('ultra_qr_scanner');
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _torchEnabled = false;
  bool _hasTorch = false;
  Point? _focusPoint;
  Timer? _focusTimer;
  StreamSubscription<QrScanResult>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _scanSubscription?.cancel();
    UltraQrScanner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _pauseScanning();
        break;
      case AppLifecycleState.resumed:
        _resumeScanning();
        break;
      default:
        break;
    }
  }

  Future<void> _initializeScanner() async {
    try {
      final initialized = await UltraQrScanner.initialize(config: widget.config);
      if (initialized) {
        _hasTorch = await UltraQrScanner.hasTorch();
        setState(() => _isInitialized = true);
        _startScanning();
      }
    } catch (e) {
      widget.onError?.call('Failed to initialize scanner: $e');
    }
  }

  void _startScanning() {
    if (_isScanning) return;

    setState(() => _isScanning = true);

    _scanSubscription = UltraQrScanner.startScanning(
      formats: widget.formats,
      continuousScanning: widget.continuousScanning,
    ).listen(
          (result) {
        HapticFeedback.lightImpact();
        widget.onScan(result);

        if (!widget.continuousScanning) {
          setState(() => _isScanning = false);
        }
      },
      onError: (error) {
        widget.onError?.call('Scanning error: $error');
      },
    );
  }

  void _pauseScanning() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    UltraQrScanner.stopScanning();
    setState(() => _isScanning = false);
  }

  void _resumeScanning() {
    if (_isInitialized) {
      _startScanning();
    }
  }

  Future<void> _toggleTorch() async {
    final enabled = await UltraQrScanner.toggleTorch();
    setState(() => _torchEnabled = enabled);
  }

  void _onTapFocus(TapUpDetails details) {
    if (!widget.showFocusIndicator) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final x = localPosition.dx / renderBox.size.width;
    final y = localPosition.dy / renderBox.size.height;

    UltraQrScanner.focusAt(x, y);

    setState(() => _focusPoint = Point(localPosition.dx, localPosition.dy));

    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _focusPoint = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        // Native camera preview
        GestureDetector(
          onTapUp: _onTapFocus,
          child: Platform.isAndroid
              ? const AndroidView(
            viewType: 'ultra_qr_scanner_view',
            creationParams: <String, dynamic>{},
            creationParamsCodec: StandardMessageCodec(),
          )
              : const UiKitView(
            viewType: 'ultra_qr_scanner_view',
            creationParams: <String, dynamic>{},
            creationParamsCodec: StandardMessageCodec(),
          ),
        ),

        // Custom overlay
        if (widget.overlay != null) widget.overlay!,

        // Default scanning overlay
        if (widget.overlay == null) _buildDefaultOverlay(),

        // Torch button
        if (widget.showTorchButton && _hasTorch)
          Positioned(
            top: 50,
            right: 20,
            child: _buildTorchButton(),
          ),

        // Focus indicator
        if (widget.showFocusIndicator && _focusPoint != null)
          Positioned(
            left: _focusPoint!.x - 30,
            top: _focusPoint!.y - 30,
            child: _buildFocusIndicator(),
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
          // Scanning area cutout
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),

          // Scanning animation
          if (_isScanning)
            Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: _buildScanningAnimation(),
              ),
            ),

          // Instructions
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: const Text(
              'Point your camera at a QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningAnimation() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return CustomPaint(
          painter: ScanLinePainter(value),
        );
      },
      onEnd: () {
        if (_isScanning && mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildTorchButton() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25),
      ),
      child: IconButton(
        icon: Icon(
          _torchEnabled ? Icons.flash_on : Icons.flash_off,
          color: Colors.white,
          size: 24,
        ),
        onPressed: _toggleTorch,
      ),
    );
  }

  Widget _buildFocusIndicator() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.0),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for scanning line animation
class ScanLinePainter extends CustomPainter {
  final double progress;

  ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final y = size.height * progress;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}