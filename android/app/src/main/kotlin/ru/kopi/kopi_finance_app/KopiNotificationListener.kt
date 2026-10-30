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

/** Never contacts a network, reads old notifications or records unselected apps. */
class KopiNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try { NotificationInbox(this).capture(sbn) } catch (_: Exception) { /* No banking text in logs. */ }
    }
}

class NotificationInbox(private val context: Context) {
    private val prefs = context.getSharedPreferences("kopi_notification_inbox", Context.MODE_PRIVATE)
    companion object { private val lock = Any(); private const val TTL = 48L * 60 * 60 * 1000 }
    private fun owner() = prefs.getString("owner", null)
    private fun verify(value: String?) { require(value != null && value == owner()) }
    fun account(value: String?) = synchronized(lock) {
        if (value != owner()) {
            // No notification may migrate from one account to another.
            val edit = prefs.edit().clear()
            if (value != null) edit.putString("owner", value)
            check(edit.commit())
        }
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
            "packages" to (prefs.getStringSet("packages", emptySet()) ?: emptySet()).toList())
    }
    fun configure(value: String?, enabled: Boolean, automatic: Boolean, packages: List<String>) = synchronized(lock) {
        verify(value)
        val edit = prefs.edit().putBoolean("enabled", enabled).putBoolean("automatic", automatic)
            .putStringSet("packages", packages.toSet())
        // Disabling discards raw text immediately. Removing an app drops its pending rows.
        val kept = JSONArray()
        if (enabled) for (row in rows()) if (packages.contains(row.getString("package"))) kept.put(row)
        check(edit.putString("queue", kept.toString()).commit())
    }
    private fun rows(): List<JSONObject> {
        val data = JSONArray(prefs.getString("queue", "[]"))
        val now = System.currentTimeMillis()
        return (0 until data.length()).map { data.getJSONObject(it) }
            .filter { now - it.getLong("receivedAt") in 0..TTL }
    }
    fun capture(sbn: StatusBarNotification) = synchronized(lock) {
        if (owner() == null || !prefs.getBoolean("enabled", false) || !allowed()) return@synchronized
        if (!(prefs.getStringSet("packages", emptySet()) ?: emptySet()).contains(sbn.packageName)) return@synchronized
        val n = sbn.notification
        if (n.flags and (Notification.FLAG_GROUP_SUMMARY or Notification.FLAG_ONGOING_EVENT) != 0) return@synchronized
        val title = n.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val body = (n.extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: n.extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        val text = "$title\n$body".take(2000)
        if (text.isBlank() || Regex("(?i)(код|никому не|одноразов|\\botp\\b|парол)").containsMatchIn(text)) return@synchronized
        val now = System.currentTimeMillis()
        val time = n.`when`.takeIf { it > 0 && now - it in 0..TTL } ?: sbn.postTime
        val key = "${sbn.packageName}|${sbn.key}|$time"
        val id = MessageDigest.getInstance("SHA-256").digest(key.toByteArray()).joinToString("") { "%02x".format(it) }
        val seen = prefs.getStringSet("seen", emptySet()) ?: emptySet()
        if (seen.contains(id)) return@synchronized
        val row = JSONObject().put("id", id).put("owner", owner()).put("package", sbn.packageName)
            .put("text", text).put("timestamp", time).put("receivedAt", now)
        val pending = rows().filter { it.getString("id") != id }.takeLast(199)
        val array = JSONArray(); pending.forEach { array.put(it) }; array.put(row)
        prefs.edit().putString("queue", array.toString()).commit()
    }
    fun pending(value: String?): List<Map<String, Any>> = synchronized(lock) {
        verify(value)
        val current = if (allowed() && prefs.getBoolean("enabled", false)) rows() else emptyList()
        val array = JSONArray(); current.forEach { array.put(it) }
        prefs.edit().putString("queue", array.toString()).commit()
        current.map { row -> row.keys().asSequence().associateWith { row.get(it) } }
    }
    fun ack(value: String?, id: String) = synchronized(lock) {
        verify(value)
        val array = JSONArray(); rows().filter { it.getString("id") != id }.forEach { array.put(it) }
        val seen = (prefs.getStringSet("seen", emptySet()) ?: emptySet()).toMutableSet()
        if (seen.size >= 2000) seen.clear()
        seen.add(id)
        check(prefs.edit().putString("queue", array.toString()).putStringSet("seen", seen).commit())
    }
}
