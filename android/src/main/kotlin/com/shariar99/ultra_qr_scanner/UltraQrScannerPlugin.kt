package com.shariar99.ultra_qr_scanner

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.os.Build
import androidx.annotation.NonNull
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
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

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        messenger = binding.binaryMessenger
        context = binding.applicationContext

        val methodChannel = MethodChannel(messenger, "ultra_qr_scanner")
        methodChannel.setMethodCallHandler(this)

        val eventChannel = EventChannel(messenger, "ultra_qr_scanner_events")
        eventChannel.setStreamHandler(this)

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
                        .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                        .build()
                    barcodeScanner = BarcodeScanning.getClient(options)

                    // Initialize image analyzer
                    imageAnalyzer = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .also { analyzer ->
                            analyzer.setAnalyzer(cameraExecutor) { image ->
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

            // Initialize preview
            preview = Preview.Builder()
                .build()

            // Bind use cases
            cameraProvider.unbindAll()
            camera = cameraProvider.bindToLifecycle(
                this,
                cameraSelector,
                preview,
                imageAnalyzer
            )

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

    override fun onListen(arguments: Any?, events: EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        lifecycleRegistry?.currentState = Lifecycle.State.RESUMED
    }

    override fun onDetachedFromActivityForConfigChanges() {
        lifecycleRegistry?.currentState = Lifecycle.State.STARTED
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        lifecycleRegistry?.currentState = Lifecycle.State.RESUMED
    }

    override fun onDetachedFromActivity() {
        lifecycleRegistry?.currentState = Lifecycle.State.CREATED
        cameraProvider.unbindAll()
        camera = null
    }
}