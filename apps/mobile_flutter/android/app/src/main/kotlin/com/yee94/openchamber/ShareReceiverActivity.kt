package com.yee94.openchamber

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/// Honors exact instance + assistant extras from Direct Share. Never defaults.
class ShareReceiverActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val extras = shortcutExtras(intent)
        val server = extras?.getString("serverInstanceID")
        val assistant = extras?.getString("assistantID")
        val target = ShareStore.exactTarget(this, server, assistant)
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        if (target == null) {
            ShareStore.writeDraft(this, text)
        } else {
            ShareStore.writeInbox(this, target, text)
        }
        startActivity(
            Intent(this, MainActivity::class.java)
                .setAction(MainActivity.ACTION_SHARE_INBOX)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        )
        finish()
    }

    private fun shortcutExtras(intent: Intent): android.os.PersistableBundle? {
        if (android.os.Build.VERSION.SDK_INT < 25) return null
        val shortcutId = intent.getStringExtra(Intent.EXTRA_SHORTCUT_ID) ?: return null
        val manager = getSystemService(android.content.pm.ShortcutManager::class.java) ?: return null
        return manager.dynamicShortcuts.firstOrNull { it.id == shortcutId }?.extras
    }
}
