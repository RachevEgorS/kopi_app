import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kopi_finance_app/data/diary.dart';
import 'package:kopi_finance_app/main.dart';
import 'package:kopi_finance_app/ui/design.dart';
import 'package:kopi_finance_app/ui/finance_flow.dart';
import 'flow_test.dart' show tapText;

Future<DiaryStore> fixture({bool sample = false}) async {
  SharedPreferences.setMockInitialValues({});
  final store = DiaryStore(await SharedPreferences.getInstance());
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
  if (sample) {
    store.entries = [
      Entry(
        id: 'coffee',
        title: 'Кофе с собой',
        category: 'Кафе',
        amount: 45000,
        date: DateTime(2026, 10, 12, 12),
      ),
      Entry(
        id: 'food',
        title: 'Продукты на неделю',
        category: 'Продукты',
        amount: 218000,
        date: DateTime(2026, 10, 12, 11),
      ),
      Entry(
        id: 'bus',
        title: 'Поездка домой',
        category: 'Транспорт',
        amount: 32000,
        date: DateTime(2026, 10, 12, 10),
      ),
      Entry(
        id: 'salary',
        title: 'Зарплата',
        category: 'Зарплата',
        amount: 6000000,
        date: DateTime(2026, 10),
        isIncome: true,
      ),
    ];
    store.payments = [
      PlannedPayment(
        id: 'movie',
        title: 'Кино и сериалы',
        amount: 149000,
        start: DateTime(2026, 10, 15),
        monthly: true,
        reminderDays: 3,
      ),
      PlannedPayment(
        id: 'home',
        title: 'Коммунальные услуги',
        amount: 520000,
        start: DateTime(2026, 10, 20),
        monthly: true,
      ),
      PlannedPayment(
        id: 'net',
        title: 'Интернет',
        amount: 70000,
        start: DateTime(2026, 10, 25),
        monthly: true,
        reminderDays: 0,
      ),
    ];
  }
  return store;
}

