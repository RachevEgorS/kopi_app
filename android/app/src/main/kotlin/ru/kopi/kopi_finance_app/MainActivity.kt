package ru.kopi.kopi_finance_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "kopi/notifications").setMethodCallHandler { call, result ->
            try {
                val repo = NotificationInbox(this)
                when (call.method) {
                    "account" -> { repo.account(call.argument<String>("owner")); result.success(null) }
                    "status" -> result.success(repo.status(call.argument<String>("owner")))
                    "configure" -> {
                        repo.configure(call.argument<String>("owner"), call.argument<Boolean>("enabled") == true,
                            call.argument<Boolean>("automatic") == true, call.argument<List<String>>("packages") ?: emptyList())
                        result.success(null)
                    }
                    "settings" -> { startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(null) }
                    "pending" -> result.success(repo.pending(call.argument<String>("owner")))
                    "ack" -> { repo.ack(call.argument<String>("owner"), call.argument<String>("id") ?: ""); result.success(null) }
                    "apps" -> {
                        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                        val apps = packageManager.queryIntentActivities(intent, 0)
                            .filter { it.activityInfo.packageName != packageName }
                            .distinctBy { it.activityInfo.packageName }
                            .map { mapOf("package" to it.activityInfo.packageName, "name" to it.loadLabel(packageManager).toString()) }
                            .sortedBy { it["name"] }
                        result.success(apps)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("notification_error", "Не удалось обновить чтение уведомлений", null) }
        }
    }
}
