package com.otyaplayer.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives the "Later" action from the update notification.
 * Saves the dismissed versionCode so WorkManager won't re-notify
 * for the same version until the next app launch clears it.
 */
class NotificationDismissReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val versionCode = intent.getIntExtra("version_code", 0)
        if (versionCode > 0) {
            context.getSharedPreferences("otya_update_prefs", Context.MODE_PRIVATE)
                .edit()
                .putInt("skipped_version_code", versionCode)
                .apply()
        }
    }
}
