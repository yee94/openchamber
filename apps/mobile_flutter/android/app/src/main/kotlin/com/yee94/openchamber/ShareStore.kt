package com.yee94.openchamber

import android.content.Context
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject

object ShareStore {
    const val SHARE_TARGET_CATEGORY = "com.yee94.openchamber.SHARE_ASSISTANT"
    private const val PREFS = "openchamber-share"
    private const val CATALOG = "openchamberShareCatalog"
    private const val INBOX = "openchamberShareInbox"

    fun catalog(context: Context): List<JSONObject> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(CATALOG, "[]")
        val array = JSONArray(raw)
        return buildList {
            for (i in 0 until array.length()) add(array.getJSONObject(i))
        }
    }

    fun updateCatalog(context: Context, entries: List<Map<String, Any?>>) {
        val array = JSONArray()
        entries.forEach { entry ->
            val obj = JSONObject()
            entry.forEach { (key, value) -> obj.put(key, value ?: JSONObject.NULL) }
            array.put(obj)
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(CATALOG, array.toString()).apply()
        refreshShortcuts(context)
    }

    fun exactTarget(context: Context, serverInstanceId: String?, assistantId: String?): JSONObject? {
        if (serverInstanceId.isNullOrEmpty() || assistantId.isNullOrEmpty()) return null
        return catalog(context).firstOrNull { entry ->
            entry.optBoolean("enabled", true) &&
                entry.optString("serverInstanceID") == serverInstanceId &&
                entry.optString("assistantID") == assistantId
        }
    }

    fun writeInbox(context: Context, target: JSONObject, text: String?) {
        val envelope = JSONObject()
            .put("operationID", java.util.UUID.randomUUID().toString())
            .put("serverInstanceID", target.getString("serverInstanceID"))
            .put("assistantID", target.getString("assistantID"))
            .put("text", text)
            .put("source", "android-share")
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val inbox = JSONArray(prefs.getString(INBOX, "[]"))
        inbox.put(envelope)
        prefs.edit().putString(INBOX, inbox.toString()).apply()
    }

    fun pending(context: Context): List<JSONObject> {
        val inbox = JSONArray(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(INBOX, "[]"))
        return buildList {
            for (i in 0 until inbox.length()) add(inbox.getJSONObject(i))
        }
    }

    private fun refreshShortcuts(context: Context) {
        if (android.os.Build.VERSION.SDK_INT < 25) return
        val manager = context.getSystemService(ShortcutManager::class.java) ?: return
        val shortcuts = catalog(context).mapNotNull { entry ->
            if (!entry.optBoolean("enabled", true)) return@mapNotNull null
            val server = entry.optString("serverInstanceID")
            val assistant = entry.optString("assistantID")
            if (server.isEmpty() || assistant.isEmpty()) return@mapNotNull null
            val extras = android.os.PersistableBundle().apply {
                putString("serverInstanceID", server)
                putString("assistantID", assistant)
            }
            ShortcutInfo.Builder(context, "$server/$assistant")
                .setShortLabel(entry.optString("name", assistant))
                .setIcon(Icon.createWithResource(context, R.mipmap.ic_launcher))
                .setCategories(setOf(SHARE_TARGET_CATEGORY))
                .setIntent(
                    Intent(context, ShareReceiverActivity::class.java)
                        .setAction(Intent.ACTION_SEND)
                        .setType("text/plain"),
                )
                .setExtras(extras)
                .build()
        }
        manager.dynamicShortcuts = shortcuts.take(4)
    }
}
