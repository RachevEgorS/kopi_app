package ru.kopi.kopi_finance_app

import android.app.Notification
import android.content.Context
import android.content.ComponentName
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class KopiNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try { NotificationInbox(this).capture(sbn) } catch (_: Exception) { /* Never log banking text. */ }
    }
}

class NotificationInbox(private val context: Context) {
    private val prefs = context.getSharedPreferences("kopi_notification_inbox", Context.MODE_PRIVATE)
    companion object { private val lock = Any(); private const val TTL = 48L * 60 * 60 * 1000 }
    private fun owner() = prefs.getString("owner", null)
    private fun verify(value: String?) { require(value != null && value == owner()) }
    fun account(value: String?) = synchronized(lock) {
        if (value != owner()) {
            NotificationPrompts(context).cancelAll()
            val edit = prefs.edit().clear()
            if (value != null) edit.putString("owner", value)
            check(edit.commit())
        }
    }
    fun session(value: String?, url: String, key: String, token: String, expires: Long) = synchronized(lock) {
        verify(value)
        require(url.startsWith("https://") && !url.contains('?') && !url.contains('#'))
        check(prefs.edit().putString("url", url.trimEnd('/')).putString("key", key)
            .putString("token", token).putLong("expires", expires).commit())
        if (rows().any { it.optBoolean("confirmed") }) NotificationUploadWorker.enqueue(context)
    }
    private fun allowed(): Boolean {
        val component = ComponentName(context, KopiNotificationListener::class.java)
        return (Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners") ?: "")
            .split(':').any { ComponentName.unflattenFromString(it) == component }
    }
    fun status(value: String?): Map<String, Any> = synchronized(lock) {
        verify(value)
        mapOf("permission" to allowed(), "enabled" to prefs.getBoolean("enabled", false),
            "automatic" to prefs.getBoolean("automatic", false),
            "prompts" to prefs.getBoolean("prompts", true),
            "canPost" to NotificationPrompts(context).allowed(),
            "revision" to prefs.getLong("revision", 0),
            "packages" to (prefs.getStringSet("packages", emptySet()) ?: emptySet()).toList())
    }
    fun configure(value: String?, enabled: Boolean, automatic: Boolean, packages: List<String>, prompts: Boolean = true) = synchronized(lock) {
        verify(value)
        val kept = rows().filter { enabled && packages.contains(it.getString("package")) }
        check(prefs.edit().putBoolean("enabled", enabled).putBoolean("automatic", automatic)
            .putBoolean("prompts", prompts).putStringSet("packages", packages.toSet())
            .putString("queue", JSONArray(kept).toString()).commit())
        NotificationPrompts(context).cancelAll()
        if (enabled && prompts && !automatic) kept.filter { !it.optBoolean("dismissed") }.forEach { NotificationPrompts(context).show(it) }
    }
    private fun rows(): List<JSONObject> {
        val data = JSONArray(prefs.getString("queue", "[]"))
        val now = System.currentTimeMillis()
        return (0 until data.length()).map { data.getJSONObject(it) }.filter {
            val keep = it.optBoolean("confirmed") || now - it.getLong("receivedAt") in 0..TTL
            if (!keep) NotificationPrompts(context).cancel(it.getString("id"))
            keep
        }
    }
    private fun write(rows: List<JSONObject>) { check(prefs.edit().putString("queue", JSONArray(rows).toString()).commit()) }
    fun capture(sbn: StatusBarNotification) = synchronized(lock) {
        if (owner() == null || !prefs.getBoolean("enabled", false) || !allowed()) return@synchronized
        if (!(prefs.getStringSet("packages", emptySet()) ?: emptySet()).contains(sbn.packageName)) return@synchronized
        val n = sbn.notification
        if (n.flags and (Notification.FLAG_GROUP_SUMMARY or Notification.FLAG_ONGOING_EVENT) != 0) return@synchronized
        val title = n.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val body = (n.extras.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: n.extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        val text = "$title\n$body".take(2000)
        if (text.isBlank() || Regex("(?i)(код|никому не|одноразов|\\botp\\b|парол)").containsMatchIn(text)) return@synchronized
        val now = System.currentTimeMillis()
        val time = n.`when`.takeIf { it > 0 && now - it in 0..TTL } ?: sbn.postTime
        val key = "${sbn.packageName}|${sbn.key}|$time"
        val id = MessageDigest.getInstance("SHA-256").digest(key.toByteArray()).joinToString("") { "%02x".format(it) }
        if ((prefs.getStringSet("seen", emptySet()) ?: emptySet()).contains(id)) return@synchronized
        val current = rows()
        // Once shown, the financial proposal is immutable: an old action cannot confirm changed text.
        if (current.any { it.getString("id") == id }) return@synchronized
        val row = JSONObject().put("id", id).put("owner", owner()).put("package", sbn.packageName)
            .put("text", text).put("timestamp", time).put("receivedAt", now)
        val confirmed = current.filter { it.optBoolean("confirmed") }
        val waiting = current.filter { !it.optBoolean("confirmed") }
        waiting.dropLast(199).forEach { NotificationPrompts(context).cancel(it.getString("id")) }
        write(confirmed + waiting.takeLast(199) + row)
        if (prefs.getBoolean("prompts", true) && !prefs.getBoolean("automatic", false)) NotificationPrompts(context).show(row)
    }
    fun pending(value: String?): List<Map<String, Any>> = synchronized(lock) {
        verify(value)
        val current = if (prefs.getBoolean("enabled", false)) rows().filter { allowed() || it.optBoolean("confirmed") } else emptyList()
        write(current)
        current.map { row -> row.keys().asSequence().associateWith {
            val item = row.get(it)
            if (item is JSONObject) item.keys().asSequence().associateWith { field -> item.get(field) } else item
        } }
    }
    fun find(value: String?, id: String): JSONObject? = synchronized(lock) {
        if (value == null || value != owner()) return@synchronized null
        rows().firstOrNull { it.getString("id") == id }
    }
    fun action(value: String?, id: String, action: String): Boolean = synchronized(lock) {
        val row = find(value, id) ?: return@synchronized false
        if (!prefs.getBoolean("enabled", false)) return@synchronized false
        if (row.optBoolean("confirmed")) return@synchronized action == "add"
        when (action) {
            "skip" -> { ack(value, id); return@synchronized true }
            "dismiss" -> row.put("dismissed", true)
            "edit" -> row.put("editing", true).put("dismissed", true)
            "add" -> {
                if (row.optBoolean("editing")) return@synchronized false
                val operation = BankOperation.parse(row.getString("text")) ?: return@synchronized false
                row.put("confirmed", true).put("payload", payload(row, operation)).put("text", "")
            }
            else -> return@synchronized false
        }
        write(rows().map { if (it.getString("id") == id) row else it })
        if (action == "add") {
            NotificationPrompts(context).show(row)
            NotificationUploadWorker.enqueue(context)
        }
        if (action == "edit") NotificationPrompts(context).cancel(id)
        true
    }
    fun confirmEdit(value: String?, id: String, data: Map<String, Any?>) = synchronized(lock) {
        verify(value)
        val row = find(value, id) ?: error("Сообщение уже обработано")
        require(!row.optBoolean("confirmed"))
        val amount = (data["amount"] as Number).toLong()
        val title = data["title"] as String
        val category = data["category"] as String
        val date = data["date"] as String
        require(amount in 1..99999999999L && title.length in 1..100 && category.length in 1..60)
        require(Regex("\\d{4}-\\d{2}-\\d{2}").matches(date))
        val operation = BankOperation(amount, data["income"] == true, title, category)
        row.put("confirmed", true).put("payload", payload(row, operation).put("occurred_on", date)).put("text", "")
        write(rows().map { if (it.getString("id") == id) row else it })
        NotificationPrompts(context).show(row)
        NotificationUploadWorker.enqueue(context)
    }
    private fun payload(row: JSONObject, operation: BankOperation): JSONObject = JSONObject()
        .put("id", BankOperation.transactionId(row.getString("owner"), row.getString("id")))
        .put("user_id", row.getString("owner")).put("kind", if (operation.income) "income" else "expense")
        .put("amount_kopecks", operation.amount).put("title", operation.title).put("category", operation.category)
        .put("occurred_on", SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(row.getLong("timestamp"))))
        .put("source", "notification").put("source_ref", row.getString("id"))
    fun upload(): UploadBatch? = synchronized(lock) {
        val owner = owner() ?: return@synchronized null
        if (prefs.getLong("expires", 0) <= System.currentTimeMillis() / 1000 + 30) return@synchronized null
        val token = prefs.getString("token", null) ?: return@synchronized null
        UploadBatch(owner, prefs.getString("url", "")!!, prefs.getString("key", "")!!, token,
            rows().filter { it.optBoolean("confirmed") })
    }
    fun stillConfirmed(value: String, id: String) = synchronized(lock) { find(value, id)?.optBoolean("confirmed") == true }
    fun ack(value: String?, id: String) = synchronized(lock) {
        verify(value)
        val kept = rows().filter { it.getString("id") != id }
        val seen = (prefs.getStringSet("seen", emptySet()) ?: emptySet()).toMutableSet()
        if (seen.size >= 2000) seen.clear()
        seen.add(id)
        check(prefs.edit().putString("queue", JSONArray(kept).toString()).putStringSet("seen", seen)
            .putLong("revision", prefs.getLong("revision", 0) + 1).commit())
        NotificationPrompts(context).cancel(id)
    }
}

data class UploadBatch(val owner: String, val url: String, val key: String, val token: String, val rows: List<JSONObject>)
