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
    private var visionRequestHandler: VNSequenceRequestHandler?
    private let processingQueue = DispatchQueue(label: "qr_processing", qos: .userInitiated)

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
        case "initialize":
            setupCamera(result: result)
        case "startScanning":
            startScanning(result: result)
        case "stopScanning":
            stopScanning(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setupCamera(result: @escaping FlutterResult) {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .vga640x480

        guard let captureSession = captureSession else {
            result(FlutterError(code: "INIT_ERROR", message: "Failed to create capture session", details: nil))
            return
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            result(FlutterError(code: "NO_CAMERA", message: "No camera available", details: nil))
            return
        }

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
                result(nil)
            } else {
                result(FlutterError(code: "SETUP_ERROR", message: "Failed to add video output", details: nil))
            }
        } catch {
            result(FlutterError(code: "SETUP_ERROR", message: "Failed to setup camera: \(error.localizedDescription)", details: nil))
        }
    }

    private func startScanning(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "NO_SESSION", message: "Camera session not initialized", details: nil))
            return
        }

        if !captureSession.isRunning {
            captureSession.startRunning()
        }
        isScanning = true
        result(nil)
    }

    private func stopScanning(result: @escaping FlutterResult) {
        guard let captureSession = captureSession else {
            result(FlutterError(code: "NO_SESSION", message: "Camera session not initialized", details: nil))
            return
        }

        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        isScanning = false
        result(nil)
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