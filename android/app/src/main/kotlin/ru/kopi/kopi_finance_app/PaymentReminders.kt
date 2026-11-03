package ru.kopi.kopi_finance_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.BroadcastReceiver
import java.time.Duration
import java.time.ZoneId
import android.os.Build
import androidx.work.*
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalTime
import java.time.YearMonth
import java.util.concurrent.TimeUnit

class PaymentReminders(private val context: Context) {
    private val prefs = context.getSharedPreferences("kopi_payment_reminders", Context.MODE_PRIVATE)
    private val manager = context.getSystemService(NotificationManager::class.java)
    companion object { private val lock = Any(); const val CHANNEL = "planned_payments" }
    fun reset(owner: String?) = synchronized(lock) {
        if(prefs.getString("owner",null)!=owner) {
            clearNotifications(); prefs.edit().clear().putString("owner",owner).commit()
            WorkManager.getInstance(context).cancelUniqueWork("kopi-payment-reminders")
            cancelAlarm()
        }
    }
    private fun clearNotifications() { manager.activeNotifications.filter { it.tag?.startsWith("payment:")==true }.forEach { manager.cancel(it.tag,it.id) } }
    fun configure(owner: String, enabled: Boolean, payments: List<Map<String,Any?>>, paid: List<String>) = synchronized(lock) {
        require(owner==prefs.getString("owner",null))
        val data=JSONArray(); payments.forEach { data.put(JSONObject(it)) }
        check(prefs.edit().putBoolean("enabled",enabled).putString("payments",data.toString()).putStringSet("paid",paid.toSet()).commit())
        clearNotifications()
        if(enabled && payments.isNotEmpty()) {
            val task=PeriodicWorkRequestBuilder<PaymentReminderWorker>(15,TimeUnit.MINUTES).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork("kopi-payment-reminders",ExistingPeriodicWorkPolicy.KEEP,task)
            tick()
        } else { WorkManager.getInstance(context).cancelUniqueWork("kopi-payment-reminders"); cancelAlarm() }
    }
    fun markPaid(owner: String, key: String) = synchronized(lock) {
        if(owner!=prefs.getString("owner",null)) return@synchronized
        val paid=(prefs.getStringSet("paid",emptySet()) ?: emptySet()).toMutableSet(); paid.add(key)
        prefs.edit().putStringSet("paid",paid).commit(); manager.cancel("payment:$key",2); scheduleNextAlarm()
    }
    private fun alarmIntent() = PendingIntent.getBroadcast(context,7201,Intent(context,PaymentAlarmReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun cancelAlarm() { context.getSystemService(AlarmManager::class.java).cancel(alarmIntent()) }
    fun scheduleNextAlarm() = synchronized(lock) {
        cancelAlarm()
        if(!prefs.getBoolean("enabled",false) || prefs.getString("owner",null)==null || !manager.areNotificationsEnabled()) return@synchronized
        if(Build.VERSION.SDK_INT>=26 && manager.getNotificationChannel(CHANNEL)?.importance==NotificationManager.IMPORTANCE_NONE) return@synchronized
        val now=java.time.LocalDateTime.now()
        val paid=prefs.getStringSet("paid",emptySet()) ?: emptySet()
        val sent=prefs.getStringSet("sent",emptySet()) ?: emptySet()
        var next: java.time.LocalDateTime?=null
        for(plan in plans()) {
            val lead=plan.getInt("reminderDays"); if(lead<0) continue
            val start=LocalDate.parse(plan.getString("start"))
            val dates=if(plan.getBoolean("monthly")) (-1..13).map { YearMonth.from(now).plusMonths(it.toLong()).let { m -> m.atDay(minOf(start.dayOfMonth,m.lengthOfMonth())) } }.filter { !it.isBefore(start) } else listOf(start)
            for(due in dates) {
                val key="${plan.getString("id")}@$due"; if(key in paid || now.toLocalDate().isAfter(due.plusDays(7))) continue
                val begin=due.minusDays(lead.toLong()).atStartOfDay().plusMinutes(plan.optInt("reminderMinute",540).toLong())
                val repeat=plan.optInt("repeatMinutes",0)
                val target=if(begin.isAfter(now)) begin else if(repeat>0) {
                    val slot=Duration.between(begin,now).toMinutes()/repeat
                    if("$key#$slot" in sent) begin.plusMinutes((slot+1)*repeat) else now.plusSeconds(1)
                } else if(key !in sent) now.plusSeconds(1) else continue
                if(target.toLocalDate().isAfter(due.plusDays(7))) continue
                if(next==null || target.isBefore(next)) next=target
            }
        }
        next?.let {
            val alarm=context.getSystemService(AlarmManager::class.java)
            val millis=it.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
            try {
                if(Build.VERSION.SDK_INT<31 || alarm.canScheduleExactAlarms()) alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,millis,alarmIntent())
                else alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,millis,alarmIntent())
            } catch (_: SecurityException) { alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,millis,alarmIntent()) }
        }
    }
    private fun plans(): List<JSONObject> {
        val data=JSONArray(prefs.getString("payments","[]"))
        return (0 until data.length()).map { data.getJSONObject(it) }
    }
    fun hasCandidate(amount: Long): Boolean = synchronized(lock) { plans().any { it.getLong("amount")==amount } }
    fun tick(today: LocalDate=LocalDate.now(), hour: Int=LocalTime.now().hour, minute: Int=LocalTime.now().minute) = synchronized(lock) {
        if(!prefs.getBoolean("enabled",false) || prefs.getString("owner",null)==null || !manager.areNotificationsEnabled()) return@synchronized
        if(Build.VERSION.SDK_INT>=26) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL,"Платежи и подписки",NotificationManager.IMPORTANCE_DEFAULT))
            if(manager.getNotificationChannel(CHANNEL).importance==NotificationManager.IMPORTANCE_NONE) return@synchronized
        }
        val paid=prefs.getStringSet("paid",emptySet()) ?: emptySet()
        val sent=(prefs.getStringSet("sent",emptySet()) ?: emptySet()).toMutableSet()
        for(plan in plans()) {
            val start=LocalDate.parse(plan.getString("start")); val lead=plan.getInt("reminderDays")
            if(lead<0) continue
            val dates=if(plan.getBoolean("monthly")) (-1..13).map { offset ->
                val month=YearMonth.from(today).plusMonths(offset.toLong()); month.atDay(minOf(start.dayOfMonth,month.lengthOfMonth()))
            }.filter { !it.isBefore(start) } else listOf(start)
            for(due in dates) {
                val key="${plan.getString("id")}@$due"
                if(key in paid || today.isBefore(due.minusDays(lead.toLong())) || today.isAfter(due.plusDays(7))) continue
                val begin=due.minusDays(lead.toLong()).atStartOfDay().plusMinutes(plan.optInt("reminderMinute",540).toLong())
                val elapsed=Duration.between(begin,today.atTime(hour,minute)).toMinutes()
                if(elapsed<0) continue
                val repeat=plan.optInt("repeatMinutes",0)
                val stamp=if(repeat>0) "$key#${elapsed/repeat}" else key
                if(stamp in sent) continue
                val pending=PendingIntent.getActivity(context,0,Intent(context,MainActivity::class.java).setAction("kopi.payment").addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val builder=if(Build.VERSION.SDK_INT>=26) Notification.Builder(context,CHANNEL) else Notification.Builder(context)
                builder.setSmallIcon(R.drawable.ic_notification).setContentTitle(plan.getString("title"))
                    .setContentText("${plan.getLong("amount")/100.0} ₽ · $due. Проверь платёж в календаре.")
                    .setVisibility(Notification.VISIBILITY_PRIVATE).setContentIntent(pending).setAutoCancel(true)
                try { manager.notify("payment:$key",2,builder.build()); sent.add(stamp) } catch (_: SecurityException) { }
            }
        }
        // Keep occurrence keys for two years; old schedules cannot produce fresh duplicates.
        val kept=sent.filter { runCatching { !LocalDate.parse(it.substringAfterLast('@').substringBefore('#')).isBefore(today.minusYears(2)) }.getOrDefault(false) }.toSet()
        prefs.edit().putStringSet("sent",kept).commit()
        scheduleNextAlarm()
    }
}
class PaymentReminderWorker(context: Context, params: WorkerParameters): Worker(context,params) {
    override fun doWork(): Result = try { PaymentReminders(applicationContext).tick(); Result.success() } catch (_:Exception) { Result.retry() }
}

class PaymentAlarmReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { PaymentReminders(context).tick(); PaymentReminders(context).scheduleNextAlarm() } catch (_: Exception) { }
    }
}
