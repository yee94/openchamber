package com.yee94.openchamber

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object NativePlugins {
    var pendingDeepLink: String? = null
    var pendingPushOpen: Map<String, Any?>? = null
    private var deepLinkChannel: MethodChannel? = null
    private var pushChannel: MethodChannel? = null

    fun register(engine: FlutterEngine, activity: MainActivity) {
        engine.plugins.add(SecureStorePlugin())
        engine.plugins.add(QrScanPlugin())
        engine.plugins.add(MediaPlugin())
        engine.plugins.add(VirtualAssetPlugin())
        engine.plugins.add(ExternalBrowserPlugin())
        engine.platformViewsController.registry.registerViewFactory(
            "openchamber/html_preview_view",
            HtmlPreviewViewFactory(),
        )
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
                "listPending", "pending" -> {
                    result.success(mapOf("envelopes" to ShareStore.pending(activity).map { envelopeMap(it) }))
                }
                "listDrafts" -> {
                    result.success(mapOf("drafts" to ShareStore.drafts(activity).map { draftMap(it) }))
                }
                "updateCatalog" -> {
                    @Suppress("UNCHECKED_CAST")
                    val entries = call.arguments as? List<Map<String, Any?>> ?: emptyList()
                    ShareStore.updateCatalog(activity, entries)
                    result.success(null)
                }
                "ack", "acknowledge" -> {
                    ShareStore.ack(activity, argumentId(call.arguments, "operationID"))
                    result.success(null)
                }
                "releaseFiles" -> {
                    ShareStore.releaseFiles(activity, argumentId(call.arguments, "operationID"))
                    result.success(null)
                }
                "cancelDraft" -> {
                    ShareStore.cancelDraft(activity, argumentId(call.arguments, "draftID"))
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
        pushChannel = MethodChannel(messenger, "openchamber/push").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestToken" -> requestFcmToken(activity, result)
                    "takeInitialOpen" -> {
                        val value = pendingPushOpen
                        pendingPushOpen = null
                        result.success(value)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        // Cold-start notification taps put FCM data on the launch intent.
        // Native FirebaseMessaging has token, not FlutterFire's getInitialMessage().
        capturePushOpen(activity.intent)
        MethodChannel(messenger, "openchamber/widget_snapshot").setMethodCallHandler { call, result ->
            if (call.method == "setBadge" || call.method == "write") {
                // Official push relay has no FCM send path (APNs aps.badge only).
                // Do not invent ShortcutBadger or a fake notification count.
                result.success(null)
            } else {
                result.notImplemented()
            }
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

    fun handleIntent(intent: Intent) {
        intent.data?.toString()?.let { open(it) }
        if (intent.action == MainActivity.ACTION_SHARE_INBOX) {
            open("openchamber://share-inbox")
        }
        capturePushOpen(intent)
    }

    private fun capturePushOpen(intent: Intent?) {
        val payload = pushPayload(intent) ?: return
        pendingPushOpen = payload
        pushChannel?.invokeMethod("opened", payload)
    }

    private fun pushPayload(intent: Intent?): Map<String, Any?>? {
        val extras = intent?.extras ?: return null
        val map = mutableMapOf<String, Any?>()
        for (key in extras.keySet()) {
            map[key] = extras.get(key)?.toString()
        }
        val url = map["url"]?.toString().orEmpty()
        val deeplink = map["deeplink"]?.toString().orEmpty()
        val sessionId = map["sessionId"]?.toString().orEmpty().ifEmpty { map["sessionID"]?.toString().orEmpty() }
        if (url.isEmpty() && deeplink.isEmpty() && sessionId.isEmpty()) return null
        return map
    }

    private fun argumentId(arguments: Any?, key: String): String {
        val map = arguments as? Map<*, *> ?: return ""
        return map[key]?.toString() ?: ""
    }

    private fun envelopeMap(env: org.json.JSONObject): Map<String, Any?> {
        return mapOf(
            "operationID" to env.optString("operationID"),
            "serverInstanceID" to env.optString("serverInstanceID"),
            "assistantID" to env.optString("assistantID"),
            "text" to env.optString("text"),
            "source" to env.optString("source", "android-share"),
            "createdAt" to env.optLong("createdAt"),
            "expiresAt" to env.optLong("expiresAt"),
        )
    }

    private fun draftMap(draft: org.json.JSONObject): Map<String, Any?> {
        return mapOf(
            "draftID" to draft.optString("draftID"),
            "serverInstanceID" to draft.optString("serverInstanceID").ifEmpty { null },
            "assistantID" to draft.optString("assistantID").ifEmpty { null },
            "text" to draft.optString("text"),
            "source" to draft.optString("source", "android-share"),
            "createdAt" to draft.optLong("createdAt"),
            "expiresAt" to draft.optLong("expiresAt"),
        )
    }

    private fun requestFcmToken(activity: MainActivity, result: MethodChannel.Result) {
        try {
            com.google.firebase.FirebaseApp.initializeApp(activity)
            com.google.firebase.messaging.FirebaseMessaging.getInstance().token
                .addOnCompleteListener { task ->
                    if (!task.isSuccessful) {
                        // Do not invent a token when Firebase is unavailable.
                        result.success(null)
                        return@addOnCompleteListener
                    }
                    val token = task.result
                    if (token.isNullOrEmpty()) {
                        result.success(null)
                    } else {
                        result.success(mapOf("token" to token, "platform" to "android"))
                    }
                }
        } catch (_: Exception) {
            result.success(null)
        }
    }
}
