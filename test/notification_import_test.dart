import 'package:flutter_test/flutter_test.dart';
import 'package:kopi_finance_app/data/notification_import.dart';

void main() {
  test('RUB purchases separate amount from balance and classify groceries', () {
    final parsed = parseBankNotification(
      'VISA *1234 Покупка 1 234,56 ₽ Пятёрочка. Баланс 8 765,44 ₽',
    )!;
    expect(parsed.amount, 123456);
    expect(parsed.income, false);
    expect(parsed.category, 'Продукты');
  });
  test('salary, decimal rubles and refunds are income', () {
    for (final value in [
      'Зачисление заработной платы 60 000 руб.',
      'Поступило 60\u00a0000.00 RUB',
      'Возврат 60000 ₽',
    ]) {
      final parsed = parseBankNotification(value)!;
      expect(parsed.amount, 6000000);
      expect(parsed.income, true);
    }
  });
  test(
    'reject codes, balances, ambiguous, failed, scheduled and unsupported money',
    () {
      for (final value in [
        'Код 123456 для покупки 450 ₽',
        'Пароль: 1234. Оплата 450 ₽',
        'Баланс 50000 ₽',
        'Покупка отклонена 450 ₽',
        'Оплата будет 450 ₽',
        'Зачисление ожидается 5000 ₽',
        'Оплата 20 USD',
        'Покупка 2 EUR',
        'Покупка 450 ₽ комиссия 10 ₽',
        'Покупка 0 ₽',
        'Покупка 1.234,56 ₽',
        'Покупка 12 34 ₽',
        'Перевод выполнен между своими счетами 1000 ₽',
        'Одобрена покупка в рассрочку 10000 ₽',
        'Покупка без суммы',
      ]) {
        expect(parseBankNotification(value), isNull, reason: value);
      }
    },
  );
}
