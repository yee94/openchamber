package com.yee94.openchamber

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativePlugins.register(flutterEngine, this)
        intent.data?.toString()?.let { NativePlugins.pendingDeepLink = it }
        if (intent.action == ACTION_SHARE_INBOX) {
            NativePlugins.pendingDeepLink = "openchamber://share-inbox"
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.toString()?.let { NativePlugins.open(it) }
        if (intent.action == ACTION_SHARE_INBOX) {
            NativePlugins.open("openchamber://share-inbox")
        }
    }

    companion object {
        const val ACTION_SHARE_INBOX = "com.yee94.openchamber.SHARE_INBOX"
    }
}
