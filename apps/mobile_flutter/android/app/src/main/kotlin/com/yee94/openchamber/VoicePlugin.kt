package com.yee94.openchamber

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.util.Base64
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/// Official dictation PCM (`audio/pcm;rate=16000;bits=16`) + TTS playback.
class VoicePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware {
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private lateinit var tts: MethodChannel
    private var activity: Activity? = null
    private var sink: EventChannel.EventSink? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val recording = AtomicBoolean(false)
    private var recorder: AudioRecord? = null
    private var player: MediaPlayer? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods = MethodChannel(binding.binaryMessenger, "openchamber/dictation")
        events = EventChannel(binding.binaryMessenger, "openchamber/dictation_pcm")
        tts = MethodChannel(binding.binaryMessenger, "openchamber/tts")
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
        tts.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> playTts((call.arguments as? Map<*, *>)?.get("audio") as? String, result)
                "stop" -> {
                    stopTts()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        tts.setMethodCallHandler(null)
        stopCapture()
        stopTts()
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

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                startCapture(result)
            }
            "stop" -> {
                stopCapture()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startCapture(result: MethodChannel.Result) {
        val host = activity
        if (host == null) {
            result.error("unavailable", "No activity", null)
            return
        }
        if (ContextCompat.checkSelfPermission(host, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(host, arrayOf(Manifest.permission.RECORD_AUDIO), 71)
            result.error("permission", "Microphone permission is required", null)
            return
        }
        if (recording.getAndSet(true)) {
            result.success(null)
            return
        }
        executor.execute {
            val min = AudioRecord.getMinBufferSize(16_000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
            val bufferSize = maxOf(min, 16_000 * 2)
            val record = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                16_000,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize,
            )
            recorder = record
            record.startRecording()
            val chunk = ByteArray(16_000 * 2)
            while (recording.get()) {
                val read = record.read(chunk, 0, chunk.size)
                if (read > 0) {
                    val encoded = Base64.encodeToString(chunk.copyOf(read), Base64.NO_WRAP)
                    host.runOnUiThread {
                        sink?.success(mapOf("audio" to encoded))
                    }
                }
            }
        }
        result.success(null)
    }

    private fun stopCapture() {
        recording.set(false)
        try {
            recorder?.stop()
        } catch (_: Exception) {
        }
        recorder?.release()
        recorder = null
    }

    private fun playTts(audio: String?, result: MethodChannel.Result) {
        val host = activity
        if (host == null || audio.isNullOrEmpty()) {
            result.error("unavailable", "No audio", null)
            return
        }
        stopTts()
        try {
            val bytes = Base64.decode(audio, Base64.DEFAULT)
            val file = File.createTempFile("oc-tts", ".bin", host.cacheDir)
            file.writeBytes(bytes)
            player = MediaPlayer().apply {
                setDataSource(file.absolutePath)
                setOnCompletionListener {
                    stopTts()
                    file.delete()
                }
                prepare()
                start()
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("tts", error.message, null)
        }
    }

    private fun stopTts() {
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        player?.release()
        player = null
    }
}
