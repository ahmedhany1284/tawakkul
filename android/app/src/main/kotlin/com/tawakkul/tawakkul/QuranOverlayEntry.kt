package com.tawakkal.tawakkal

import android.content.Intent
import android.app.Service
import android.os.IBinder
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class QuranOverlayService : Service() {
    private var flutterEngine: FlutterEngine? = null

    override fun onCreate() {
        super.onCreate()
        flutterEngine = FlutterEngine(this)
        flutterEngine?.dartExecutor?.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
    }

    override fun onBind(intent: Intent): IBinder? = null
}