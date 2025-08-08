package com.shariar99.ultra_qr_scanner

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.annotation.NonNull
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class UltraQrScannerPlugin: FlutterPlugin, MethodCallHandler, StreamHandler, ActivityAware, LifecycleOwner {
    private lateinit var messenger: BinaryMessenger
    private lateinit var context: Context
    private lateinit var cameraProvider: ProcessCameraProvider
    private lateinit var cameraExecutor: ExecutorService
    private var eventSink: EventSink? = null
    private var isScanning = false
    private var cameraSelector: CameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
    private var preview: Preview? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private var barcodeScanner: BarcodeScanner? = null
    private var lifecycleRegistry: LifecycleRegistry? = null
    private var camera: Camera? = null
    private var eventSinkWithType: EventSink? = null
    // Add PreviewView for camera display
    private var previewView: PreviewView? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        messenger = binding.binaryMessenger
        context = binding.applicationContext

        val methodChannel = MethodChannel(messenger, "ultra_qr_scanner")
        methodChannel.setMethodCallHandler(this)

        val eventChannel = EventChannel(messenger, "ultra_qr_scanner_events")
        eventChannel.setStreamHandler(this)

        val eventChannelWithType = EventChannel(messenger, "ultra_qr_scanner_events_with_type")
        eventChannelWithType.setStreamHandler(object : StreamHandler {
            override fun onListen(arguments: Any?, events: EventSink?) {
                eventSinkWithType = events
            }
            override fun onCancel(arguments: Any?) {
                eventSinkWithType = null
            }
        })

        // Register platform view factory
        binding.platformViewRegistry.registerViewFactory(
            "ultra_qr_camera_view",
            CameraViewFactory(this)
        )

        cameraExecutor = Executors.newSingleThreadExecutor()
        lifecycleRegistry = LifecycleRegistry(this)
        lifecycleRegistry?.currentState = Lifecycle.State.CREATED
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        cameraExecutor.shutdown()
        lifecycleRegistry?.currentState = Lifecycle.State.DESTROYED
        lifecycleRegistry = null
    }

    override val lifecycle: Lifecycle
        get() = lifecycleRegistry ?: throw IllegalStateException("LifecycleRegistry not initialized")

    fun createCameraView(): PreviewView {
        previewView = PreviewView(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            scaleType = PreviewView.ScaleType.FILL_CENTER
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        }
        return previewView!!
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "prepareScanner" -> prepareScanner(result)
            "scanOnce" -> scanOnce(result)
            "stopScanner" -> stopScanner(result)
            "toggleFlash" -> toggleFlash(call, result)
            "requestPermissions" -> requestPermissions(result)
            "switchCamera" -> switchCamera(call, result)
            else -> result.notImplemented()
        }
    }
    private fun getBarcodeFormatName(format: Int): String {
        return when (format) {
            Barcode.FORMAT_QR_CODE -> "QR_CODE"
            Barcode.FORMAT_CODE_128 -> "CODE_128"
            Barcode.FORMAT_CODE_39 -> "CODE_39"
            Barcode.FORMAT_CODE_93 -> "CODE_93"
            Barcode.FORMAT_EAN_13 -> "EAN_13"
            Barcode.FORMAT_EAN_8 -> "EAN_8"
            Barcode.FORMAT_UPC_A -> "UPC_A"
            Barcode.FORMAT_UPC_E -> "UPC_E"
            Barcode.FORMAT_CODABAR -> "CODABAR"
            Barcode.FORMAT_ITF -> "ITF"
            Barcode.FORMAT_PDF417 -> "PDF417"
            Barcode.FORMAT_DATA_MATRIX -> "DATA_MATRIX"
            Barcode.FORMAT_AZTEC -> "AZTEC"
            else -> "UNKNOWN"
        }
    }

    private fun prepareScanner(result: Result) {
        try {
            // Check camera permission
            if (ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                result.error("PERMISSION_DENIED", "Camera permission is required", null)
                return
            }

            // Initialize camera provider
            val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            cameraProviderFuture.addListener({
                try {
                    cameraProvider = cameraProviderFuture.get()

                    // Initialize barcode scanner
                    val options = BarcodeScannerOptions.Builder()
                        .setBarcodeFormats(
                            Barcode.FORMAT_QR_CODE,
                            Barcode.FORMAT_CODE_128,
                            Barcode.FORMAT_CODE_39,
                            Barcode.FORMAT_CODE_93,
                            Barcode.FORMAT_EAN_13,
                            Barcode.FORMAT_EAN_8,
                            Barcode.FORMAT_UPC_A,
                            Barcode.FORMAT_UPC_E,
                            Barcode.FORMAT_CODABAR,
                            Barcode.FORMAT_ITF,
                            Barcode.FORMAT_PDF417,
                            Barcode.FORMAT_DATA_MATRIX,
                            Barcode.FORMAT_AZTEC
                        )
                        .build()

                    barcodeScanner = BarcodeScanning.getClient(options)

                    // Initialize preview
                    preview = Preview.Builder().build()

                    // Connect preview to PreviewView
                    previewView?.let {
                        preview?.setSurfaceProvider(it.surfaceProvider)
                    }

                    // Initialize image analyzer
                    imageAnalyzer = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .also { analyzer ->
                            analyzer.setAnalyzer(cameraExecutor) { image ->
                                val inputImage = InputImage.fromMediaImage(
                                    image.image!!,
                                    image.imageInfo.rotationDegrees
                                )
                                barcodeScanner?.process(inputImage)
                                    ?.addOnSuccessListener { barcodes ->
                                        for (barcode in barcodes) {
                                            // Send to legacy event sink
                                            eventSink?.success(barcode.rawValue)

                                            // Send to new event sink with type info
                                            val result = mapOf(
                                                "code" to barcode.rawValue,
                                                "type" to getBarcodeFormatName(barcode.format)
                                            )
                                            eventSinkWithType?.success(result)
                                        }
                                    }
                                    ?.addOnFailureListener { e ->
                                        eventSink?.error("ERROR", "Failed to scan QR code", e.message)
                                    }
                                    ?.addOnCompleteListener {
                                        image.close()
                                    }
                            }
                        }

                    result.success(true)
                } catch (e: Exception) {
                    result.error("INIT_ERROR", "Failed to initialize scanner", e.message)
                }
            }, ContextCompat.getMainExecutor(context))
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize scanner", e.message)
        }
    }

    private fun scanOnce(result: Result) {
        try {
            if (!::cameraProvider.isInitialized) {
                result.error("NOT_INITIALIZED", "Scanner not initialized", null)
                return
            }

            if (isScanning) {
                result.success(true)
                return
            }

            // Bind use cases to lifecycle
            cameraProvider.unbindAll()
            camera = cameraProvider.bindToLifecycle(
                this,
                cameraSelector,
                preview,
                imageAnalyzer
            )

            // Update preview view
            previewView?.let {
                preview?.setSurfaceProvider(it.surfaceProvider)
            }

            isScanning = true
            result.success(true)
        } catch (e: Exception) {
            result.error("START_ERROR", "Failed to start scanning", e.message)
        }
    }

    private fun stopScanner(result: Result) {
        try {
            if (!::cameraProvider.isInitialized || !isScanning) {
                result.success(true)
                return
            }

            cameraProvider.unbindAll()
            camera = null
            isScanning = false
            result.success(true)
        } catch (e: Exception) {
            result.error("STOP_ERROR", "Failed to stop scanning", e.message)
        }
    }

    private fun toggleFlash(call: MethodCall, result: Result) {
        if (!::cameraProvider.isInitialized) {
            result.error("NOT_INITIALIZED", "Scanner not initialized", null)
            return
        }

        val enabled = call.argument<Boolean>("enabled") ?: false

        try {
            val currentCamera = camera
            if (currentCamera == null) {
                result.error("NO_CAMERA", "Camera not bound", null)
                return
            }

            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = cameraManager.cameraIdList.firstOrNull { id ->
                val characteristics = cameraManager.getCameraCharacteristics(id)
                characteristics.get(CameraCharacteristics.LENS_FACING) ==
                        if (cameraSelector == CameraSelector.DEFAULT_BACK_CAMERA)
                            CameraMetadata.LENS_FACING_BACK
                        else
                            CameraMetadata.LENS_FACING_FRONT
            }

            if (cameraId == null) {
                result.error("NO_FLASH", "Camera not found", null)
                return
            }

            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            val flashAvailable = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false

            if (!flashAvailable) {
                result.error("NO_FLASH", "Flash not available", null)
                return
            }

            currentCamera.cameraControl.enableTorch(enabled)
            result.success(true)
        } catch (e: Exception) {
            result.error("FLASH_ERROR", e.message ?: "Failed to toggle flash", e.localizedMessage)
        }
    }

    private fun switchCamera(call: MethodCall, result: Result) {
        if (!::cameraProvider.isInitialized) {
            result.error("NOT_PREPARED", "Scanner not prepared", null)
            return
        }

        val position = call.argument<String>("position") ?: "back"
        cameraSelector = if (position == "front") {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }

        // Stop current camera
        cameraProvider.unbindAll()

        // Start new camera with updated selector
        try {
            preview = Preview.Builder().build()

            // Connect to preview view
            previewView?.let {
                preview?.setSurfaceProvider(it.surfaceProvider)
            }

            imageAnalyzer = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also {
                    it.setAnalyzer(cameraExecutor) { image ->
                        val inputImage = InputImage.fromMediaImage(image.image!!, image.imageInfo.rotationDegrees)
                        barcodeScanner?.process(inputImage)
                            ?.addOnSuccessListener { barcodes ->
                                for (barcode in barcodes) {
                                    eventSink?.success(barcode.rawValue)
                                }
                            }
                            ?.addOnFailureListener { e ->
                                eventSink?.error("ERROR", "Failed to scan QR code", e.message)
                            }
                            ?.addOnCompleteListener {
                                image.close()
                            }
                    }
                }

            camera = cameraProvider.bindToLifecycle(
                this,
                cameraSelector,
                preview,
                imageAnalyzer
            )

            result.success(true)
        } catch (e: Exception) {
            result.error("CAMERA_ERROR", "Failed to switch camera", e.message)
        }
    }

    private fun requestPermissions(result: Result) {
        result.success(hasCameraPermission())
    }

    private fun hasCameraPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun bindCameraUseCases() {
        try {
            if (::cameraProvider.isInitialized && isScanning) {
                cameraProvider.unbindAll()
                camera = cameraProvider.bindToLifecycle(
                    this,
                    cameraSelector,
                    preview,
                    imageAnalyzer
                )

                // Update preview view
                previewView?.let {
                    preview?.setSurfaceProvider(it.surfaceProvider)
                }
            }
        } catch (e: Exception) {
            eventSink?.error("CAMERA_ERROR", "Failed to bind camera use cases", e.message)
        }
    }

    override fun onListen(arguments: Any?, events: EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        lifecycleRegistry?.currentState = Lifecycle.State.RESUMED
        // Restart camera if it was running
        if (isScanning && ::cameraProvider.isInitialized) {
            bindCameraUseCases()
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        lifecycleRegistry?.currentState = Lifecycle.State.STARTED
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        lifecycleRegistry?.currentState = Lifecycle.State.RESUMED
        // Restart camera if it was running
        if (isScanning && ::cameraProvider.isInitialized) {
            bindCameraUseCases()
        }
    }

    override fun onDetachedFromActivity() {
        lifecycleRegistry?.currentState = Lifecycle.State.CREATED
        if (::cameraProvider.isInitialized) {
            cameraProvider.unbindAll()
        }
        camera = null
    }
}

// Platform View Factory
class CameraViewFactory(private val plugin: UltraQrScannerPlugin) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
        return CameraPlatformView(plugin, context!!, viewId, args)
    }
}

// Platform View Implementation
class CameraPlatformView(
    private val plugin: UltraQrScannerPlugin,
    context: Context,
    viewId: Int,
    args: Any?
) : PlatformView {

    private val frameLayout: FrameLayout = FrameLayout(context)
    private val previewView: PreviewView = plugin.createCameraView()

    init {
        // Set up the preview view with proper layout parameters
        val layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        previewView.layoutParams = layoutParams

        // Set scale type to fill the view
        previewView.scaleType = PreviewView.ScaleType.FILL_CENTER

        // Add the preview view to the frame layout
        frameLayout.addView(previewView)
    }

    override fun getView(): View = frameLayout

    override fun dispose() {
        frameLayout.removeAllViews()
    }
}