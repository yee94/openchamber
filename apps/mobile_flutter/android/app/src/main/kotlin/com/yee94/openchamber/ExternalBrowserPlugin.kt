package com.yee94.openchamber

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Official Capacitor plugin is OpenChamberExternalBrowser (`open` + http(s) URL).
class ExternalBrowserPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "openchamber/external_browser")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "open") {
            result.notImplemented()
            return
        }
        val rawUrl = (call.argument<String>("url") ?: "").trim()
        val url = Uri.parse(rawUrl)
        val scheme = url.scheme
        if (rawUrl.isEmpty() || url.host.isNullOrEmpty() ||
            !("http".equals(scheme, ignoreCase = true) || "https".equals(scheme, ignoreCase = true))
        ) {
            result.error("invalid_url", "An http(s) URL is required.", null)
            return
        }
        val host = activity
        if (host == null) {
            result.error("unavailable", "The browser is unavailable.", null)
            return
        }
        host.runOnUiThread {
            try {
                host.startActivity(Intent(Intent.ACTION_VIEW, url).addCategory(Intent.CATEGORY_BROWSABLE))
                result.success(null)
            } catch (_: ActivityNotFoundException) {
                result.error("unavailable", "The browser is unavailable.", null)
            }
        }
    }
}
