package com.otyaplayer.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.*
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker that checks for OTYA Player updates every 24 hours.
 *
 * Scheduling: call [UpdateCheckWorker.schedule] once on app start.
 * The OS will run this worker periodically even when the app is in background.
 *
 * On update found:
 *   - Shows a high-priority notification with "Download Now" and "Later" actions.
 *   - Tapping "Download Now" opens the Worker /download URL in the browser.
 *
 * No Firebase / FCM required — pure WorkManager + local notifications.
 */
class UpdateCheckWorker(context: Context, params: WorkerParameters)
    : CoroutineWorker(context, params) {

    companion object {
        private const val WORK_NAME        = "otya_update_check"
        private const val CHANNEL_ID       = "com.otyaplayer.app.updates"
        private const val CHANNEL_NAME     = "Updates"
        private const val NOTIFICATION_ID  = 9001
        private const val VERSION_URL      = "https://petersmartlink.com/check-update"
        private const val DOWNLOAD_URL     = "https://petersmartlink.com/download/otya-player"
        private const val PREF_NAME        = "otya_update_prefs"
        private const val PREF_SKIPPED     = "skipped_version_code"

        /**
         * Schedule a periodic update check every 24 hours.
         * Safe to call multiple times — uses KEEP policy so existing work is not replaced.
         * Call this from MainActivity.onCreate or Flutter's main.dart via MethodChannel.
         */
        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = PeriodicWorkRequestBuilder<UpdateCheckWorker>(
                24, TimeUnit.HOURS,
                // Flex window: worker can run any time in the last 4 hours of the period
                4, TimeUnit.HOURS
            )
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.MINUTES)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
        }

        /** Run an immediate one-shot check (e.g. on app foreground). */
        fun runNow(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<UpdateCheckWorker>()
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueue(request)
        }
    }

    override suspend fun doWork(): Result {
        // Ensure the notification channel exists before we try to post.
        // Creating it here is safe and idempotent — Android ignores duplicate
        // channel creation. This guarantees the channel is ready even if the
        // worker runs before the app has been opened after a fresh install.
        createNotificationChannel()

        return try {
            val versionInfo = fetchVersionInfo() ?: return Result.success()
            val serverCode  = versionInfo.optInt("versionCode", 0)
            if (serverCode == 0) return Result.success()

            val installedCode = getInstalledVersionCode()
            val skippedCode   = getSkippedVersionCode()

            if (serverCode > installedCode && serverCode != skippedCode) {
                val version   = versionInfo.optString("version", "")
                val changelog = versionInfo.optString("changelog", "Bug fixes and improvements")
                showUpdateNotification(version, serverCode, changelog)
            }

            Result.success()
        } catch (e: Exception) {
            // Retry on network errors, succeed on other errors to avoid battery drain
            if (runAttemptCount < 3) Result.retry() else Result.success()
        }
    }

    private fun fetchVersionInfo(): JSONObject? {
        val url = URL(VERSION_URL)
        val conn = url.openConnection() as HttpURLConnection
        return try {
            conn.connectTimeout = 10_000
            conn.readTimeout    = 10_000
            conn.requestMethod  = "GET"
            if (conn.responseCode != 200) return null
            val body = conn.inputStream.bufferedReader().readText()
            JSONObject(body)
        } finally {
            conn.disconnect()
        }
    }

    @Suppress("DEPRECATION")
    private fun getInstalledVersionCode(): Int {
        return try {
            val pm = applicationContext.packageManager
            val pi = pm.getPackageInfo(applicationContext.packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pi.longVersionCode.toInt()
            } else {
                pi.versionCode
            }
        } catch (e: Exception) { 0 }
    }

    private fun getSkippedVersionCode(): Int {
        val prefs = applicationContext.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        return prefs.getInt(PREF_SKIPPED, 0)
    }

    private fun showUpdateNotification(version: String, versionCode: Int, changelog: String) {
        createNotificationChannel()

        // "Download Now" action — opens Worker /download in browser
        val downloadIntent = Intent(Intent.ACTION_VIEW, Uri.parse(DOWNLOAD_URL)).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val downloadPi = PendingIntent.getActivity(
            applicationContext, 0, downloadIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // "Later" action — dismisses notification (WorkManager re-checks in 24h)
        val dismissIntent = Intent(applicationContext, NotificationDismissReceiver::class.java).apply {
            putExtra("version_code", versionCode)
        }
        val dismissPi = PendingIntent.getBroadcast(
            applicationContext, 1, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val shortChangelog = if (changelog.length > 200) changelog.take(197) + "..." else changelog

        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("OTYA Player Update Available")
            .setContentText("Version $version is ready to download")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText(shortChangelog)
                .setBigContentTitle("OTYA Player $version is available"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_RECOMMENDATION)
            .setAutoCancel(true)
            .setContentIntent(downloadPi)
            .addAction(0, "Download Now", downloadPi)
            .addAction(0, "Later", dismissPi)
            .build()

        try {
            NotificationManagerCompat.from(applicationContext)
                .notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS permission not granted — silently skip
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "OTYA Player app update notifications"
                enableVibration(true)
            }
            val nm = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE)
                    as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }
}
