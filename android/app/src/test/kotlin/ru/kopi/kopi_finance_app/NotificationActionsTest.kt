package ru.kopi.kopi_finance_app

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.provider.Settings
import androidx.work.testing.WorkManagerTestInitHelper
import androidx.work.testing.TestListenableWorkerBuilder
import androidx.work.WorkerParameters
import androidx.work.ListenableWorker.Result
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class NotificationActionsTest {
    private lateinit var context: Context
    private lateinit var inbox: NotificationInbox
    private val owner = "11111111-1111-4111-8111-111111111111"
    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences("kopi_notification_inbox", Context.MODE_PRIVATE).edit().clear().commit()
        WorkManagerTestInitHelper.initializeTestWorkManager(context)
        inbox = NotificationInbox(context)
        inbox.account(owner)
        Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners", "${context.packageName}/${KopiNotificationListener::class.java.name}")
        inbox.configure(owner, true, false, listOf("bank.test"))
        val row = JSONObject().put("id", "event-1").put("owner", owner).put("package", "bank.test")
            .put("text", "Покупка 850 ₽ Пятёрочка. Баланс 12000 ₽").put("timestamp", System.currentTimeMillis()).put("receivedAt", System.currentTimeMillis())
        context.getSharedPreferences("kopi_notification_inbox", Context.MODE_PRIVATE).edit().putString("queue", JSONArray().put(row).toString()).commit()
    }
    @Test fun confirmIsDurableAndIdempotent() {
        assertTrue(inbox.action(owner, "event-1", "add"))
        assertTrue(inbox.action(owner, "event-1", "add"))
        val restored = NotificationInbox(context).pending(owner)
        assertEquals(1, restored.size)
        assertEquals(true, restored.single()["confirmed"])
        assertEquals("", restored.single()["text"])
        val payload = restored.single()["payload"] as Map<*, *>
        assertEquals(85000L, (payload["amount_kopecks"] as Number).toLong())
        assertFalse(payload.containsKey("text"))
        assertFalse(payload.containsKey("token"))
        assertEquals(BankOperation.transactionId(owner, "event-1"), payload["id"])
        assertNull(inbox.upload()) // No session: confirmation is retained, never anonymously uploaded.
    }
    @Test fun swipingAndEditingDoNotSave() {
        assertTrue(inbox.action(owner, "event-1", "dismiss"))
        assertFalse(inbox.find(owner, "event-1")!!.optBoolean("confirmed"))
        assertTrue(inbox.action(owner, "event-1", "edit"))
        assertFalse(inbox.action(owner, "event-1", "add")) // stale Add button cannot overwrite edits.
        inbox.confirmEdit(owner, "event-1", mapOf("amount" to 90000, "income" to false, "title" to "Продукты", "category" to "Продукты", "date" to "2026-10-30"))
        assertEquals(90000L, inbox.find(owner, "event-1")!!.getJSONObject("payload").getLong("amount_kopecks"))
    }
    @Test fun skipAndAccountChangeInvalidateOldActions() {
        assertTrue(inbox.action(owner, "event-1", "skip"))
        assertFalse(inbox.action(owner, "event-1", "add"))
        inbox.account("another-user")
        assertFalse(inbox.action(owner, "event-1", "add"))
        assertTrue(inbox.pending("another-user").isEmpty())
        assertNull(inbox.upload())
    }
    @Test fun confirmedRowsDoNotExpireOrDependOnListenerPermission() {
        inbox.action(owner, "event-1", "add")
        val row = inbox.find(owner, "event-1")!!.put("receivedAt", 1)
        context.getSharedPreferences("kopi_notification_inbox", Context.MODE_PRIVATE).edit().putString("queue", JSONArray().put(row).toString()).commit()
        Settings.Secure.putString(context.contentResolver, "enabled_notification_listeners", "")
        assertEquals(1, NotificationInbox(context).pending(owner).size)
    }
    @Test fun promptHasThreeActionsAndHidesAmountsOnLockScreen() {
        NotificationPrompts(context).show(inbox.find(owner, "event-1")!!)
        val notification = shadowOf(context.getSystemService(NotificationManager::class.java)).allNotifications.single()
        assertEquals(listOf("Добавить", "Изменить", "Пропустить"), notification.actions.map { it.title.toString() })
        assertEquals(Notification.VISIBILITY_PRIVATE, notification.visibility)
        assertFalse(notification.publicVersion.extras.toString().contains("850"))
        assertFalse(notification.extras.toString().contains("12000"))
        notification.actions.first().actionIntent.send()
        shadowOf(android.os.Looper.getMainLooper()).idle()
        assertTrue(inbox.find(owner, "event-1")!!.optBoolean("confirmed"))
    }
    @Test fun nativeParserRejectsAmbiguousMessages() {
        assertEquals("c570d78b-672b-534d-a505-375483672ba1", BankOperation.transactionId(owner, "event-1"))
        for (text in listOf("Код 1234. Покупка 850 ₽", "Баланс 850 ₽", "Покупка 1.234,56 ₽", "Покупка 12 34 ₽", "Оплата будет 450 ₽", "Покупка 850 ₽ комиссия 10 ₽", "Оплата 20 USD")) assertNull(text, BankOperation.parse(text))
        assertEquals(123456L, BankOperation.parse("Покупка 1 234,56 ₽ Пятёрочка. Баланс 9000 ₽")!!.amount)
        assertEquals("Зарплата", BankOperation.parse("Зачисление зарплаты 30 000 ₽")!!.category)
    }
    @Test fun failedUploadIsRetriedWithSameIdAndAckOnlyAfterSuccess() {
        inbox.action(owner, "event-1", "add")
        context.getSharedPreferences("kopi_notification_inbox", Context.MODE_PRIVATE).edit()
            .putString("token", "test-token").putString("key", "test-key").putString("url", "https://example.invalid")
            .putLong("expires", System.currentTimeMillis() / 1000 + 3600).commit()
        val worker = TestListenableWorkerBuilder<StubUploadWorker>(context).build()
        assertEquals(Result.retry(), worker.doWork())
        assertTrue(inbox.stillConfirmed(owner, "event-1"))
        worker.response = 201
        assertEquals(Result.success(), worker.doWork())
        assertNull(inbox.find(owner, "event-1"))
        assertEquals(2, worker.ids.size)
        assertEquals(worker.ids[0], worker.ids[1])
        assertEquals(Result.success(), worker.doWork())
        assertEquals(2, worker.ids.size)
    }
    @Test fun expiredSessionDoesNotDiscardConfirmedRow() {
        inbox.action(owner, "event-1", "add")
        val worker = TestListenableWorkerBuilder<StubUploadWorker>(context).build()
        assertEquals(Result.success(), worker.doWork())
        assertTrue(worker.ids.isEmpty())
        assertTrue(inbox.stillConfirmed(owner, "event-1"))
    }
}

class StubUploadWorker(context: Context, params: WorkerParameters) : NotificationUploadWorker(context, params) {
    var response = 503
    val ids = mutableListOf<String>()
    override fun post(batch: UploadBatch, payload: JSONObject): Int {
        ids.add(payload.getString("id"))
        return response
    }
}
