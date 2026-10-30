package ru.kopi.kopi_finance_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.os.Build
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 8701) {
            permissionResult?.success(NotificationPrompts(this).allowed())
            permissionResult = null
        }
    }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "kopi/notifications").setMethodCallHandler { call, result ->
            try {
                val repo = NotificationInbox(this)
                when (call.method) {
                    "account" -> { repo.account(call.argument<String>("owner")); result.success(null) }
                    "session" -> {
                        repo.session(call.argument<String>("owner"), call.argument<String>("url")!!,
                            call.argument<String>("key")!!, call.argument<String>("token")!!, (call.argument<Number>("expires")!!).toLong())
                        result.success(null)
                    }
                    "requestPost" -> {
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission("android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED) {
                            if (permissionResult != null) { result.success(false) } else {
                                permissionResult = result
                                requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 8701)
                            }
                        } else result.success(NotificationPrompts(this).allowed())
                    }
                    "postSettings" -> {
                        startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                        result.success(null)
                    }
                    "takeAction" -> {
                        val owner = intent.getStringExtra("notificationOwner")
                        val id = intent.getStringExtra("notificationId")
                        intent.removeExtra("notificationOwner"); intent.removeExtra("notificationId")
                        if (owner == call.argument<String>("owner") && id != null && repo.action(owner, id, "edit")) {
                            val row = repo.find(owner, id)
                            result.success(row?.keys()?.asSequence()?.associateWith { row.get(it) })
                        } else result.success(null)
                    }
                    "edit" -> result.success(repo.action(call.argument<String>("owner"), call.argument<String>("id")!!, "edit"))
                    "confirm" -> result.success(repo.action(call.argument<String>("owner"), call.argument<String>("id")!!, "add"))
                    "confirmEdit" -> {
                        repo.confirmEdit(call.argument<String>("owner"), call.argument<String>("id")!!, call.argument<Map<String, Any?>>("entry")!!)
                        result.success(null)
                    }
                    "status" -> result.success(repo.status(call.argument<String>("owner")))
                    "configure" -> {
                        repo.configure(call.argument<String>("owner"), call.argument<Boolean>("enabled") == true,
                            call.argument<Boolean>("automatic") == true, call.argument<List<String>>("packages") ?: emptyList(), call.argument<Boolean>("prompts") != false)
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
