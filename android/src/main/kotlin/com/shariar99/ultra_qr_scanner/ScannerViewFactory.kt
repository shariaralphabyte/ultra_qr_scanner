package com.shariar99.ultra_qr_scanner

import android.content.Context
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class ScannerViewFactory(private val context: Context) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return ScannerView(context)
    }
}

class ScannerView(context: Context) : PlatformView {
    private val cameraView: CameraView = CameraView(context)

    override fun getView(): View {
        return cameraView
    }

    override fun dispose() {
        cameraView.cleanup()
    }
}