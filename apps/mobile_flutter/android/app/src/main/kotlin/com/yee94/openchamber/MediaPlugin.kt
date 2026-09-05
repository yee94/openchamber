package com.yee94.openchamber

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Base64
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class MediaPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pending: MethodChannel.Result? = null
    private var pendingSave: MethodChannel.Result? = null
    private var pendingSavePath: String? = null
    private val executor = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "openchamber/media")
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
        when (call.method) {
            "pickMedia" -> pickMedia(call, result)
            "pickFiles" -> pickFiles(call, result)
            "transcode" -> transcode(call, result)
            "saveFile" -> saveFile(call, result)
            else -> result.notImplemented()
        }
    }

    private fun pickMedia(call: MethodCall, result: MethodChannel.Result) {
        val host = activity
        if (host == null) {
            result.error("no_activity", "Photo picker needs an activity", null)
            return
        }
        if (pending != null) {
            result.error("busy", "Picker already open", null)
            return
        }
        var limit = call.argument<Int>("limit") ?: 20
        var maxLimit = 100
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                val systemMax = MediaStore.getPickImagesMaxLimit()
                if (systemMax > 0) maxLimit = systemMax
            } catch (_: Exception) {
                maxLimit = 100
            }
        }
        if (limit < 1) limit = 1
        if (limit > maxLimit) limit = maxLimit
        pending = result
        val intent = Intent(MediaStore.ACTION_PICK_IMAGES)
        intent.putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, limit)
        try {
            host.startActivityForResult(intent, REQUEST)
        } catch (_: ActivityNotFoundException) {
            val fallback = Intent(Intent.ACTION_GET_CONTENT)
            fallback.addCategory(Intent.CATEGORY_OPENABLE)
            fallback.type = "image/*"
            fallback.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            fallback.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            try {
                host.startActivityForResult(fallback, REQUEST)
            } catch (error: ActivityNotFoundException) {
                pending = null
                result.error("unavailable", error.message ?: "Photo picker is unavailable", null)
            }
        }
    }

    private fun pickFiles(call: MethodCall, result: MethodChannel.Result) {
        val host = activity
        if (host == null) {
            result.error("no_activity", "File picker needs an activity", null)
            return
        }
        if (pending != null) {
            result.error("busy", "Picker already open", null)
            return
        }
        pending = result
        val intent = Intent(Intent.ACTION_GET_CONTENT)
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.type = "*/*"
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        try {
            host.startActivityForResult(intent, REQUEST_FILES)
        } catch (error: ActivityNotFoundException) {
            pending = null
            result.error("unavailable", error.message ?: "File picker is unavailable", null)
        }
    }

    private fun saveFile(call: MethodCall, result: MethodChannel.Result) {
        var data = call.argument<String>("dataBase64").orEmpty()
        val comma = data.indexOf(',')
        if (data.startsWith("data:", ignoreCase = true) && comma >= 0) {
            data = data.substring(comma + 1)
        }
        if (data.isEmpty()) {
            result.error("invalid", "dataBase64 is required", null)
            return
        }
        val filename = sanitizeExportFilename(call.argument<String>("filename") ?: "export.json")
        val host = activity
        if (host == null) {
            result.error("no_activity", "No activity to present the save picker", null)
            return
        }
        if (pendingSave != null || pending != null) {
            result.error("busy", "Picker already open", null)
            return
        }
        executor.execute {
            try {
                val bytes = Base64.decode(data, Base64.DEFAULT)
                if (bytes == null || bytes.isEmpty() || bytes.size > MAX_BYTES) {
                    host.runOnUiThread { result.error("invalid", "File data is empty or too large", null) }
                    return@execute
                }
                val dir = File(host.cacheDir, "save-file")
                dir.mkdirs()
                dir.listFiles()?.forEach { it.delete() }
                val cacheFile = File(dir, filename)
                cacheFile.outputStream().use { it.write(bytes) }
                host.runOnUiThread {
                    pendingSave = result
                    pendingSavePath = cacheFile.absolutePath
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                    intent.addCategory(Intent.CATEGORY_OPENABLE)
                    intent.type = "application/octet-stream"
                    intent.putExtra(Intent.EXTRA_TITLE, filename)
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    try {
                        host.startActivityForResult(intent, REQUEST_SAVE)
                    } catch (error: ActivityNotFoundException) {
                        pendingSave = null
                        pendingSavePath = null
                        cacheFile.delete()
                        result.error("unavailable", error.message ?: "Save picker is unavailable", null)
                    }
                }
            } catch (error: Exception) {
                host.runOnUiThread { result.error("save", error.message ?: "Could not stage file", null) }
            }
        }
    }

    private fun sanitizeExportFilename(raw: String): String {
        val trimmed = raw.trim().ifEmpty { "export.json" }
        return trimmed.replace(Regex("[\\\\/]+"), "-")
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_SAVE) {
            val reply = pendingSave
            val path = pendingSavePath
            pendingSave = null
            pendingSavePath = null
            val cache = path?.let { File(it) }
            if (reply == null) {
                cache?.delete()
                return true
            }
            if (resultCode != Activity.RESULT_OK || data?.data == null || cache == null || !cache.exists()) {
                cache?.delete()
                reply.success(mapOf("cancelled" to true))
                return true
            }
            val host = activity
            if (host == null) {
                cache.delete()
                reply.error("no_activity", "No activity to write the file", null)
                return true
            }
            executor.execute {
                try {
                    host.contentResolver.openOutputStream(data.data!!)?.use { output ->
                        cache.inputStream().use { it.copyTo(output) }
                    } ?: throw IllegalStateException("Could not open destination")
                    cache.delete()
                    host.runOnUiThread { reply.success(mapOf("cancelled" to false)) }
                } catch (error: Exception) {
                    cache.delete()
                    host.runOnUiThread { reply.error("save", error.message ?: "Save failed", null) }
                }
            }
            return true
        }
        if (requestCode != REQUEST && requestCode != REQUEST_FILES) return false
        val reply = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            reply.success(mapOf("cancelled" to true, "files" to emptyList<Map<String, Any?>>()))
            return true
        }
        val uris = mutableListOf<android.net.Uri>()
        val clip = data.clipData
        if (clip != null) {
            for (index in 0 until clip.itemCount) {
                clip.getItemAt(index).uri?.let(uris::add)
            }
        } else {
            data.data?.let(uris::add)
        }
        val host = activity
        if (host == null) {
            reply.success(mapOf("cancelled" to false, "files" to emptyList<Map<String, Any?>>()))
            return true
        }
        executor.execute {
            val dir = File(host.cacheDir, "pick-media")
            dir.mkdirs()
            dir.listFiles()?.forEach { it.delete() }
            val files = mutableListOf<Map<String, Any?>>()
            val resolver = host.contentResolver
            for (uri in uris) {
                try {
                    var displayName = "image.jpg"
                    resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val name = cursor.getString(0)
                            if (!name.isNullOrBlank()) displayName = name
                        }
                    }
                    var mime = resolver.getType(uri) ?: "image/jpeg"
                    val dest = File(dir, UUID.randomUUID().toString() + "-" + displayName.replace('/', '_'))
                    resolver.openInputStream(uri)?.use { input ->
                        dest.outputStream().use { input.copyTo(it) }
                    }
                    if (dest.exists() && dest.length() in 1..MAX_BYTES) {
                        files.add(
                            mapOf(
                                "path" to dest.absolutePath,
                                "name" to displayName,
                                "mimeType" to mime,
                                "size" to dest.length(),
                            ),
                        )
                    }
                } catch (_: Exception) {
                    // One failed file must not erase the rest.
                }
            }
            host.runOnUiThread {
                reply.success(mapOf("cancelled" to false, "files" to files))
            }
        }
        return true
    }

    private fun transcode(call: MethodCall, result: MethodChannel.Result) {
        var data = call.argument<String>("data").orEmpty()
        val comma = data.indexOf(',')
        if (data.startsWith("data:", ignoreCase = true) && comma >= 0) {
            data = data.substring(comma + 1)
        }
        val mime = call.argument<String>("mime")?.trim()?.lowercase().orEmpty()
        if (mime != "image/heic" && mime != "image/heif") {
            result.error("unsupported", "Unsupported image type: $mime", null)
            return
        }
        val qualityRaw = call.argument<Double>("quality") ?: 0.9
        val quality = ((if (qualityRaw.isNaN() || qualityRaw.isInfinite()) 0.9 else qualityRaw) * 100)
            .toInt()
            .coerceIn(0, 100)
        executor.execute {
            try {
                val bytes = Base64.decode(data, Base64.DEFAULT)
                if (bytes == null || bytes.isEmpty() || bytes.size > MAX_BYTES) {
                    activity?.runOnUiThread { result.error("invalid", "Image data is empty or too large", null) }
                    return@execute
                }
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bitmap == null) {
                    activity?.runOnUiThread { result.error("decode", "Could not decode HEIC/HEIF image", null) }
                    return@execute
                }
                val out = ByteArrayOutputStream()
                val ok = bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
                bitmap.recycle()
                if (!ok || out.size() == 0) {
                    activity?.runOnUiThread { result.error("encode", "Could not encode JPEG", null) }
                    return@execute
                }
                activity?.runOnUiThread {
                    result.success(mapOf("data" to Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP), "mime" to "image/jpeg"))
                }
            } catch (error: Exception) {
                activity?.runOnUiThread { result.error("transcode", error.message ?: "Transcode failed", null) }
            }
        }
    }

    companion object {
        private const val REQUEST = 7102
        private const val REQUEST_FILES = 7103
        private const val REQUEST_SAVE = 7104
        private const val MAX_BYTES = 32 * 1024 * 1024
    }
}

class VirtualAssetPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val assets = HashMap<String, ByteArrayOutputStream>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "openchamber/virtual_asset")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val assetId = call.argument<String>("assetId").orEmpty()
        when (call.method) {
            "create" -> {
                if (!assetId.matches(Regex("^[A-Za-z0-9_-]{8,80}$"))) {
                    result.error("invalid_id", "Invalid assetId", null)
                    return
                }
                assets[assetId] = ByteArrayOutputStream()
                result.success(mapOf("assetId" to assetId, "url" to "openchamber-asset://v/$assetId"))
            }
            "append" -> {
                val chunk = call.argument<String>("chunk").orEmpty()
                val stream = assets[assetId]
                if (stream == null) {
                    result.error("unknown", "Unknown asset", null)
                    return
                }
                stream.write(Base64.decode(chunk, Base64.DEFAULT))
                result.success(null)
            }
            "finish" -> result.success(null)
            "cancel" -> {
                assets.remove(assetId)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
