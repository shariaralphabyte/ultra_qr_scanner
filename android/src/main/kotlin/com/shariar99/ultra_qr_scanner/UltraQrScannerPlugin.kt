package com.shariar99.ultra_qr_scanner

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.*
import android.hardware.camera2.*
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.util.Size
import android.view.Surface
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.min

class UltraQrScannerPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var scanChannel: EventChannel
    private var context: Context? = null
    private var activity: Activity? = null

    // Camera and scanning components
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var barcodeScanner: BarcodeScanner? = null
    private var cameraExecutor: ExecutorService? = null

    // Performance optimization
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private var scanningEnabled = false
    private var torchEnabled = false

    // Statistics
    private var totalScans = 0
    private var successfulScans = 0
    private var processingTimes = mutableListOf<Long>()
    private var lastFrameTime = 0L
    private var frameCount = 0

    // Configuration
    private var enableGpuAcceleration = true
    private var optimizeForSpeed = true
    private var continuousScanning = false

    companion object {
        private const val PERMISSION_REQUEST_CODE = 1001
        private const val MAX_PROCESSING_TIME_BUFFER = 100
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ultra_qr_scanner")
        channel.setMethodCallHandler(this)

        scanChannel = EventChannel(flutterPluginBinding.binaryMessenger, "ultra_qr_scanner/scan")

        // Register native view factory
        flutterPluginBinding
            .platformViewRegistry
            .registerViewFactory("ultra_qr_scanner_view", ScannerViewFactory(context!!))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        cleanup()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "startScanning" -> startScanning(result)
            "stopScanning" -> stopScanning(result)
            "toggleTorch" -> toggleTorch(result)
            "hasTorch" -> hasTorch(result)
            "focusAt" -> focusAt(call, result)
            "getStats" -> getStats(result)
            "dispose" -> dispose(result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        if (!hasPermissions()) {
            requestPermissions()
            result.success(false)
            return
        }

        try {
            // Get configuration
            enableGpuAcceleration = call.argument("enableGpuAcceleration") ?: true
            optimizeForSpeed = call.argument("optimizeForSpeed") ?: true

            // Initialize background processing
            backgroundThread = HandlerThread("UltraQrScanner").apply { start() }
            backgroundHandler = Handler(backgroundThread!!.looper)

            // Initialize camera executor
            cameraExecutor = Executors.newSingleThreadExecutor()

            // Configure barcode scanner with optimizations
            val options = BarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_QR_CODE) // Focus on QR codes for speed
                .build()

            barcodeScanner = BarcodeScanning.getClient(options)

            result.success(true)
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize: ${e.message}", null)
        }
    }

    private fun startScanning(result: MethodChannel.Result) {
        if (!scanningEnabled) {
            scanningEnabled = true
            setupCamera()
        }
        result.success(true)
    }

    private fun stopScanning(result: MethodChannel.Result) {
        scanningEnabled = false
        cameraProvider?.unbindAll()
        result.success(true)
    }

    private fun setupCamera() {
        val activity = this.activity ?: return
        val context = this.context ?: return

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                bindCameraUseCases(activity)
            } catch (e: Exception) {
                // Handle error
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun bindCameraUseCases(lifecycleOwner: LifecycleOwner) {
        val cameraProvider = this.cameraProvider ?: return

        // Camera selector - prefer back camera
        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

        // Preview use case
        preview = Preview.Builder()
            .setTargetResolution(Size(720, 1280)) // Optimized resolution
            .build()

        // Image analysis for QR scanning
        imageAnalysis = ImageAnalysis.Builder()
            .setTargetResolution(Size(640, 480)) // Lower resolution for faster processing
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also { analysis ->
                analysis.setAnalyzer(cameraExecutor!!) { imageProxy ->
                    processImage(imageProxy)
                }
            }

        try {
            // Unbind use cases before rebinding
            cameraProvider.unbindAll()

            // Bind use cases to camera
            camera = cameraProvider.bindToLifecycle(
                lifecycleOwner,
                cameraSelector,
                preview,
                imageAnalysis
            )

        } catch (e: Exception) {
            // Handle binding error
        }
    }

    private fun processImage(imageProxy: ImageProxy) {
        if (!scanningEnabled) {
            imageProxy.close()
            return
        }

        val currentTime = System.currentTimeMillis()
        val startTime = System.nanoTime()

        totalScans++
        frameCount++

        // Calculate FPS
        if (currentTime - lastFrameTime >= 1000) {
            lastFrameTime = currentTime
            frameCount = 0
        }

        val mediaImage = imageProxy.image
        if (mediaImage != null) {
            val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

            barcodeScanner?.process(image)
                ?.addOnSuccessListener { barcodes ->
                    val processingTime = (System.nanoTime() - startTime) / 1_000_000L // Convert to ms

                    if (barcodes.isNotEmpty()) {
                        successfulScans++

                        // Update processing times buffer
                        processingTimes.add(processingTime)
                        if (processingTimes.size > MAX_PROCESSING_TIME_BUFFER) {
                            processingTimes.removeAt(0)
                        }

                        val barcode = barcodes[0]
                        val result = mapOf(
                            "data" to (barcode.rawValue ?: ""),
                            "format" to getFormatName(barcode.format),
                            "corners" to barcode.cornerPoints?.map { point ->
                                mapOf("x" to point.x.toDouble(), "y" to point.y.toDouble())
                            } ?: emptyList<Map<String, Double>>(),
                            "timestamp" to currentTime,
                            "confidence" to 1.0, // ML Kit doesn't provide confidence
                            "processingTimeMs" to processingTime.toInt()
                        )

                        // Send result through event channel
                        activity?.runOnUiThread {
                            scanChannel.setStreamHandler(object : EventChannel.StreamHandler {
                                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                                    events?.success(result)

                                    if (!continuousScanning) {
                                        scanningEnabled = false
                                    }
                                }

                                override fun onCancel(arguments: Any?) {}
                            })
                        }
                    }
                }
                ?.addOnCompleteListener {
                    imageProxy.close()
                }
        } else {
            imageProxy.close()
        }
    }

    private fun getFormatName(format: Int): String {
        return when (format) {
            Barcode.FORMAT_QR_CODE -> "qr"
            Barcode.FORMAT_DATA_MATRIX -> "dataMatrix"
            Barcode.FORMAT_CODE_128 -> "code128"
            Barcode.FORMAT_CODE_39 -> "code39"
            Barcode.FORMAT_CODE_93 -> "code93"
            Barcode.FORMAT_EAN_8 -> "ean8"
            Barcode.FORMAT_EAN_13 -> "ean13"
            Barcode.FORMAT_UPC_A -> "upca"
            Barcode.FORMAT_UPC_E -> "upce"
            Barcode.FORMAT_PDF417 -> "pdf417"
            Barcode.FORMAT_AZTEC -> "aztec"
            else -> "unknown"
        }
    }

    private fun toggleTorch(result: MethodChannel.Result) {
        val camera = this.camera
        if (camera?.cameraInfo?.hasFlashUnit() == true) {
            torchEnabled = !torchEnabled
            camera.cameraControl.enableTorch(torchEnabled)
            result.success(torchEnabled)
        } else {
            result.success(false)
        }
    }

    private fun hasTorch(result: MethodChannel.Result) {
        val hasTorch = camera?.cameraInfo?.hasFlashUnit() ?: false
        result.success(hasTorch)
    }

    private fun focusAt(call: MethodCall, result: MethodChannel.Result) {
        val x = call.argument<Double>("x") ?: 0.5
        val y = call.argument<Double>("y") ?: 0.5

        val camera = this.camera
        if (camera != null) {
            val factory = SurfaceOrientedMeteringPointFactory(1.0f, 1.0f)
            val point = factory.createPoint(x.toFloat(), y.toFloat())
            val action = FocusMeteringAction.Builder(point).build()

            camera.cameraControl.startFocusAndMetering(action)
            result.success(true)
        } else {
            result.success(false)
        }
    }

    private fun getStats(result: MethodChannel.Result) {
        val averageProcessingTime = if (processingTimes.isNotEmpty()) {
            processingTimes.average()
        } else {
            0.0
        }

        val successRate = if (totalScans > 0) {
            (successfulScans.toDouble() / totalScans.toDouble()) * 100
        } else {
            0.0
        }

        val stats = mapOf(
            "totalScans" to totalScans,
            "successfulScans" to successfulScans,
            "averageProcessingTime" to averageProcessingTime,
            "successRate" to successRate,
            "framesPerSecond" to frameCount
        )

        result.success(stats)
    }

    private fun dispose(result: MethodChannel.Result) {
        cleanup()
        result.success(true)
    }

    private fun cleanup() {
        scanningEnabled = false
        cameraProvider?.unbindAll()
        cameraExecutor?.shutdown()
        backgroundThread?.quitSafely()
        backgroundHandler = null
        barcodeScanner?.close()

        // Reset statistics
        totalScans = 0
        successfulScans = 0
        processingTimes.clear()
        frameCount = 0
    }

    private fun hasPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(
            context!!,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermissions() {
        activity?.let { act ->
            ActivityCompat.requestPermissions(
                act,
                arrayOf(Manifest.permission.CAMERA),
                PERMISSION_REQUEST_CODE
            )
        }
    }
}