package com.shariar99.ultra_qr_scanner

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
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

class UltraQrScannerPlugin: FlutterPlugin, MethodCallHandler, StreamHandler, ActivityAware {
    private lateinit var messenger: BinaryMessenger
    private lateinit var context: Context
    private lateinit var cameraProvider: ProcessCameraProvider
    private lateinit var cameraExecutor: ExecutorService
    private var eventSink: EventSink? = null
    private var isScanning = false
    private var isPrepared = false
    private var isFlashOn = false
    private var cameraSelector: CameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
    private var preview: Preview? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private var barcodeScanner: BarcodeScanner? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        messenger = flutterPluginBinding.binaryMessenger
        context = flutterPluginBinding.applicationContext
        
        val methodChannel = MethodChannel(messenger, "ultra_qr_scanner")
        methodChannel.setMethodCallHandler(this)

        val eventChannel = EventChannel(messenger, "ultra_qr_scanner_events")
        eventChannel.setStreamHandler(this)

        cameraExecutor = Executors.newSingleThreadExecutor()
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "prepareScanner" -> prepareScanner(result)
            "scanOnce" -> scanOnce(result)
            "startScanStream" -> startScanStream(result)
            "stopScanner" -> stopScanner(result)
            "toggleFlash" -> toggleFlash(call, result)
            "requestPermissions" -> requestPermissions(result)
            "switchCamera" -> switchCamera(call, result)
            else -> result.notImplemented()
        }
    }

    private fun prepareScanner(result: Result) {
        if (isPrepared) {
            result.success(true)
            return
        }

        if (!hasCameraPermission()) {
            result.error("PERMISSION_DENIED", "Camera permission not granted", null)
            return
        }

        try {
            val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            cameraProviderFuture.addListener({
                cameraProvider = cameraProviderFuture.get()
                isPrepared = true
                result.success(true)
            }, ContextCompat.getMainExecutor(context))
        } catch (e: Exception) {
            result.error("ERROR", e.message, e.localizedMessage)
        }
    }

    private fun scanOnce(result: Result) {
        if (!isPrepared) {
            result.error("NOT_PREPARED", "Scanner not prepared", null)
            return
        }

        isScanning = true
        startCameraPreview()
        result.success(null)
    }

    private fun startScanStream(result: Result) {
        if (!isPrepared) {
            result.error("NOT_PREPARED", "Scanner not prepared", null)
            return
        }

        isScanning = true
        startCameraPreview()
        result.success(null)
    }

    private fun stopScanner(result: Result) {
        isScanning = false
        preview?.unbindAll()
        result.success(true)
    }

    private fun toggleFlash(call: MethodCall, result: Result) {
        if (!isPrepared) {
            result.error("NOT_PREPARED", "Scanner not prepared", null)
            return
        }

        val enabled = call.argument<Boolean>("enabled") ?: false
        isFlashOn = enabled
        
        try {
            val camera = cameraProvider.getCamera(cameraSelector)
            val characteristics = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = characteristics.cameraIdList.firstOrNull { id ->
                characteristics.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING) == 
                if (cameraSelector == CameraSelector.DEFAULT_BACK_CAMERA) CameraMetadata.LENS_FACING_BACK else CameraMetadata.LENS_FACING_FRONT
            }
            
            if (cameraId == null || !characteristics.getCameraCharacteristics(cameraId).get(CameraCharacteristics.FLASH_INFO_AVAILABLE)!!) {
                result.error("NO_FLASH", "Flash not available", null)
                return
            }

            camera.cameraControl.enableTorch(enabled)
            result.success(true)
        } catch (e: Exception) {
            result.error("FLASH_ERROR", e.message ?: "Failed to toggle flash", e.localizedMessage)
        }
    }

    private fun switchCamera(call: MethodCall, result: Result) {
        if (!isPrepared) {
            result.error("NOT_PREPARED", "Scanner not prepared", null)
            return
        }

        val position = call.argument<String>("position") ?: "back"
        cameraSelector = if (position == "front") {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }
        startCameraPreview()
        result.success(true)
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

    private fun startCameraPreview() {
        preview = Preview.Builder().build()
        imageAnalyzer = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also {
                it.setAnalyzer(cameraExecutor) { image ->
                    val imageProxy = image.image ?: return@setAnalyzer
                    val inputImage = InputImage.fromMediaImage(imageProxy, image.imageInfo.rotationDegrees)
                    processImage(inputImage)
                    image.close()
                }
            }

        try {
            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(
                context as ActivityPluginBinding.ActivityContext,
                cameraSelector,
                preview,
                imageAnalyzer
            )
        } catch (e: Exception) {
            eventSink?.error("ERROR", e.message ?: "Failed to start camera", e.localizedMessage)
        }
    }

    private fun processImage(image: InputImage) {
        if (!isScanning) return

        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build()
        barcodeScanner = BarcodeScanning.getClient(options)

        barcodeScanner?.process(image)
            ?.addOnSuccessListener { barcodes ->
                for (barcode in barcodes) {
                    val qrCode = barcode.rawValue ?: continue
                    eventSink?.success(qrCode)
                    if (!isScanning) break
                }
            }
            ?.addOnFailureListener { e ->
                eventSink?.error("ERROR", e.message ?: "Failed to process image", e.localizedMessage)
            }
    }

    override fun onListen(arguments: Any?, events: EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        // Handle activity lifecycle
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // Handle config changes
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        // Handle config changes
    }

    override fun onDetachedFromActivity() {
        // Cleanup
        cameraExecutor.shutdown()
        preview?.unbindAll()
    }
}
