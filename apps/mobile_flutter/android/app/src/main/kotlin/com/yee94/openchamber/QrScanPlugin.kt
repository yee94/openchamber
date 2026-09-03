package com.yee94.openchamber

import android.app.Activity
import android.content.Intent
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class QrScanPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pending: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "openchamber/qr_scanner")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "scan") {
            result.notImplemented()
            return
        }
        val host = activity
        if (host == null) {
            result.error("no_activity", "QR scanner needs an activity", null)
            return
        }
        pending = result
        tryGoogleScanner(host)
    }

    private fun tryGoogleScanner(host: Activity) {
        try {
            val options = GmsBarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                .build()
            val scanner = GmsBarcodeScanning.getClient(host, options)
            scanner.startScan()
                .addOnSuccessListener { barcode ->
                    pending?.success(barcode.rawValue)
                    pending = null
                }
                .addOnCanceledListener {
                    pending?.success(null)
                    pending = null
                }
                .addOnFailureListener {
                    host.startActivityForResult(Intent(host, CameraXQrActivity::class.java), REQUEST)
                }
        } catch (_: Throwable) {
            host.startActivityForResult(Intent(host, CameraXQrActivity::class.java), REQUEST)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val value = data?.getStringExtra(CameraXQrActivity.EXTRA_VALUE)
        pending?.success(if (resultCode == Activity.RESULT_OK) value else null)
        pending = null
        return true
    }

    companion object {
        const val REQUEST = 4411
    }
}
