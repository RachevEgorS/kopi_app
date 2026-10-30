import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'diary.dart';

class NotificationOperation {
  final int amount;
  final bool income;
  final String title, category;
  const NotificationOperation(
    this.amount,
    this.income,
    this.title,
    this.category,
  );
}

/// Conservative RUB-only parser. Never treats a balance or an OTP as a purchase.
NotificationOperation? parseBankNotification(String text) {
  final value = text
      .toLowerCase()
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u202f', ' ');
  if (RegExp(
    r'код|парол|otp|отклон|отказ|отмен|не выполн|будет|ожида|предстоит|заплан|пополните|одобрен|между своими|своих счет|кэшбэк до|доллар|usd|eur|€|\$',
  ).hasMatch(value)) {
    return null;
  }
  final main = value.split(RegExp(r'остаток|баланс|доступно')).first;
  final incoming = RegExp(r'зачислен|поступил|получен|возврат').hasMatch(main);
  final outgoing = RegExp(
    r'покупка|оплата|списан|перевод выполнен|перевод отправлен',
  ).hasMatch(main);
  if (incoming == outgoing) return null;
  final amounts = RegExp(
    r'(?<![\d.,])(\d+(?: \d{3})*(?:[.,]\d{1,2})?)\s*(?:₽|руб(?:\.|ля|лей)?(?![а-я])|rub\b)',
  ).allMatches(main).toList();
  if (amounts.length != 1) return null;
  final match = amounts.single;
  if (RegExp(r'\d[ .,]*$').hasMatch(main.substring(0, match.start))) {
    return null;
  }
  final amount = parseMoney(match.group(1)!);
  if (amount == null || amount <= 0) return null;
  if (incoming) {
    return NotificationOperation(
      amount,
      true,
      main.contains('зарплат') || main.contains('заработн')
          ? 'Заработная плата'
          : 'Зачисление',
      main.contains('зарплат') || main.contains('заработн')
          ? 'Зарплата'
          : 'Другой доход',
    );
  }
  final groceries = RegExp(
    r'пят[её]роч|pyateroch|магнит|magnit|перекр[её]ст|perekrest|вкусвилл|vkusvill',
  ).hasMatch(main);
  return NotificationOperation(
    amount,
    false,
    groceries ? 'Покупка продуктов' : 'Покупка из уведомления',
    groceries ? 'Продукты' : 'Другое',
  );
}

abstract final class NotificationBridge {
  static const _channel = MethodChannel('kopi/notifications');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<void> account(String? owner) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('account', {'owner': owner});
    } on MissingPluginException {
      /* Widget tests and an old hot-reloaded engine. */
    }
  }

  static Future<Map<String, dynamic>> status(String owner) async =>
      Map<String, dynamic>.from(
        await _channel.invokeMethod('status', {'owner': owner}) as Map,
      );
  static Future<List<Map<String, dynamic>>> pending(String owner) async =>
      (await _channel.invokeListMethod<dynamic>('pending', {'owner': owner}) ??
              [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
  static Future<List<Map<String, dynamic>>> apps() async =>
      (await _channel.invokeListMethod<dynamic>('apps') ?? [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
  static Future<void> settings() => _channel.invokeMethod('settings');
  static Future<void> configure(
    String owner,
    bool enabled,
    bool automatic,
    Set<String> packages,
  ) => _channel.invokeMethod('configure', {
    'owner': owner,
    'enabled': enabled,
    'automatic': automatic,
    'packages': packages.toList(),
  });
  static Future<void> ack(String owner, String id) =>
      _channel.invokeMethod('ack', {'owner': owner, 'id': id});
}
