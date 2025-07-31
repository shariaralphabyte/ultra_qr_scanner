import Flutter
import UIKit
import AVFoundation
import Vision

public class UltraQrScannerPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel!
    private var eventChannel: FlutterEventChannel!
    private var eventSink: FlutterEventSink?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?

    private var isScanning = false
    private var isPrepared = false
    private var frameSkipCounter = 0
    private let processingQueue = DispatchQueue(label: "qr_processing", qos: .userInitiated)

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
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func prepareScanner(result: @escaping FlutterResult) {
        guard !isPrepared else {
            result(nil)
            return
        }

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

    private func setupCamera(completion: @escaping (Bool) -> Void) {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .vga640x480

        guard let captureSession = captureSession,
              let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            completion(false)
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.setSampleBufferDelegate(self, queue: processingQueue)
            videoOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

            if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }

            // Disable autofocus to improve performance
            try backCamera.lockForConfiguration()
            if backCamera.isFocusModeSupported(.continuousAutoFocus) {
                backCamera.focusMode = .continuousAutoFocus
            }
            backCamera.unlockForConfiguration()

            completion(true)
        } catch {
            completion(false)
        }
    }

    private func scanOnce(result: @escaping FlutterResult) {
        guard isPrepared else {
            result(FlutterError(code: "NOT_PREPARED", message: "Scanner not prepared", details: nil))
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
            result(FlutterError(code: "FLASH_ERROR", message: error.localizedDescription, details: nil))
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

    private func requestPermissions(result: @escaping FlutterResult) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            result(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    result(granted)
                }
            }
        default:
            result(false)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension UltraQrScannerPlugin: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isScanning else { return }

        // Frame throttling - process every 3rd frame
        frameSkipCounter += 1
        guard frameSkipCounter % 3 == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self, self.isScanning else { return }

            if let results = request.results as? [VNBarcodeObservation],
               let firstBarcode = results.first,
               let qrValue = firstBarcode.payloadStringValue {

                self.isScanning = false

                DispatchQueue.main.async {
                    self.eventSink?(qrValue)
                    self.stopCameraSession()
                }
            }
        }

        request.symbologies = [.QR]

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}

// MARK: - FlutterStreamHandler
extension UltraQrScannerPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}