package com.yee94.openchamber

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object NativePlugins {
    var pendingDeepLink: String? = null
    private var deepLinkChannel: MethodChannel? = null

    fun register(engine: FlutterEngine, activity: MainActivity) {
        engine.plugins.add(SecureStorePlugin())
        engine.plugins.add(QrScanPlugin())
        val messenger = engine.dartExecutor.binaryMessenger
        deepLinkChannel = MethodChannel(messenger, "openchamber/deep_link").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "takeInitial") {
                    val value = pendingDeepLink
                    pendingDeepLink = null
                    result.success(value)
                } else {
                    result.notImplemented()
                }
            }
        }
        MethodChannel(messenger, "openchamber/share").setMethodCallHandler { call, result ->
            when (call.method) {
                "pending" -> {
                    result.success(
                        ShareStore.pending(activity).map { env ->
                            mapOf(
                                "operationID" to env.optString("operationID"),
                                "serverInstanceID" to env.optString("serverInstanceID"),
                                "assistantID" to env.optString("assistantID"),
                                "text" to env.optString("text"),
                            )
                        },
                    )
                }
                "updateCatalog" -> {
                    @Suppress("UNCHECKED_CAST")
                    val entries = call.arguments as? List<Map<String, Any?>> ?: emptyList()
                    ShareStore.updateCatalog(activity, entries)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(messenger, "openchamber/haptics").setMethodCallHandler { call, result ->
            if (call.method == "impact") {
                val strength = (call.arguments as? Map<*, *>)?.get("strength") as? String ?: "light"
                val view = activity.window?.decorView
                val feedback = when (strength) {
                    "medium" -> android.view.HapticFeedbackConstants.KEYBOARD_TAP
                    "heavy" -> android.view.HapticFeedbackConstants.LONG_PRESS
                    else -> android.view.HapticFeedbackConstants.CLOCK_TICK
                }
                view?.performHapticFeedback(feedback)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(messenger, "openchamber/push").setMethodCallHandler { call, result ->
            if (call.method == "requestToken") {
                // FCM token needs the Firebase SDK. Do not invent a token.
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(messenger, "openchamber/widget_snapshot").setMethodCallHandler { call, result ->
            result.success(null)
        }
        MethodChannel(messenger, "openchamber/live_activity").setMethodCallHandler { call, result ->
            when (call.method) {
                "supported" -> result.success(false)
                "start", "update", "end" -> result.success(null)
                else -> result.notImplemented()
            }
        }
        pendingDeepLink?.let { deepLinkChannel?.invokeMethod("opened", it) }
    }

    fun open(uri: String) {
        pendingDeepLink = uri
        deepLinkChannel?.invokeMethod("opened", uri)
    }
}
