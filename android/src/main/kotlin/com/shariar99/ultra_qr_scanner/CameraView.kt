package com.shariar99.ultra_qr_scanner

import android.content.Context
import android.util.AttributeSet
import android.view.SurfaceHolder
import android.view.SurfaceView
import androidx.camera.core.Preview
import androidx.camera.view.PreviewView
import androidx.lifecycle.LifecycleOwner

class CameraView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : PreviewView(context, attrs, defStyleAttr) {

    init {
        // Configure for optimal performance
        implementationMode = ImplementationMode.PERFORMANCE
        scaleType = ScaleType.FILL_CENTER
    }

    fun setupPreview(preview: Preview) {
        preview.setSurfaceProvider(surfaceProvider)
    }

    fun cleanup() {
        // Cleanup resources if needed
    }
}