import Flutter
import AVFoundation
import Vision

private let kPreviewLayerChanged = NSNotification.Name("UltraQrScannerPreviewLayerChanged")

@objc(UltraQrScannerPlugin)
public class UltraQrScannerPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var channel: FlutterMethodChannel!
    private var eventChannel: FlutterEventChannel!
    private var eventSink: FlutterEventSink?

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private var isScanning = false
    private var isPrepared = false
    private var visionRequestHandler: VNSequenceRequestHandler?
    private let processingQueue = DispatchQueue(label: "qr_processing", qos: .userInitiated)
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var torchDevice: AVCaptureDevice?

    private var eventChannelWithType: FlutterEventChannel!
    private var eventSinkWithType: FlutterEventSink?

    private func getBarcodeTypeName(_ symbology: VNBarcodeSymbology) -> String {
        switch symbology {
        case .qr: return "QR_CODE"
        case .code128: return "CODE_128"
        case .code39: return "CODE_39"
        case .code93: return "CODE_93"
        case .ean13: return "EAN_13"
        case .ean8: return "EAN_8"
        case .upce: return "UPC_E"
        case .itf14: return "ITF"
        case .pdf417: return "PDF417"
        case .dataMatrix: return "DATA_MATRIX"
        case .aztec: return "AZTEC"
        default:
            if #available(iOS 15.0, *) {
                if symbology == .codabar { return "CODABAR" }
            }
            return "UNKNOWN"
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

        let factory = CameraViewFactory(plugin: instance)
        registrar.register(factory, withId: "ultra_qr_camera_view")
    }

    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        if let args = arguments as? [String: Any], let ch = args["channel"] as? String, ch == "with_type" {
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
        case "prepareScanner":  prepareScanner(result: result)
        case "scanOnce":        scanOnce(result: result)
        case "stopScanner":     stopScanner(result: result)
        case "disposeScanner":  disposeScanner(result: result)
        case "toggleFlash":     toggleFlash(call: call, result: result)
        case "requestPermissions": requestPermissions(result: result)
        case "switchCamera":    switchCamera(call: call, result: result)
        default:                result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Permission

    private func requestPermissions(result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: result(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { result(granted) }
            }
        default: result(false)
        }
    }

    // MARK: - Camera Setup

    private func prepareScanner(result: @escaping FlutterResult) {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission required", details: nil))
            return
        }
        setupCamera(result: result)
    }

    private func setupCamera(result: @escaping FlutterResult) {
        // Tear down any existing session first
        if let existing = captureSession {
            existing.stopRunning()
            captureSession = nil
            previewLayer = nil
        }

        let session = AVCaptureSession()
        session.sessionPreset = .vga640x480
        captureSession = session

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            result(FlutterError(code: "NO_CAMERA", message: "No camera for requested position", details: nil))
            return
        }
        torchDevice = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                result(FlutterError(code: "SETUP_ERROR", message: "Cannot add camera input", details: nil))
                return
            }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: processingQueue)
            output.alwaysDiscardsLateVideoFrames = true

            guard session.canAddOutput(output) else {
                result(FlutterError(code: "SETUP_ERROR", message: "Cannot add video output", details: nil))
                return
            }
            session.addOutput(output)
            videoOutput = output

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            previewLayer = layer

            visionRequestHandler = VNSequenceRequestHandler()
            isPrepared = true

            // Start session then notify platform view to swap layer
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: kPreviewLayerChanged, object: self)
                    result(true)
                }
            }
        } catch {
            result(FlutterError(code: "SETUP_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    // MARK: - Scan Control

    private func scanOnce(result: @escaping FlutterResult) {
        guard isPrepared, let session = captureSession else {
            result(FlutterError(code: "NOT_PREPARED", message: "Scanner not prepared", details: nil))
            return
        }
        if session.isRunning {
            isScanning = true
            result(true)
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                DispatchQueue.main.async {
                    self.isScanning = true
                    result(true)
                }
            }
        }
    }

    // stopScanner keeps session alive so preview stays live; only stops QR detection
    private func stopScanner(result: @escaping FlutterResult) {
        isScanning = false
        result(true)
    }

    // disposeScanner fully shuts down the session (call from widget dispose)
    private func disposeScanner(result: @escaping FlutterResult) {
        isScanning = false
        isPrepared = false
        if let session = captureSession, session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
                DispatchQueue.main.async {
                    self.captureSession = nil
                    self.previewLayer = nil
                    result(true)
                }
            }
        } else {
            captureSession = nil
            previewLayer = nil
            result(true)
        }
    }

    // MARK: - Flash & Camera Switch

    private func toggleFlash(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let device = torchDevice, device.hasTorch else {
            result(FlutterError(code: "NO_FLASH", message: "Flash not available", details: nil))
            return
        }
        guard let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool else {
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
            result(FlutterError(code: "FLASH_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func switchCamera(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any], let position = args["position"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        let wasScanning = isScanning
        isScanning = false
        currentCameraPosition = position == "front" ? .front : .back

        setupCamera(result: { [weak self] setupResult in
            if let error = setupResult as? FlutterError {
                result(error)
            } else {
                if wasScanning { self?.isScanning = true }
                result(true)
            }
        })
    }

    // MARK: - Frame Processing

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isScanning, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var symbologies: [VNBarcodeSymbology] = [
            .qr, .code128, .code39, .code93, .ean13, .ean8, .upce, .itf14, .pdf417, .dataMatrix, .aztec
        ]
        if #available(iOS 15.0, *) { symbologies.append(.codabar) }

        let request = VNDetectBarcodesRequest { [weak self] req, error in
            guard error == nil, let results = req.results as? [VNBarcodeObservation] else { return }
            for obs in results {
                guard let payload = obs.payloadStringValue else { continue }
                DispatchQueue.main.async {
                    self?.eventSink?(payload)
                    self?.eventSinkWithType?(["code": payload, "type": self?.getBarcodeTypeName(obs.symbology) ?? "UNKNOWN"])
                }
                return
            }
        }
        request.symbologies = symbologies

        do {
            try visionRequestHandler?.perform([request], on: pixelBuffer)
        } catch {
            print("Vision request failed: \(error.localizedDescription)")
        }
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

// MARK: - Camera Container View

class CameraContainerView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let layer = previewLayer {
                layer.videoGravity = .resizeAspectFill
                layer.frame = bounds
                self.layer.insertSublayer(layer, at: 0)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let previewLayer = previewLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }
}

// MARK: - Platform View

class CameraPlatformView: NSObject, FlutterPlatformView {
    private let containerView: CameraContainerView
    private weak var plugin: UltraQrScannerPlugin?

    init(frame: CGRect, plugin: UltraQrScannerPlugin) {
        self.containerView = CameraContainerView(frame: frame)
        self.plugin = plugin
        super.init()

        containerView.backgroundColor = .black
        containerView.clipsToBounds = true
        containerView.previewLayer = plugin.previewLayer

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(previewLayerChanged(_:)),
            name: kPreviewLayerChanged,
            object: plugin
        )
    }

    @objc private func previewLayerChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let plugin = self.plugin else { return }
            self.containerView.previewLayer = plugin.previewLayer
            self.containerView.setNeedsLayout()
        }
    }

    func view() -> UIView { containerView }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
