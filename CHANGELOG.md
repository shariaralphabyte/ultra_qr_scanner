# Changelog
## 3.0.0
* **MAJOR RELEASE**: Added comprehensive barcode scanning support
* **Auto-Detection**: Automatically detects and scans both QR codes and barcodes without mode switching
* **Multi-Format Support**: Added support for 12 additional barcode formats:
  - Code 128, Code 39, Code 93
  - EAN-13, EAN-8, UPC-A, UPC-E
  - Codabar, ITF, PDF417, Data Matrix, Aztec
* **Type Detection**: New callback signature `onCodeDetected(String code, String type)` returns format type
* **Enhanced Native Performance**: Same ultra-fast scanning for all formats using MLKit (Android) and Vision (iOS)
* **Backward Compatible**: Existing QR-only code continues to work with legacy `onQrDetected` callback
* **Visual Enhancements**:
  - Dynamic scanning frame colors based on detected format
  - Format type indicators in default overlay
  - Auto-detection status display
* **New API Methods**:
  - `scanStreamWithType()` - Stream with type information
  - `scanOnceWithType()` - Single scan with type

## 2.1.0
* Initial release of ultra_qr_scanner
* Ultra-fast QR code scanning with native performance
* Support for both Android (CameraX + MLKit) and iOS (AVCapture + Vision)
* Features:
    - Preload scanner for instant startup
    - Background processing threads
    - Frame throttling for battery efficiency
    - Auto-stop on detection
    - Flash toggle support
    - Pause/resume detection
    - Stream and single-scan modes

