# Ultra QR Scanner

[![pub package](https://img.shields.io/pub/v/ultra_qr_scanner.svg)](https://pub.dev/packages/ultra_qr_scanner)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ultra-fast QR code scanner plugin for Flutter with native performance optimization. Designed for professional applications requiring instant QR code detection and processing, similar to the bKash app experience.

## 🚀 Features

- **⚡ Ultra-Fast Scanning**: Optimized native code for instant QR detection
- **🔧 Professional Grade**: Built for production apps with reliability focus
- **📱 Native Performance**: Platform-specific optimizations for iOS and Android
- **🎯 GPU Acceleration**: Hardware acceleration support for maximum speed
- **📊 Performance Monitoring**: Real-time statistics and metrics
- **🔦 Advanced Camera Controls**: Torch, focus, and exposure controls
- **📋 Multiple Formats**: Support for QR, DataMatrix, Code128, and more
- **🎨 Customizable UI**: Flexible overlay and styling options
- **🔄 Continuous Scanning**: Option for multiple scans without restart

## 🎯 Performance Benchmarks

- **Scan Speed**: < 100ms average processing time
- **Detection Rate**: 99%+ success rate in optimal conditions
- **Frame Rate**: 30+ FPS with real-time processing
- **Memory Usage**: Optimized for minimal memory footprint
- **Battery Efficient**: Intelligent resource management

## 📱 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  ultra_qr_scanner: ^1.0.0
```

Run the following command:

```bash
flutter pub get
```

## 🔧 Platform Setup

### Android

Add camera permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
<uses-feature android:name="android.hardware.camera.autofocus" />
```

Minimum SDK version: 21

### iOS

Add camera usage description to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan QR codes</string>
```

Minimum iOS version: 12.0

## 🚀 Quick Start

### Basic Usage

```dart
import 'package:ultra_qr_scanner/ultra_qr_scanner.dart';

class ScannerPage extends StatefulWidget {
  @override
  _ScannerPageState createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    final config = ScanConfig(
      enableGpuAcceleration: true,
      optimizeForSpeed: true,
      previewResolution: PreviewResolution.medium,
    );

    await UltraQrScanner.initialize(config: config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: UltraQrScannerWidget(
        onScan: (result) {
          print('Scanned: ${result.data}');
          print('Processing time: ${result.processingTimeMs}ms');
        },
        onError: (error) {
          print('Error: $error');
        },
      ),
    );
  }
}
```

### Advanced Configuration

```dart
// Ultra-fast configuration (like bKash)
final speedConfig = ScanConfig(
  enableGpuAcceleration: true,
  optimizeForSpeed: true,
  previewResolution: PreviewResolution.low, // Fastest
  focusMode: FocusMode.continuous,
  enableMultiScanning: false,
);

// High-quality configuration
final qualityConfig = ScanConfig(
  enableGpuAcceleration: true,
  optimizeForSpeed: false,
  previewResolution: PreviewResolution.high,
  focusMode: FocusMode.auto,
  enableMultiScanning: true,
);

await UltraQrScanner.initialize(config: speedConfig);
```

### Custom Overlay

```dart
UltraQrScannerWidget(
  onScan: _onScan,
  overlay: CustomScannerOverlay(),
  showTorchButton: true,
  showFocusIndicator: true,
  formats: [BarcodeFormat.qr, BarcodeFormat.dataMatrix],
  continuousScanning: false,
)
```

### Manual Controls

```dart
// Toggle torch/flashlight
bool torchEnabled = await UltraQrScanner.toggleTorch();

// Focus at specific point
await UltraQrScanner.focusAt(0.5, 0.5); // Center of screen

// Check torch availability
bool hasTorch = await UltraQrScanner.hasTorch();

// Get performance statistics
ScanStats? stats = await UltraQrScanner.getStats();
print('Success rate: ${stats?.successRate}%');
print('Average processing time: ${stats?.averageProcessingTime}ms');
```

## 📊 Performance Monitoring

Monitor scanning performance in real-time:

```dart
class PerformanceMonitor extends StatefulWidget {
  @override
  _PerformanceMonitorState createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  ScanStats? stats;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (_) => _updateStats());
  }

  Future<void> _updateStats() async {
    final newStats = await UltraQrScanner.getStats();
    setState(() => stats = newStats);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Success Rate: ${stats?.successRate.toStringAsFixed(1)}%'),
        Text('Avg Time: ${stats?.averageProcessingTime.toStringAsFixed(1)}ms'),
        Text('FPS: ${stats?.framesPerSecond}'),
        Text('Total Scans: ${stats?.totalScans}'),
      ],
    );
  }
}
```

## 🎨 Customization

### Custom Scanner Overlay

```dart
class CustomScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Semi-transparent background
        Container(color: Colors.black54),
        
        // Scanning area
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        
        // Instructions
        Positioned(
          bottom: 100,
          left: 20,
          right: 20,
          child: Text(
            'Position QR code within the frame',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
```

### Supported Formats

```dart
enum BarcodeFormat {
  qr,           // QR Code (fastest)
  dataMatrix,   // Data Matrix
  code128,      // Code 128
  code39,       // Code 39
  code93,       // Code 93
  ean8,         // EAN-8
  ean13,        // EAN-13
  upca,         // UPC-A
  upce,         // UPC-E
  pdf417,       // PDF417
  aztec,        // Aztec
}
```

## 🔧 Configuration Options

### ScanConfig

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enableGpuAcceleration` | `bool` | `true` | Enable hardware acceleration |
| `optimizeForSpeed` | `bool` | `true` | Prioritize speed over quality |
| `previewResolution` | `PreviewResolution` | `medium` | Camera preview resolution |
| `focusMode` | `FocusMode` | `auto` | Camera focus mode |
| `enableMultiScanning` | `bool` | `false` | Allow multiple simultaneous scans |
| `torchEnabled` | `bool` | `false` | Start with torch enabled |

### PreviewResolution

- `low` (480p) - Fastest performance
- `medium` (720p) - Balanced quality/speed
- `high` (1080p) - Best quality

### FocusMode

- `auto` - Single autofocus
- `continuous` - Continuous autofocus (recommended)
- `manual` - Manual focus control
- `fixed` - Fixed focus

## 📈 Performance Tips

1. **Use QR format only** for maximum speed
2. **Enable GPU acceleration** on supported devices
3. **Choose low resolution** for speed-critical apps
4. **Use continuous focus mode** for moving targets
5. **Disable multi-scanning** unless needed
6. **Monitor statistics** to optimize performance

## 🐛 Troubleshooting

### Common Issues

**Slow scanning performance:**
- Enable GPU acceleration
- Use lower preview resolution
- Focus on QR format only

**Camera permission denied:**
- Check platform-specific permission setup
- Request permissions at runtime

**High memory usage:**
- Use appropriate preview resolution
- Dispose scanner when not needed

**Focus issues:**
- Use continuous focus mode
- Ensure adequate lighting

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Credits

- Built with ❤️ for the Flutter community
- Inspired by high-performance apps like bKash
- Uses ML Kit (Android) and Vision (iOS) for detection

## 📞 Support

For issues and feature requests, please [create an issue](https://github.com/shariaralphabyte/ultra_qr_scanner/issues) on GitHub.

---

**Made with ⚡ by developers, for developers**