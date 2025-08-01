import Flutter
import UIKit
import AVFoundation

class ScannerViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return ScannerView(frame: frame, viewIdentifier: viewId, arguments: args, binaryMessenger: messenger)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class ScannerView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var previewLayer: AVCaptureVideoPreviewLayer?

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, binaryMessenger messenger: FlutterBinaryMessenger?) {
        _view = UIView(frame: frame)
        super.init()
        createNativeView(view: _view)
    }

    func view() -> UIView {
        return _view
    }

    func createNativeView(view: UIView) {
        view.backgroundColor = UIColor.black

        // Setup preview layer for camera feed
        if let captureSession = getCaptureSession() {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.frame = view.bounds
            previewLayer?.videoGravity = .resizeAspectFill

            if let previewLayer = previewLayer {
                view.layer.addSublayer(previewLayer)
            }
        }
    }

    private func getCaptureSession() -> AVCaptureSession? {
        // Get the capture session from the plugin instance
        // This is a simplified approach - in practice, you'd need to coordinate with the plugin
        return nil
    }
}