void main() {
  test('Old saved entries migrate without losing budgets or session', () async {
    final store = await fixture();
    final json =
        jsonDecode(store.preferences.getString(DiaryStore.storageKey)!)
            as Map<String, dynamic>;
    json.remove('payments');
    json['entries'] = [
      {
        'id': 'old',
        'title': 'Кофе',
        'category': 'Кафе',
        'amount': 45000,
        'date': '2026-10-12T00:00:00.000',
      },
    ];
    await store.preferences.setString(DiaryStore.storageKey, jsonEncode(json));
    final restored = DiaryStore(store.preferences)..load();
    expect(restored.recovered, false);
    expect(restored.signedIn, true);
    expect(restored.entries.single.isIncome, false);
    expect(restored.payments, isEmpty);
    expect(restored.budgets['2026-10']?.limit, 5000000);
  });
  test(
    'Monthly dates clamp without losing the original day, including leap years',
    () {
      final payment = PlannedPayment(
        id: 'p',
        title: 'Подписка',
        amount: 10000,
        start: DateTime(2028, 1, 31),
        monthly: true,
      );
      expect(payment.inMonth(DateTime(2027, 12)), isNull);
      expect(payment.inMonth(DateTime(2028, 2))!.date, DateTime(2028, 2, 29));
      expect(payment.inMonth(DateTime(2028, 3))!.date, DateTime(2028, 3, 31));
      expect(payment.inMonth(DateTime(2029, 2))!.date, DateTime(2029, 2, 28));
    },
  );
  test('Income, edits and deletion update totals and persist', () async {
    final store = await fixture();
    await store.addEntry(
      Entry(
        id: 'salary',
        title: 'Подработка',
        category: 'Подработка',
        amount: 100000,
        date: DateTime(2026, 10, 12),
        isIncome: true,
      ),
    );
    expect(store.spentFor(DateTime(2026, 10)), 0);
    expect(store.incomeFor(DateTime(2026, 10)), 6100000);
    await store.updateEntry(
      Entry(
        id: 'salary',
        title: 'Покупки',
        category: 'Покупки',
        amount: 25000,
        date: DateTime(2026, 11),
      ),
    );
    expect(store.incomeFor(DateTime(2026, 10)), 6000000);
    expect(store.spentFor(DateTime(2026, 11)), 25000);
    final restored = DiaryStore(store.preferences)..load();
    expect(restored.entries.single.amount, 25000);
    await restored.deleteEntry('salary');
    expect(restored.entries, isEmpty);
  });
  test(
    'Payment is saved, reserves are not doubled, paying is idempotent and reversible',
    () async {
      final store = await fixture();
      final month = DateTime(2026, 10);
      final payment = PlannedPayment(
        id: 'p',
        title: 'Интернет',
        amount: 70000,
        start: DateTime(2026, 10, 12),
        monthly: true,
      );
      await store.savePayment(payment);
      expect(store.reserveFor(month), 1100000);
      final before = DailyAllowance.calculate(
        limit: 5000000,
        spent: store.spentFor(month),
        available: store.incomeFor(month) - store.spentFor(month),
        reserve: store.reserveFor(month),
        dreams: 500000,
        days: 20,
      );
      final occurrence = payment.inMonth(month)!;
      await store.pay(occurrence, DateTime(2026, 10, 12));
      await store.pay(occurrence, DateTime(2026, 10, 12));
      expect(store.entries.length, 1);
      expect(store.reserveFor(month), 1030000);
      final after = DailyAllowance.calculate(
        limit: 5000000,
        spent: store.spentFor(month),
        available: store.incomeFor(month) - store.spentFor(month),
        reserve: store.reserveFor(month),
        dreams: 500000,
        days: 20,
      );
      expect(after.free, before.free);
      final restored = DiaryStore(store.preferences)..load();
      expect(restored.isPaid(occurrence), true);
      expect(restored.payments.single.monthly, true);
      await restored.deleteEntry(restored.entries.single.id);
      expect(restored.isPaid(occurrence), false);
      expect(restored.reserveFor(month), 1100000);
      await restored.deletePayment('p');
      expect(restored.payments, isEmpty);
    },
  );

  testWidgets('Diary → history → income → filtered history → edit → diary', (
    tester,
  ) async {
    final store = await fixture();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      KopiApp(store: store, clock: () => DateTime(2026, 10, 26)),
    );
    await tapText(tester, 'Все записи →');
    expect(find.text('История'), findsOneWidget);
    await tapText(tester, '+ Добавить запись');
    await tapText(tester, 'Доход');
    await tester.enterText(find.byType(TextFormField).first, '1250,50');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Подработка в выходные',
    );
    await tapText(tester, 'Записать доход');
    expect(find.text('История'), findsOneWidget);
    expect(store.entries.single.isIncome, true);
    await tapText(tester, 'Расходы');
    expect(find.text('Подработка в выходные'), findsNothing);
    await tapText(tester, 'Доходы');
    await tester.enterText(find.byType(TextField).first, 'выходные');
    await tester.pumpAndSettle();
    await tapText(tester, 'Подработка в выходные');
    await tester.enterText(find.byType(TextFormField).first, '1500');
    await tapText(tester, 'Сохранить изменения');
    expect(find.text('+1 500 ₽'), findsOneWidget);
    expect(store.entries.length, 1);
    await tapText(tester, 'Дневник');
    expect(find.text('Можно потратить сегодня'), findsOneWidget);
    expect(find.text('61 500 ₽'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Calendar → payment → subscription → pay → history with linked expense',
    (tester) async {
      final store = await fixture();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        KopiApp(store: store, clock: () => DateTime(2026, 10, 26)),
      );
      await tapText(tester, 'Календарь');
      await tapText(tester, '+ Запланировать платёж');
      await tester.enterText(find.byType(TextFormField).first, 'Интернет');
      await tester.enterText(find.byType(TextFormField).at(1), '700');
      await tapText(tester, 'Один раз');
      await tapText(tester, 'Каждый месяц');
      await tapText(tester, 'Сохранить платёж');
      expect(store.payments.length, 1);
      expect(find.text('Интернет'), findsOneWidget);
      await tapText(tester, 'Подписки →');
      expect(find.text('Регулярные платежи'), findsOneWidget);
      await tapText(tester, 'Интернет');
      await tapText(tester, 'Отметить оплаченным');
      await tapText(tester, 'Да, записать оплату');
      expect(store.entries.single.amount, 70000);
      expect(store.entries.single.paymentOccurrence, isNotNull);
      await tapText(tester, 'Дневник');
      expect(find.text('Можно потратить сегодня'), findsOneWidget);
      await tapText(tester, 'Все записи →');
      expect(find.text('Интернет'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Five new screens render on narrow devices with enlarged text and keyboard',
    (tester) async {
      final store = await fixture(sample: true);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 740);
        for (final scale in [1.0, 1.6]) {
          for (final page in FinancePage.values) {
            await tester.pumpWidget(
              MaterialApp(
                theme: kopiTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    viewInsets: const EdgeInsets.only(bottom: 180),
                  ),
                  child: child!,
                ),
                home: FinanceFlow(
                  store: store,
                  initial: page,
                  initialDate: DateTime(2026, 10, 12),
                  clock: () => DateTime(2026, 10, 26),
                  onBudget: () {},
                  onLogout: () async {},
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$page width=$width scale=$scale',
            );
            await tester.pumpWidget(const SizedBox());
          }
        }
      }
    },
  );

  testWidgets('Export next five screens', (tester) async {
    for (final (family, asset) in [
      ('Inter', 'assets/fonts/Inter.ttf'),
      ('PTSerif', 'assets/fonts/PTSerif-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await fixture(sample: true);
    final pages = {
      '06-history': FinancePage.history,
      '07-operation': FinancePage.operation,
      '08-calendar': FinancePage.calendar,
      '09-payment': FinancePage.payment,
      '10-subscriptions': FinancePage.subscriptions,
    };
    for (final entry in pages.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: kopiTheme(),
          home: RepaintBoundary(
            key: key,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 24, bottom: 24),
              ),
              child: FinanceFlow(
                store: store,
                initial: entry.value,
                clock: () => DateTime(2026, 10, 12),
                initialDate: DateTime(2026, 10, 12),
                onBudget: () {},
                onLogout: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('previews/${entry.key}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
