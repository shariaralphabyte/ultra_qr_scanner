# Changelog
## 3.0.4
* **Fix iOS camera preview blank screen**: Camera session now starts immediately on `prepareScanner` so preview appears without requiring the user to press Start Scan
* **Fix iOS camera switch freeze**: Platform view now receives a notification when the preview layer changes (front/back switch) and swaps the layer instantly — no more frozen frame
* **Fix preview layer frame**: Added `layoutSubviews` override to `CameraContainerView` so the preview layer resizes correctly from `CGRect.zero` to the real widget size
* **Fix hot restart crash**: Added `disposeScanner` method that fully shuts down the native `AVCaptureSession`; widget `dispose()` now calls it so the native session is cleaned up before recreation
* **Fix flash button on front camera**: Flash toggle button is now hidden when the front camera is active; switching to front camera with flash on automatically turns it off

## 3.0.3
* **Support Google 16KB Page size**: Support Google 16KB Page size
* **Fix Ios scanning error**: Fix Ios scanning error
## 3.0.2
* **New Readme update**: add and update readme for more clear documentation 
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

