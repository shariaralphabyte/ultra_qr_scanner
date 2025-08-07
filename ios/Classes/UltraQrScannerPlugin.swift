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
    private var isScanning = false
    private var isPrepared = false
    private var visionRequestHandler: VNSequenceRequestHandler?
    private let processingQueue = DispatchQueue(label: "qr_processing", qos: .userInitiated)
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var torchDevice: AVCaptureDevice?

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
        
        registrar.addMethodCallDelegate(instance, channel: instance.channel)
        instance.eventChannel.setStreamHandler(instance)
    }

    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
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
            captureSession.startRunning()
        }
        isScanning = true
        result(true)
    }

    private func stopScanner(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(true)
            return
        }

        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        isScanning = false
        result(true)
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
        
        currentCameraPosition = position == "front" ? .front : .back
        
        // Restart camera with new position
        setupCamera(result: result)
        
        // If we were scanning, start scanning again
        if isScanning, let captureSession = captureSession, !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !isScanning { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectBarcodesRequest { request, error in
            guard error == nil else {
                print("Error processing frame: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let results = request.results as? [VNBarcodeObservation] {
                for result in results {
                    if result.symbology == .QR {
                        DispatchQueue.main.async {
                            self.eventSink?(result.payloadStringValue)
                        }
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
}