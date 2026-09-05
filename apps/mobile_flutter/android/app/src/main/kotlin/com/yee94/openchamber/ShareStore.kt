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
    private const val DRAFTS = "openchamberShareDrafts"

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
        val now = System.currentTimeMillis()
        val envelope = JSONObject()
            .put("operationID", java.util.UUID.randomUUID().toString())
            .put("serverInstanceID", target.getString("serverInstanceID"))
            .put("assistantID", target.getString("assistantID"))
            .put("text", text)
            .put("source", "android-share")
            .put("createdAt", now)
            .put("expiresAt", now + 24L * 60L * 60L * 1000L)
            .put("attachments", JSONArray())
        putJson(context, INBOX, envelope)
    }

    fun writeDraft(context: Context, text: String?) {
        val now = System.currentTimeMillis()
        val draft = JSONObject()
            .put("draftID", java.util.UUID.randomUUID().toString())
            .put("text", text)
            .put("source", "android-share")
            .put("createdAt", now)
            .put("expiresAt", now + 24L * 60L * 60L * 1000L)
            .put("attachments", JSONArray())
        putJson(context, DRAFTS, draft)
    }

    fun pending(context: Context): List<JSONObject> = readJsonList(context, INBOX)

    fun drafts(context: Context): List<JSONObject> = readJsonList(context, DRAFTS)

    fun ack(context: Context, operationID: String) {
        removeJson(context, INBOX, "operationID", operationID)
    }

    fun releaseFiles(context: Context, operationID: String) {
        removeJson(context, INBOX, "operationID", operationID)
    }

    fun cancelDraft(context: Context, draftID: String) {
        removeJson(context, DRAFTS, "draftID", draftID)
    }

    private fun readJsonList(context: Context, key: String): List<JSONObject> {
        val inbox = JSONArray(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(key, "[]"))
        return buildList {
            for (i in 0 until inbox.length()) add(inbox.getJSONObject(i))
        }
    }

    private fun putJson(context: Context, key: String, item: JSONObject) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(key, "[]"))
        array.put(item)
        prefs.edit().putString(key, array.toString()).apply()
    }

    private fun removeJson(context: Context, key: String, idField: String, id: String) {
        if (id.isEmpty()) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val array = JSONArray(prefs.getString(key, "[]"))
        val next = JSONArray()
        for (i in 0 until array.length()) {
            val item = array.getJSONObject(i)
            if (item.optString(idField) != id) next.put(item)
        }
        prefs.edit().putString(key, next.toString()).apply()
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
