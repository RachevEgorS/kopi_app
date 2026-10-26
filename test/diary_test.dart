import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kopi_finance_app/data/diary.dart';

void main() {
  test('Parses kopecks exactly and rejects invalid amounts', () {
    expect(parseMoney('60 000,15'), 6000015);
    expect(parseMoney('0.01'), 1);
    expect(parseMoney('-50'), isNull);
    expect(parseMoney('2.999'), isNull);
    expect(parseMoney('1e6'), isNull);
    expect(parseMoney(''), isNull);
    expect(money(124050), '1 240,50 ₽');
  });
  test('Specification daily allowance example and deficit', () {
    final result = DailyAllowance.calculate(
      limit: 3000000,
      spent: 1200000,
      available: 2500000,
      reserve: 500000,
      dreams: 200000,
      days: 10,
    );
    expect(result.free, 1100000);
    expect(result.amount, 110000);
    final deficit = DailyAllowance.calculate(
      limit: 10000,
      spent: 20000,
      available: 0,
      reserve: 0,
      dreams: 0,
      days: 1,
    );
    expect(deficit.amount, 0);
    expect(deficit.free, -10000);
  });
  test('Daily allowance rounds down to kopecks', () {
    expect(
      DailyAllowance.calculate(
        limit: 100,
        spent: 0,
        available: 100,
        reserve: 0,
        dreams: 0,
        days: 3,
      ).amount,
      33,
    );
  });
  test(
    'State survives restart, budgets stay in their months, duplicate entries are ignored',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DiaryStore(prefs)..load();
      expect(store.introduced, false);
      await store.enterDemo('Аня', 'anya@example.ru');
      await store.saveBudget(
        DateTime(2026, 10),
        const Budget(
          income: 6000000,
          limit: 5000000,
          reserve: 1100000,
          dreams: 500000,
        ),
      );
      final entry = Entry(
        id: 'one',
        title: 'Кофе',
        category: 'Кафе',
        amount: 45000,
        date: DateTime(2026, 10, 26),
      );
      await store.addEntry(entry);
      await store.addEntry(entry);
      final restored = DiaryStore(prefs)..load();
      expect(restored.signedIn, true);
      expect(restored.setupDone, true);
      expect(restored.budgets['2026-10']?.income, 6000000);
      expect(restored.budgets['2026-11'], isNull);
      expect(restored.entriesFor(DateTime(2026, 10)).length, 1);
      expect(restored.entriesFor(DateTime(2026, 11)), isEmpty);
      expect(
        prefs.getString(DiaryStore.storageKey),
        isNot(contains('password')),
      );
      await restored.logout();
      final signedOut = DiaryStore(prefs)..load();
      expect(signedOut.introduced, true);
      expect(signedOut.signedIn, false);
      expect(signedOut.entries.length, 1);
    },
  );
}
