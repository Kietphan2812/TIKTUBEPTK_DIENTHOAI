package com.example.flutter_app_ptk

import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flutter_app_ptk/app_control"
    private var ringtone: Ringtone? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "bringToFront" -> {
                    try {
                        val intent = Intent(applicationContext, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "startRingtone" -> {
                    try {
                        if (ringtone == null) {
                            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                            ringtone = RingtoneManager.getRingtone(applicationContext, uri)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                ringtone?.isLooping = true
                            }
                        }
                        if (ringtone?.isPlaying != true) {
                            ringtone?.play()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopRingtone" -> {
                    try {
                        if (ringtone?.isPlaying == true) {
                            ringtone?.stop()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openUrl" -> {
                    try {
                        val url = call.argument<String>("url")
                        if (url != null) {
                            val browserIntent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(browserIntent)
                            result.success(true)
                        } else {
                            result.error("INVALID_URL", "URL is null", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "getVideoFrame" -> {
                    try {
                        val path = call.argument<String>("path")
                        val uriStr = call.argument<String>("uri")
                        val urlStr = call.argument<String>("url")
                        val timeMs = call.argument<Int>("timeMs") ?: 0
                        val retriever = MediaMetadataRetriever()
                        if (!path.isNullOrEmpty() && File(path).exists()) {
                            retriever.setDataSource(path)
                        } else if (!uriStr.isNullOrEmpty()) {
                            retriever.setDataSource(applicationContext, android.net.Uri.parse(uriStr))
                        } else if (!urlStr.isNullOrEmpty()) {
                            retriever.setDataSource(urlStr, HashMap<String, String>())
                        } else {
                            result.error("INVALID_ARGS", "Path, URI or URL must be provided", null)
                            return@setMethodCallHandler
                        }
                        val timeUs = timeMs.toLong() * 1000L
                        val bitmap: Bitmap? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                            retriever.getScaledFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST, 1280, 720)
                                ?: retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST)
                        } else {
                            retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST)
                        }
                        retriever.release()
                        if (bitmap != null) {
                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
                            val byteArray = stream.toByteArray()
                            result.success(byteArray)
                        } else {
                            result.error("FRAME_NULL", "Could not extract frame", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            if (ringtone?.isPlaying == true) {
                ringtone?.stop()
            }
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
