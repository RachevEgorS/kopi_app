package ru.kopi.kopi_finance_app

import android.app.*
import android.content.*
import android.net.Uri
import android.os.Build
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale

class NotificationPrompts(private val context: Context) {
    private val manager = context.getSystemService(NotificationManager::class.java)
    companion object { const val CHANNEL = "bank_confirmations" }
    private fun channel() {
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "Подтверждение операций", NotificationManager.IMPORTANCE_DEFAULT)
                .apply { description = "Предложения записать расходы и доходы из уведомлений банков" })
    }
    fun allowed(): Boolean {
        channel()
        return manager.areNotificationsEnabled() && (Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(CHANNEL).importance != NotificationManager.IMPORTANCE_NONE)
    }
    fun cancel(id: String) = manager.cancel(id, 1)
    fun cancelAll() = manager.cancelAll()
    private fun intent(row: JSONObject, action: String): Intent = Intent(context, NotificationActionReceiver::class.java)
        .setAction(action).setData(Uri.parse("kopi-action://$action/${row.getString("owner")}/${row.getString("id")}"))
        .putExtra("owner", row.getString("owner")).putExtra("id", row.getString("id"))
    private fun broadcast(row: JSONObject, action: String) = PendingIntent.getBroadcast(context, 0, intent(row, action), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun edit(row: JSONObject): PendingIntent = PendingIntent.getActivity(context, 0,
        Intent(context, MainActivity::class.java).setAction("kopi.edit")
            .setData(Uri.parse("kopi-edit://notification/${row.getString("owner")}/${row.getString("id")}"))
            .putExtra("notificationOwner", row.getString("owner")).putExtra("notificationId", row.getString("id"))
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun action(label: String, pending: PendingIntent): Notification.Action {
        val builder = Notification.Action.Builder(null, label, pending)
        if (Build.VERSION.SDK_INT >= 31) builder.setAuthenticationRequired(true)
        return builder.build()
    }
    fun show(row: JSONObject) {
        if (!allowed()) return
        val confirmed = row.optBoolean("confirmed")
        val operation = if (confirmed) row.getJSONObject("payload").let {
            BankOperation(it.getLong("amount_kopecks"), it.getString("kind") == "income", it.getString("title"), it.getString("category"))
        } else BankOperation.parse(row.getString("text")) ?: return
        val amount = if (confirmed) row.getJSONObject("payload").getLong("amount_kopecks") else operation.amount
        val formatted = NumberFormat.getNumberInstance(Locale.forLanguageTag("ru-RU")).apply { maximumFractionDigits = 2 }.format(amount / 100.0) + " ₽"
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_notification).setColor(0xffb77e99.toInt())
            .setContentTitle(if (confirmed) "Подтверждено: $formatted" else "Записать ${if (operation.income) "доход" else "расход"} $formatted?")
            .setContentText(if (confirmed) "Ожидает отправки. При необходимости открой Копи." else if (operation.income) "Уже учтено в плане? Проверь перед добавлением." else operation.category)
            .setVisibility(Notification.VISIBILITY_PRIVATE).setOnlyAlertOnce(true)
            .setPublicVersion((if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context))
                .setSmallIcon(R.drawable.ic_notification).setContentTitle("Копи · операция из банка").setContentText("Разблокируй телефон для просмотра").build())
            .setContentIntent(edit(row)).setAutoCancel(false)
        if (!confirmed) {
            builder.setDeleteIntent(broadcast(row, "dismiss"))
                .addAction(action("Добавить", broadcast(row, "add")))
                .addAction(action("Изменить", edit(row)))
                .addAction(action("Пропустить", broadcast(row, "skip")))
        }
        try { manager.notify(row.getString("id"), 1, builder.build()) } catch (_: SecurityException) { /* Permission revoked. */ }
    }
}

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "dismiss" && context.getSystemService(KeyguardManager::class.java).isDeviceLocked) return
        val owner = intent.getStringExtra("owner") ?: return
        val id = intent.getStringExtra("id") ?: return
        try { NotificationInbox(context).action(owner, id, intent.action ?: "") } catch (_: Exception) { /* Queue is unchanged on failure. */ }
    }
}
