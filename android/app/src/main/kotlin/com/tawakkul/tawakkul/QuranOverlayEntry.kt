package com.tawakkal.tawakkal

import io.flutter.app.FlutterApplication
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

class QuranOverlayEntry : FlutterApplication() {
    companion object {
        const val CHANNEL_ID = "quran_overlay_channel"
        const val CHANNEL_NAME = "Quran Overlay Service"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Quran Overlay Channel
            val quranOverlayChannel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows Quran verses periodically"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }

            // Get notification manager and create channels
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(quranOverlayChannel)
        }
    }
}