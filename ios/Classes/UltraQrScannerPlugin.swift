import Flutter
import AVFoundation
import Vision

@objc(UltraQrScannerPlugin)
public class UltraQrScannerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var channel: FlutterMethodChannel!
    private var eventChannel: FlutterEventChannel!
    private var eventSink: FlutterEventSink?

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isScanning = false
    private var isPrepared = false
    private var visionRequestHandler: VNSequenceRequestHandler?
    private let processingQueue = DispatchQueue(label: "qr_processing", qos: .userInitiated)
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var torchDevice: AVCaptureDevice?

    private var eventChannelWithType: FlutterEventChannel!
    private var eventSinkWithType: FlutterEventSink?
  // Enable all supported formats
    request.symbologies = [
        .qr,
        .code128,
        .code39,
        .code93,
        .ean13,
        .ean8,
        .upce,
        .codabar,
        .itf14,
        .pdf417,
        .dataMatrix,
        .aztec
    ]

    private func getBarcodeTypeName(_ symbology: VNBarcodeSymbology) -> String {
        switch symbology {
        case .qr: return "QR_CODE"
        case .code128: return "CODE_128"
        case .code39: return "CODE_39"
        case .code93: return "CODE_93"
        case .ean13: return "EAN_13"
        case .ean8: return "EAN_8"
        case .upce: return "UPC_E"
        case .codabar: return "CODABAR"
        case .itf14: return "ITF"
        case .pdf417: return "PDF417"
        case .dataMatrix: return "DATA_MATRIX"
        case .aztec: return "AZTEC"
        default: return "UNKNOWN"
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = UltraQrScannerPlugin()

        instance.channel = FlutterMethodChannel(
            name: "ultra_qr_scanner",
            binaryMessenger: registrar.messenger()
        )

        instance.eventChannel = FlutterEventChannel(
            name: "ultra_qr_scanner_events",
            binaryMessenger: registrar.messenger()
        )


        instance.eventChannelWithType = FlutterEventChannel(
            name: "ultra_qr_scanner_events_with_type",
            binaryMessenger: registrar.messenger()
        )

        instance.eventChannelWithType.setStreamHandler(instance)

        registrar.addMethodCallDelegate(instance, channel: instance.channel)
        instance.eventChannel.setStreamHandler(instance)

        // Register platform view factory
        let factory = CameraViewFactory(plugin: instance)
        registrar.register(factory, withId: "ultra_qr_camera_view")
    }

   public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
       if let args = arguments as? [String: Any], let channel = args["channel"] as? String, channel == "with_type" {
           self.eventSinkWithType = eventSink
       } else {
           self.eventSink = eventSink
       }
       return nil
   }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "prepareScanner":
            prepareScanner(result: result)
        case "scanOnce":
            scanOnce(result: result)
        case "stopScanner":
            stopScanner(result: result)
        case "toggleFlash":
            toggleFlash(call: call, result: result)
        case "requestPermissions":
            requestPermissions(result: result)
        case "switchCamera":
            switchCamera(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func prepareScanner(result: @escaping FlutterResult) {
        // Check camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status != .authorized {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission is required", details: nil))
            return
        }

        setupCamera(result: result)
    }

    private func requestPermissions(result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            result(true)
            return
        }

        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    result(granted)
                }
            }
        } else {
            result(false)
        }
    }

    private func setupCamera(result: @escaping FlutterResult) {
        // Clean up existing session if any
        if let session = captureSession, session.isRunning {
            session.stopRunning()
        }

        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .vga640x480

        guard let captureSession = captureSession else {
            result(FlutterError(code: "INIT_ERROR", message: "Failed to create capture session", details: nil))
            return
        }

        let devicePosition = currentCameraPosition
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: devicePosition) else {
            result(FlutterError(code: "NO_CAMERA", message: "No camera available", details: nil))
            return
        }

        torchDevice = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA]
            videoOutput?.setSampleBufferDelegate(self, queue: processingQueue)

            if captureSession.canAddOutput(videoOutput!) {
                captureSession.addOutput(videoOutput!)

                // Create preview layer
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer?.videoGravity = .resizeAspectFill

                visionRequestHandler = VNSequenceRequestHandler()
                isPrepared = true
                result(true)
            } else {
                result(FlutterError(code: "SETUP_ERROR", message: "Failed to add video output", details: nil))
            }
        } catch {
            result(FlutterError(code: "SETUP_ERROR", message: "Failed to setup camera: \(error.localizedDescription)", details: nil))
        }
    }

    private func scanOnce(result: @escaping FlutterResult) {
        guard isPrepared else {
            result(FlutterError(code: "NOT_PREPARED", message: "Scanner not prepared", details: nil))
            return
        }

        guard let captureSession = captureSession else {
            result(FlutterError(code: "NO_SESSION", message: "Camera session not initialized", details: nil))
            return
        }

        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isScanning = true
                    result(true)
                }
            }
        } else {
            isScanning = true
            result(true)
        }
    }

    private func stopScanner(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(true)
            return
        }

        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isScanning = false
                    result(true)
                }
            }
        } else {
            isScanning = false
            result(true)
        }
    }

    private func toggleFlash(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let device = torchDevice, device.hasTorch else {
            result(FlutterError(code: "NO_FLASH", message: "Flash not available", details: nil))
            return
        }

        guard let arguments = call.arguments as? [String: Any],
              let enabled = arguments["enabled"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        do {
            try device.lockForConfiguration()
            if enabled && device.isTorchAvailable {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
            result(true)
        } catch {
            result(FlutterError(code: "FLASH_ERROR", message: "Failed to toggle flash: \(error.localizedDescription)", details: nil))
        }
    }

    private func switchCamera(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let position = arguments["position"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        let wasScanning = isScanning
        currentCameraPosition = position == "front" ? .front : .back

        // Stop current session
        if let session = captureSession, session.isRunning {
            session.stopRunning()
        }

        // Restart camera with new position
        setupCamera(result: { [weak self] setupResult in
            // Check if setupResult is a FlutterError or success
            if let error = setupResult as? FlutterError {
                result(error)
            } else {
                // Setup was successful, start scanning again if needed
                if wasScanning {
                    self?.scanOnce { _ in }
                }
                result(true)
            }
        })
    }

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !isScanning { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    // Replace the existing Vision request:
    let request = VNDetectBarcodesRequest { [weak self] request, error in
        guard error == nil else {
            print("Error processing frame: \(error?.localizedDescription ?? "Unknown error")")
            return
        }

        if let results = request.results as? [VNBarcodeObservation] {
            for result in results {
                if let payload = result.payloadStringValue {
                    DispatchQueue.main.async {
                        // Send to legacy event sink
                        self?.eventSink?(payload)

                        // Send to new event sink with type info
                        let resultWithType: [String: Any] = [
                            "code": payload,
                            "type": self?.getBarcodeTypeName(result.symbology) ?? "UNKNOWN"
                        ]
                        self?.eventSinkWithType?(resultWithType)
                    }
                    return // Only send first code found
                }
            }
        }
    }



        do {
            try visionRequestHandler!.perform([request], on: pixelBuffer)
        } catch {
            print("Failed to perform vision request: \(error.localizedDescription)")
        }
    }

    // Create preview layer for platform view
    func createPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return previewLayer
    }
}

// MARK: - Platform View Factory
class CameraViewFactory: NSObject, FlutterPlatformViewFactory {
    private let plugin: UltraQrScannerPlugin

    init(plugin: UltraQrScannerPlugin) {
        self.plugin = plugin
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return CameraPlatformView(frame: frame, plugin: plugin)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

// MARK: - Platform View Implementation
// MARK: - Platform View Implementation (FIXED VERSION)
class CameraPlatformView: NSObject, FlutterPlatformView {
    private let containerView: UIView
    private let plugin: UltraQrScannerPlugin
    private var previewLayer: AVCaptureVideoPreviewLayer?

    init(frame: CGRect, plugin: UltraQrScannerPlugin) {
        self.containerView = UIView(frame: frame)
        self.plugin = plugin
        super.init()

        containerView.backgroundColor = UIColor.black
        containerView.clipsToBounds = true

        setupPreviewLayer()

        // Add observer to handle frame changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    private func setupPreviewLayer() {
        if let previewLayer = plugin.createPreviewLayer() {
            self.previewLayer = previewLayer
            updatePreviewLayerFrame()
            previewLayer.videoGravity = .resizeAspectFill
            containerView.layer.addSublayer(previewLayer)
        }
    }

    @objc private func orientationDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updatePreviewLayerFrame()
        }
    }

    private func updatePreviewLayerFrame() {
        guard let previewLayer = self.previewLayer else { return }

        // Update frame to match container bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true) // Prevent animations
        previewLayer.frame = containerView.bounds
        CATransaction.commit()
    }

    func view() -> UIView {
        return containerView
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}