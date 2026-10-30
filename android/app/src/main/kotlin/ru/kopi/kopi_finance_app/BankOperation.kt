package ru.kopi.kopi_finance_app

import java.math.BigDecimal
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.util.Locale
import java.util.UUID

/** Same conservative rules as notification_import.dart; amounts are integer kopecks. */
data class BankOperation(val amount: Long, val income: Boolean, val title: String, val category: String) {
    companion object {
        fun parse(text: String): BankOperation? {
            val value = text.lowercase(Locale.ROOT).replace('\u00a0', ' ').replace('\u202f', ' ')
            if (Regex("код|парол|otp|отклон|отказ|отмен|не выполн|будет|ожида|предстоит|заплан|пополните|одобрен|между своими|своих счет|кэшбэк до|доллар|usd|eur|€|\\$").containsMatchIn(value)) return null
            val main = value.split(Regex("остаток|баланс|доступно")).first()
            val income = Regex("зачислен|поступил|получен|возврат").containsMatchIn(main)
            val expense = Regex("покупка|оплата|списан|перевод выполнен|перевод отправлен").containsMatchIn(main)
            if (income == expense) return null
            val matches = Regex("(?<![\\d.,])(\\d+(?: \\d{3})*(?:[.,]\\d{1,2})?)\\s*(?:₽|руб(?:\\.|ля|лей)?(?![а-я])|rub\\b)").findAll(main).toList()
            if (matches.size != 1) return null
            val match = matches.single()
            if (Regex("\\d[ .,]*$").containsMatchIn(main.substring(0, match.range.first))) return null
            val number = match.groupValues[1].replace(" ", "").replace(',', '.')
            if (!Regex("\\d{1,9}(\\.\\d{1,2})?").matches(number)) return null
            val amount = try { BigDecimal(number).movePointRight(2).longValueExact() } catch (_: Exception) { return null }
            if (amount !in 1..99999999999L) return null
            val salary = main.contains("зарплат") || main.contains("заработн")
            val groceries = Regex("пят[её]роч|pyateroch|магнит|magnit|перекр[её]ст|perekrest|вкусвилл|vkusvill").containsMatchIn(main)
            return if (income) BankOperation(amount, true, if (salary) "Заработная плата" else "Зачисление", if (salary) "Зарплата" else "Другой доход")
            else BankOperation(amount, false, if (groceries) "Покупка продуктов" else "Покупка из уведомления", if (groceries) "Продукты" else "Другое")
        }

        fun transactionId(owner: String, source: String): String {
            val namespace = UUID.fromString("6ba7b811-9dad-11d1-80b4-00c04fd430c8")
            val bytes = ByteBuffer.allocate(16).putLong(namespace.mostSignificantBits).putLong(namespace.leastSignificantBits).array()
            val hash = MessageDigest.getInstance("SHA-1").digest(bytes + "kopi:notification:$owner:$source".toByteArray(Charsets.UTF_8))
            hash[6] = ((hash[6].toInt() and 15) or 80).toByte()
            hash[8] = ((hash[8].toInt() and 63) or 128).toByte()
            val buffer = ByteBuffer.wrap(hash)
            return UUID(buffer.long, buffer.long).toString()
        }
    }
}
