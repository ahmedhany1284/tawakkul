package com.tawakkal.tawakkal

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.util.Log
import androidx.annotation.NonNull

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            Log.d(TAG, "Method called: ${call.method}")
            if (call.method == "openApp") {
                try {
                    val intent: Intent? =
                        packageManager.getLaunchIntentForPackage(packageName)
                    if (intent != null) {
                        intent.addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED or
                                    Intent.FLAG_ACTIVITY_CLEAR_TOP
                        )
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.error("ERROR", "Could not create intent", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error opening app", e)
                    result.error("ERROR", "Failed to open app", e.message)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    companion object {
        private const val CHANNEL = "com.quran.khatma/channel"
        private const val TAG = "MainActivity"
    }
}