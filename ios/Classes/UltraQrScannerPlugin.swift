import Flutter
import UIKit
import AVFoundation
import Vision

public class UltraQrScannerPlugin: NSObject, FlutterPlugin, AVCaptureMetadataOutputObjectsDelegate {
    private var methodChannel: FlutterMethodChannel!
    private var eventChannel: FlutterEventChannel!
    private var eventSink: FlutterEventSink?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var backCamera: AVCaptureDevice?

    private var isScanning = false
    private var isPrepared = false
    private var frameSkipCounter = 0
    private let processingQueue = DispatchQueue(label: "qr_processing", qos: .userInitiated)

    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var cameraInput: AVCaptureDeviceInput?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = UltraQrScannerPlugin()

        instance.methodChannel = FlutterMethodChannel(
            name: "ultra_qr_scanner",
            binaryMessenger: registrar.messenger()
        )

        instance.eventChannel = FlutterEventChannel(
            name: "ultra_qr_scanner_events",
            binaryMessenger: registrar.messenger()
        )

        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel)
        instance.eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "prepareScanner":
            prepareScanner(result: result)
        case "scanOnce":
            scanOnce(result: result)
        case "startScanStream":
            startScanStream(result: result)
        case "stopScanner":
            stopScanner(result: result)
        case "toggleFlash":
            let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
            toggleFlash(enabled: enabled, result: result)
        case "pauseDetection":
            pauseDetection(result: result)
        case "resumeDetection":
            resumeDetection(result: result)
        case "requestPermissions":
            requestPermissions(result: result)
        case "switchCamera":
            let position = (call.arguments as? [String: Any])?["position"] as? String ?? "back"
            switchCamera(position: position, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setupCamera(completion: @escaping (Bool) -> Void) {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .vga640x480
        captureSession?.automaticallyConfiguresCaptureDeviceForWideColor = false
        captureSession?.automaticallyConfiguresPreferredVideoSettings = false

        guard let captureSession = captureSession else {
            completion(false)
            return
        }

        // Configure camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            completion(false)
            return
        }

        do {
            // Remove existing input if any
            if let existingInput = captureSession.inputs.first as? AVCaptureDeviceInput {
                captureSession.removeInput(existingInput)
            }

            // Create new input
            let input = try AVCaptureDeviceInput(device: camera)
            cameraInput = input

            // Add input
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                completion(false)
                return
            }

            // Configure metadata output for QR code detection
            let metadataOutput = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: processingQueue)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                completion(false)
                return
            }

            // Set up preview layer
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.connection?.videoOrientation = .portrait

            completion(true)
        } catch {
            completion(false)
        }
    }

    private func scanOnce(result: @escaping FlutterResult) {
        guard isPrepared else {
            let error = FlutterError(
                code: "NOT_PREPARED",
                message: "Scanner not prepared",
                details: nil
            )
            result(error)
            return
        }

        isScanning = true
        startCameraSession()

        // Handle single scan result
        let originalSink = eventSink
        eventSink = { [weak self] event in
            originalSink?(event)
            result(event)
            self?.eventSink = originalSink
            self?.stopCameraSession()
        }
    }

    private func startScanStream(result: @escaping FlutterResult) {
        guard isPrepared else {
            result(FlutterError(code: "NOT_PREPARED", message: "Scanner not prepared", details: nil))
            return
        }

        isScanning = true
        startCameraSession()
        result(nil)
    }

    private func startCameraSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    private func stopScanner(result: @escaping FlutterResult) {
        isScanning = false
        stopCameraSession()
        result(nil)
    }

    private func stopCameraSession() {
        captureSession?.stopRunning()
    }

    private func toggleFlash(enabled: Bool, result: @escaping FlutterResult) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else {
            result(FlutterError(code: "NO_FLASH", message: "Flash not available", details: nil))
            return
        }

        do {
            try device.lockForConfiguration()
            device.torchMode = enabled ? .on : .off
            device.unlockForConfiguration()
            result(nil)
        } catch {
            result(FlutterError(code: "FLASH_ERROR", message: "Failed to toggle flash", details: error.localizedDescription))
        }
    }

    private func pauseDetection(result: @escaping FlutterResult) {
        isScanning = false
        result(nil)
    }

    private func resumeDetection(result: @escaping FlutterResult) {
        isScanning = true
        result(nil)
    }

    private func prepareScanner(result: @escaping FlutterResult) {
        guard !isPrepared else {
            result(nil)
            return
        }

        // Check permissions first
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break // Already authorized
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if !granted {
                        result(FlutterError(code: "PERMISSION_DENIED",
                                           message: "Camera permission denied",
                                           details: nil))
                        return
                    }
                    self.prepareCamera(result: result)
                }
            }
            return
        case .denied, .restricted:
            result(FlutterError(code: "PERMISSION_DENIED",
                               message: "Camera permission denied",
                               details: nil))
            return
        @unknown default:
            result(FlutterError(code: "PERMISSION_ERROR",
                               message: "Unknown authorization status",
                               details: nil))
            return
        }

        prepareCamera(result: result)
    }

    private func prepareCamera(result: @escaping FlutterResult) {
        processingQueue.async { [weak self] in
            self?.setupCamera { success in
                DispatchQueue.main.async {
                    if success {
                        self?.isPrepared = true
                        result(nil)
                    } else {
                        result(FlutterError(code: "PREPARE_ERROR", message: "Failed to prepare camera", details: nil))
                    }
                }
            }
        }
    }

    private func requestPermissions(result: @escaping FlutterResult) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if !granted {
                    result(FlutterError(code: "PERMISSION_DENIED",
                                       message: "Camera permission denied",
                                       details: nil))
                    return
                }
                result(granted)
            }
        }
    }

    private func switchCamera(position: String, result: @escaping FlutterResult) {
        guard let newPosition = AVCaptureDevice.Position(rawValue: position) else {
            result(FlutterError(code: "INVALID_CAMERA", message: "Invalid camera position", details: nil))
            return
        }

        currentCameraPosition = newPosition
        setupCamera { success in
            result(success)
        }
    }

    private func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !isScanning {
            return
        }

        // Frame throttling - process every 3rd frame
        if frameSkipCounter.compareAndSet(false, true) {
            frameSkipCounter.set(false)
            return
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        
        do {
            // Create Vision request
            let request = VNDetectBarcodesRequest { [weak self] request, error in
                guard let self = self, self.isScanning else { return }

                if let results = request.results as? [VNBarcodeObservation],
                   let firstBarcode = results.first,
                   let qrValue = firstBarcode.payloadStringValue {
                    
                    DispatchQueue.main.async {
                        self.isScanning = false
                        self.eventSink?(qrValue)
                        self.stopCameraInternal()
                    }
                }
            }

            try context.perform([request], on: ciImage)
        } catch {
            print("Error processing frame: \(error)")
        }
    }

    private func stopCameraInternal() {
        captureSession?.stopRunning()
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}