import Flutter
import UIKit
import AVFoundation
import Vision
import VideoToolbox

public class UltraQrScannerPlugin: NSObject, FlutterPlugin {

    private var channel: FlutterMethodChannel?
    private var scanChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    // Camera and scanning components
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var device: AVCaptureDevice?

    // Performance optimization
    private let processingQueue = DispatchQueue(label: "ultra_qr_scanner.processing", qos: .userInitiated)
    private let sessionQueue = DispatchQueue(label: "ultra_qr_scanner.session", qos: .userInitiated)

    // Configuration
    private var enableGpuAcceleration = true
    private var optimizeForSpeed = true
    private var scanningEnabled = false
    private var continuousScanning = false

    // Statistics
    private var totalScans = 0
    private var successfulScans = 0
    private var processingTimes: [Double] = []
    private var frameCount = 0
    private var lastFrameTime = CFAbsoluteTimeGetCurrent()

    // Vision requests
    private lazy var barcodeDetectionRequest: VNDetectBarcodesRequest = {
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            self?.handleBarcodeDetection(request: request, error: error)
        }

        // Optimize for speed
        request.revision = VNDetectBarcodesRequestRevision1

        // Focus on QR codes for maximum performance
        request.symbologies = [.qr]

        return request
    }()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = UltraQrScannerPlugin()

        let channel = FlutterMethodChannel(name: "ultra_qr_scanner", binaryMessenger: registrar.messenger())
        let scanChannel = FlutterEventChannel(name: "ultra_qr_scanner/scan", binaryMessenger: registrar.messenger())

        instance.channel = channel
        instance.scanChannel = scanChannel

        registrar.addMethodCallDelegate(instance, channel: channel)
        scanChannel.setStreamHandler(instance)

        // Register native view factory
        let factory = ScannerViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "ultra_qr_scanner_view")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(call: call, result: result)
        case "startScanning":
            startScanning(result: result)
        case "stopScanning":
            stopScanning(result: result)
        case "toggleTorch":
            toggleTorch(result: result)
        case "hasTorch":
            hasTorch(result: result)
        case "focusAt":
            focusAt(call: call, result: result)
        case "getStats":
            getStats(result: result)
        case "dispose":
            dispose(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }

        // Check camera permissions
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .authorized else {
            if status == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        result(granted)
                    }
                }
                return
            }
            result(false)
            return
        }

        // Get configuration
        enableGpuAcceleration = args["enableGpuAcceleration"] as? Bool ?? true
        optimizeForSpeed = args["optimizeForSpeed"] as? Bool ?? true

        sessionQueue.async { [weak self] in
            self?.setupCaptureSession()
            DispatchQueue.main.async {
                result(true)
            }
        }
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()

        guard let captureSession = captureSession else { return }

        // Configure session for optimal performance
        if optimizeForSpeed {
            captureSession.sessionPreset = .medium // Balance between quality and speed
        } else {
            captureSession.sessionPreset = .high
        }

        // Setup camera input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return
        }

        self.device = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            return
        }

        // Setup video output
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.setSampleBufferDelegate(self, queue: processingQueue)

        // Optimize video settings for performance
        videoOutput?.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        // Discard late frames for real-time processing
        videoOutput?.alwaysDiscardsLateVideoFrames = true

        if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Configure camera settings for optimal scanning
        configureCameraForScanning()
    }

    private func configureCameraForScanning() {
        guard let device = device else { return }

        do {
            try device.lockForConfiguration()

            // Set focus mode for fast autofocus
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            // Set exposure mode
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            // Enable low light boost if available
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }

            // Set frame rate for optimal performance
            let frameRate = optimizeForSpeed ? 30.0 : 60.0
            device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
            device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))

            device.unlockForConfiguration()
        } catch {
            // Handle configuration error
        }
    }

    private func startScanning(result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self, let captureSession = self.captureSession else {
                DispatchQueue.main.async {
                    result(false)
                }
                return
            }

            self.scanningEnabled = true

            if !captureSession.isRunning {
                captureSession.startRunning()
            }

            DispatchQueue.main.async {
                result(true)
            }
        }
    }

    private func stopScanning(result: @escaping FlutterResult) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    result(false)
                }
                return
            }

            self.scanningEnabled = false
            self.captureSession?.stopRunning()

            DispatchQueue.main.async {
                result(true)
            }
        }
    }

    private func toggleTorch(result: @escaping FlutterResult) {
        guard let device = device, device.hasTorch else {
            result(false)
            return
        }

        do {
            try device.lockForConfiguration()

            if device.torchMode == .off {
                try device.setTorchModeOn(level: 1.0)
                device.unlockForConfiguration()
                result(true)
            } else {
                device.torchMode = .off
                device.unlockForConfiguration()
                result(false)
            }
        } catch {
            device.unlockForConfiguration()
            result(false)
        }
    }

    private func hasTorch(result: @escaping FlutterResult) {
        result(device?.hasTorch ?? false)
    }

    private func focusAt(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let x = args["x"] as? Double,
              let y = args["y"] as? Double,
              let device = device else {
            result(false)
            return
        }

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: x, y: y)
                device.focusMode = .autoFocus
            }

            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = CGPoint(x: x, y: y)
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()
            result(true)
        } catch {
            device.unlockForConfiguration()
            result(false)
        }
    }

    private func getStats(result: @escaping FlutterResult) {
        let averageProcessingTime = processingTimes.isEmpty ? 0.0 : processingTimes.reduce(0, +) / Double(processingTimes.count)
        let successRate = totalScans > 0 ? (Double(successfulScans) / Double(totalScans)) * 100 : 0.0

        let stats: [String: Any] = [
            "totalScans": totalScans,
            "successfulScans": successfulScans,
            "averageProcessingTime": averageProcessingTime,
            "successRate": successRate,
            "framesPerSecond": frameCount
        ]

        result(stats)
    }

    private func dispose(result: @escaping FlutterResult) {
        cleanup()
        result(true)
    }

    private func cleanup() {
        scanningEnabled = false
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        previewLayer = nil
        device = nil

        // Reset statistics
        totalScans = 0
        successfulScans = 0
        processingTimes.removeAll()
        frameCount = 0
    }

    private func handleBarcodeDetection(request: VNRequest, error: Error?) {
        guard scanningEnabled else { return }

        let processingEndTime = CFAbsoluteTimeGetCurrent()
        let processingTime = (processingEndTime - lastFrameTime) * 1000 // Convert to ms

        guard let observations = request.results as? [VNBarcodeObservation],
              let firstObservation = observations.first,
              let payload = firstObservation.payloadStringValue else {
            return
        }

        successfulScans += 1

        // Update processing times buffer
        processingTimes.append(processingTime)
        if processingTimes.count > 100 {
            processingTimes.removeFirst()
        }

        // Convert corner points
        let corners = firstObservation.topLeft != CGPoint.zero ? [
            ["x": firstObservation.topLeft.x, "y": firstObservation.topLeft.y],
            ["x": firstObservation.topRight.x, "y": firstObservation.topRight.y],
            ["x": firstObservation.bottomRight.x, "y": firstObservation.bottomRight.y],
            ["x": firstObservation.bottomLeft.x, "y": firstObservation.bottomLeft.y]
        ] : []

        let result: [String: Any] = [
            "data": payload,
            "format": getFormatName(firstObservation.symbology),
            "corners": corners,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "confidence": firstObservation.confidence,
            "processingTimeMs": Int(processingTime)
        ]

        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(result)

            if !(self?.continuousScanning ?? false) {
                self?.scanningEnabled = false
            }
        }
    }

    private func getFormatName(_ symbology: VNBarcodeSymbology) -> String {
        switch symbology {
        case .qr:
            return "qr"
        case .dataMatrix:
            return "dataMatrix"
        case .code128:
            return "code128"
        case .code39:
            return "code39"
        case .code93:
            return "code93"
        case .ean8:
            return "ean8"
        case .ean13:
            return "ean13"
        case .upce:
            return "upce"
        case .pdf417:
            return "pdf417"
        case .aztec:
            return "aztec"
        default:
            return "unknown"
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension UltraQrScannerPlugin: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard scanningEnabled else { return }

        totalScans += 1
        frameCount += 1

        // Calculate FPS
        let currentTime = CFAbsoluteTimeGetCurrent()
        if currentTime - lastFrameTime >= 1.0 {
            lastFrameTime = currentTime
            frameCount = 0
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try imageRequestHandler.perform([barcodeDetectionRequest])
        } catch {
            // Handle processing error
        }
    }
}

// MARK: - FlutterStreamHandler
extension UltraQrScannerPlugin: FlutterStreamHandler {

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events

        if let args = arguments as? [String: Any] {
            continuousScanning = args["continuous"] as? Bool ?? false

            // Update barcode types based on formats
            if let formats = args["formats"] as? [String] {
                var symbologies: [VNBarcodeSymbology] = []

                for format in formats {
                    switch format {
                    case "qr":
                        symbologies.append(.qr)
                    case "dataMatrix":
                        symbologies.append(.dataMatrix)
                    case "code128":
                        symbologies.append(.code128)
                    case "code39":
                        symbologies.append(.code39)
                    case "code93":
                        symbologies.append(.code93)
                    case "ean8":
                        symbologies.append(.ean8)
                    case "ean13":
                        symbologies.append(.ean13)
                    case "upce":
                        symbologies.append(.upce)
                    case "pdf417":
                        symbologies.append(.pdf417)
                    case "aztec":
                        symbologies.append(.aztec)
                    default:
                        break
                    }
                }

                if !symbologies.isEmpty {
                    barcodeDetectionRequest.symbologies = symbologies
                }
            }
        }

        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}