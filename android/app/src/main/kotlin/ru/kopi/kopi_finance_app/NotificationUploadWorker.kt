package ru.kopi.kopi_finance_app

import android.content.Context
import androidx.work.*
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit
import org.json.JSONObject

/** Uses only the current short-lived user access token, never a service or refresh key. */
open class NotificationUploadWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    companion object {
        fun enqueue(context: Context) {
            val request = OneTimeWorkRequestBuilder<NotificationUploadWorker>()
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build()
            // APPEND avoids losing a confirmation that arrives while the previous worker finishes.
            WorkManager.getInstance(context).enqueueUniqueWork("kopi-confirmed-notifications", ExistingWorkPolicy.APPEND_OR_REPLACE, request)
        }
    }
    override fun doWork(): Result {
        val inbox = NotificationInbox(applicationContext)
        val batch = inbox.upload() ?: return Result.success() // Re-enqueued when the app renews its session.
        for (row in batch.rows) {
            if (isStopped) return Result.retry()
            val id = row.getString("id")
            if (!inbox.stillConfirmed(batch.owner, id)) continue
            try {
                val status = post(batch, row.getJSONObject("payload"))
                if (status in 200..299) {
                    if (inbox.stillConfirmed(batch.owner, id)) inbox.ack(batch.owner, id)
                } else if (status == 401 || status == 403 || status in 400..499 && status != 429) {
                    return Result.success() // Retain the queue; retry after session renewal or user correction.
                } else return Result.retry()
            } catch (_: Exception) { return Result.retry() }
        }
        return Result.success()
    }

    protected open fun post(batch: UploadBatch, payload: JSONObject): Int {
        val connection = URL("${batch.url}/rest/v1/transactions?on_conflict=id").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            connection.doOutput = true
            connection.setRequestProperty("apikey", batch.key)
            connection.setRequestProperty("Authorization", "Bearer ${batch.token}")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Prefer", "resolution=ignore-duplicates,return=minimal")
            connection.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
            return connection.responseCode
        } finally { connection.disconnect() }
    }
}
