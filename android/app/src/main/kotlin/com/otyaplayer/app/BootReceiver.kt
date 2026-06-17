package com.otyaplayer.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives BOOT_COMPLETED so the app can restart its background
 * media-playback service after the device reboots.
 *
 * Flutter's audio_service plugin handles the actual service restart;
 * this receiver simply ensures the OS wakes the app on boot.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            // audio_service will re-attach when MainActivity is next opened.
            // No explicit service start needed — Flutter engine is not running yet.
        }
    }
}
