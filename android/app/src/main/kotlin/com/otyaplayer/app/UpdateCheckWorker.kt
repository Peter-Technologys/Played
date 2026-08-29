package com.otyaplayer.app

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkManager
import androidx.work.WorkerParameters

/**
 * Compatibility shim for installs that may still have OTYA's old native
 * WorkManager update job registered.
 *
 * OTYA v1 has one update owner: Flutter UpdateService. It respects the
 * SELF_UPDATE build flag and runs after the first frame, so local playback is
 * never coupled to an update network request.
 *
 * MainActivity and older boot receivers may still call [schedule] during the
 * migration. Instead of creating another updater, that call now removes any
 * legacy periodic work. Once the native callers are removed, this shim can be
 * deleted completely.
 */
class UpdateCheckWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    companion object {
        private const val WORK_NAME = "otya_update_check"

        fun schedule(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }

        fun runNow(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }

    override suspend fun doWork(): Result = Result.success()
}
