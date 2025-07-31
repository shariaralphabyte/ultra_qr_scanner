package com.shariar99.ultra_qr_scanner

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class UltraQrScannerPlugin: FlutterPlugin, MethodChannel.MethodCallHandler,
  ActivityAware, PluginRegistry.RequestPermissionsResultListener {

  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var activity: Activity? = null
  private var context: Context? = null

  private var cameraProvider: ProcessCameraProvider? = null
  private var camera: Camera? = null
  private var previewView: PreviewView? = null
  private var imageAnalyzer: ImageAnalysis? = null
  private var currentCameraPosition = CameraSelector.LENS_FACING_BACK

  private val isScanning = AtomicBoolean(false)
  private val isPrepared = AtomicBoolean(false)
  private val frameSkipCounter = AtomicBoolean(false)

  private var eventSink: EventChannel.EventSink? = null
  private lateinit var cameraExecutor: ExecutorService
  private val scannerScope = CoroutineScope(Dispatchers.Default + SupervisorJob())

  // MLKit scanner with optimized options
  private val barcodeScanner by lazy {
    val options = BarcodeScannerOptions.Builder()
      .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
      .build()
    BarcodeScanning.getClient(options)
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "ultra_qr_scanner")
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "ultra_qr_scanner_events")

    methodChannel.setMethodCallHandler(this)
    eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
      }

      override fun onCancel(arguments: Any?) {
        eventSink = null
      }
    })

    cameraExecutor = Executors.newSingleThreadExecutor()
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "prepareScanner" -> prepareScanner(result)
      "scanOnce" -> scanOnce(result)
      "startScanStream" -> startScanStream(result)
      "stopScanner" -> stopScanner(result)
      "toggleFlash" -> toggleFlash(call.argument<Boolean>("enabled") ?: false, result)
      "pauseDetection" -> pauseDetection(result)
      "resumeDetection" -> resumeDetection(result)
      "requestPermissions" -> requestPermissions(result)
      "switchCamera" -> switchCamera(call.argument<String>("position") ?: "back", result)
      else -> result.notImplemented()
    }
  }

  private fun prepareScanner(result: MethodChannel.Result) {
    if (isPrepared.get()) {
      result.success(null)
      return
    }

    // Check permissions first
    val cameraPermission = Manifest.permission.CAMERA
    val hasPermission = ContextCompat.checkSelfPermission(context!!, cameraPermission) == PackageManager.PERMISSION_GRANTED

    if (!hasPermission) {
      result.error("PERMISSION_DENIED", "Camera permission not granted", null)
      return
    }

    scannerScope.launch {
      try {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context!!)
        cameraProvider = cameraProviderFuture.get()

        withContext(Dispatchers.Main) {
          setupCamera()
          isPrepared.set(true)
          result.success(null)
        }
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          result.error("PREPARE_ERROR", e.message ?: "Failed to prepare camera", e)
        }
      }
    }
  }

  private fun setupCamera() {
    previewView = PreviewView(context!!)
    previewView?.scaleType = PreviewView.ScaleType.FIT_CENTER

    val preview = Preview.Builder()
      .setTargetResolution(android.util.Size(640, 480))
      .setTargetRotation(Surface.ROTATION_0)
      .build()

    imageAnalyzer = ImageAnalysis.Builder()
      .setTargetResolution(android.util.Size(640, 480))
      .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
      .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888)
      .build()

    imageAnalyzer?.setAnalyzer(cameraExecutor) { imageProxy ->
      processImageProxy(imageProxy)
    }

    val cameraSelector = when (currentCameraPosition) {
      CameraSelector.LENS_FACING_BACK -> CameraSelector.DEFAULT_BACK_CAMERA
      else -> CameraSelector.DEFAULT_FRONT_CAMERA
    }

    try {
      cameraProvider?.unbindAll()
      camera = cameraProvider?.bindToLifecycle(
        activity as LifecycleOwner,
        cameraSelector,
        preview,
        imageAnalyzer
      )

      preview.setSurfaceProvider(previewView?.surfaceProvider)
    } catch (e: Exception) {
      eventSink?.error("CAMERA_ERROR", e.message, e)
    }
  }

  private fun processImageProxy(imageProxy: ImageProxy) {
    if (!isScanning.get()) {
      imageProxy.close()
      return
    }

    // Frame throttling - process every 3rd frame
    if (!frameSkipCounter.compareAndSet(false, true)) {
      frameSkipCounter.set(false)
      imageProxy.close()
      return
    }

    val rotationDegrees = imageProxy.imageInfo.rotationDegrees
    val image = imageProxy.image ?: return

    try {
      // Create MLKit input image
      val inputImage = InputImage.fromMediaImage(image, rotationDegrees)
      
      // Process with MLKit
      barcodeScanner.process(inputImage)
        .addOnSuccessListener { barcodes ->
          if (barcodes.isNotEmpty() && isScanning.get()) {
            val qrCode = barcodes.first().rawValue
            if (!qrCode.isNullOrEmpty()) {
              isScanning.set(false)
              eventSink?.success(qrCode)
              
              // Auto-stop camera after detection
              scannerScope.launch(Dispatchers.Main) {
                stopCameraInternal()
              }
            }
          }
        }
        .addOnFailureListener { e ->
          eventSink?.error("SCAN_ERROR", e.message, e)
        }
        .addOnCompleteListener {
          imageProxy.close()
        }
    } catch (e: Exception) {
      eventSink?.error("SCAN_ERROR", e.message, e)
      imageProxy.close()
    }
  }

  private fun stopCameraInternal() {
    scannerScope.launch(Dispatchers.Main) {
      cameraProvider?.unbindAll()
      camera = null
      previewView = null
      imageAnalyzer = null
      cameraExecutor.shutdown()
    }
  }
  }

  private fun switchCamera(position: String, result: MethodChannel.Result) {
    scannerScope.launch {
      try {
        currentCameraPosition = when (position) {
          "front" -> CameraSelector.LENS_FACING_FRONT
          else -> CameraSelector.LENS_FACING_BACK
        }

        setupCamera()
        result.success(true)
      } catch (e: Exception) {
        withContext(Dispatchers.Main) {
          result.error("CAMERA_ERROR", e.message, e)
        }
      }
    }
  }

  private fun processImageProxy(imageProxy: ImageProxy) {
    if (!isScanning.get()) {
      imageProxy.close()
      return
    }

    // Frame throttling - process every 3rd frame
    if (!frameSkipCounter.compareAndSet(false, true)) {
      frameSkipCounter.set(false)
      imageProxy.close()
      return
    }

    scannerScope.launch {
      try {
        val inputImage = InputImage.fromMediaImage(
          imageProxy.image!!,
          imageProxy.imageInfo.rotationDegrees
        )

        barcodeScanner.process(inputImage)
          .addOnSuccessListener { barcodes ->
            if (barcodes.isNotEmpty() && isScanning.get()) {
              val qrCode = barcodes.first().rawValue
              if (!qrCode.isNullOrEmpty()) {
                isScanning.set(false)
                eventSink?.success(qrCode)

                // Auto-stop camera after detection
                CoroutineScope(Dispatchers.Main).launch {
                  stopCameraInternal()
                }
              }
            }
          }
          .addOnCompleteListener {
            imageProxy.close()
          }
      } catch (e: Exception) {
        imageProxy.close()
      }
    }
  }

  private fun scanOnce(result: MethodChannel.Result) {
    if (!isPrepared.get()) {
      result.error("NOT_PREPARED", "Scanner not prepared", null)
      return
    }

    isScanning.set(true)

    // Set up one-time listener
    val originalSink = eventSink
    eventSink = object : EventChannel.EventSink {
      override fun success(event: Any?) {
        originalSink?.success(event)
        result.success(event)
        eventSink = originalSink
      }

      override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
        originalSink?.error(errorCode, errorMessage, errorDetails)
        result.error(errorCode ?: "SCAN_ERROR", errorMessage, errorDetails)
        eventSink = originalSink
      }

      override fun endOfStream() {
        originalSink?.endOfStream()
        eventSink = originalSink
      }
    }

    startCameraInternal()
  }

  private fun startScanStream(result: MethodChannel.Result) {
    if (!isPrepared.get()) {
      result.error("NOT_PREPARED", "Scanner not prepared", null)
      return
    }

    isScanning.set(true)
    startCameraInternal()
    result.success(null)
  }

  private fun startCameraInternal() {
    CoroutineScope(Dispatchers.Main).launch {
      try {
        if (camera == null) {
          setupCamera()
        }
      } catch (e: Exception) {
        eventSink?.error("START_ERROR", e.message, null)
      }
    }
  }

  private fun stopScanner(result: MethodChannel.Result) {
    isScanning.set(false)
    stopCameraInternal()
    result.success(null)
  }

  private fun stopCameraInternal() {
    cameraProvider?.unbindAll()
    camera = null
  }

  private fun toggleFlash(enabled: Boolean, result: MethodChannel.Result) {
    try {
      if (camera?.cameraInfo?.hasFlashUnit() == true) {
        camera?.cameraControl?.enableTorch(enabled)
        result.success(null)
      } else {
        result.error("NO_FLASH", "Flash not available", null)
      }
    } catch (e: Exception) {
      result.error("FLASH_ERROR", e.message, null)
    }
  }

  private fun pauseDetection(result: MethodChannel.Result) {
    isScanning.set(false)
    result.success(null)
  }

  private fun resumeDetection(result: MethodChannel.Result) {
    isScanning.set(true)
    result.success(null)
  }

  private fun requestPermissions(result: MethodChannel.Result) {
    val permission = Manifest.permission.CAMERA
    if (ContextCompat.checkSelfPermission(context!!, permission) == PackageManager.PERMISSION_GRANTED) {
      result.success(true)
    } else {
      ActivityCompat.requestPermissions(activity!!, arrayOf(permission), 1001)
      // Result will be handled in onRequestPermissionsResult
    }
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
  ): Boolean {
    if (requestCode == 1001) {
      val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
      methodChannel.invokeMethod("onPermissionResult", granted)
      return true
    }
    return false
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivity() {
    activity = null
    scannerScope.cancel()
    cameraExecutor.shutdown()
    cameraProvider?.unbindAll()
    cameraProvider = null
    camera = null
    previewView = null
    imageAnalyzer = null
    eventSink = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    cameraExecutor.shutdown()
    scannerScope.cancel()
    barcodeScanner.close()
  }
}