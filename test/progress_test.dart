import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kopi_finance_app/data/diary.dart';
import 'package:kopi_finance_app/data/progress.dart';
import 'package:kopi_finance_app/main.dart';
import 'package:kopi_finance_app/ui/design.dart';
import 'package:kopi_finance_app/ui/finance_flow.dart';
import 'package:kopi_finance_app/ui/progress_pages.dart';
import 'flow_test.dart' show tapText;
import 'finance_test.dart' show fixture;

final today = DateTime(2026, 10, 12);
SavingGoal laptop({int weekly = 200000, int saved = 4000000}) => SavingGoal(
  id: 'laptop',
  title: 'Новый ноутбук',
  target: 8000000,
  saved: saved,
  weekly: weekly,
  nextContribution: addDays(today, 7),
);
Entry expense(
  String id,
  int amount,
  DateTime date, {
  String category = 'Кафе',
  bool income = false,
}) => Entry(
  id: id,
  title: id,
  amount: amount,
  category: category,
  date: date,
  isIncome: income,
);
Future<DiaryStore> sample() async {
  final store = await fixture();
  await store.saveProfile('Алексей', 'alexey@example.ru');
  await store.saveGoal(laptop());
  await store.saveGoal(
    SavingGoal(
      id: 'travel',
      title: 'Маленькое путешествие',
      target: 4000000,
      saved: 1200000,
      weekly: 50000,
      nextContribution: addDays(today, 7),
      icon: 'leaf',
    ),
  );
  store.entries = [
    expense('Продукты', 746200, today, category: 'Продукты'),
    expense('Дом', 564200, today, category: 'Дом'),
    expense('Кафе', 309400, today),
    expense('Прочее', 200200, today, category: 'Прочее'),
    expense('Прошлый месяц', 234394, DateTime(2026, 9, 12)),
  ];
  store.payments = [
    PlannedPayment(
      id: 'subscriptions',
      title: 'Подписки',
      amount: 390000,
      start: today,
      monthly: true,
    ),
  ];
  for (var i = 6; i >= 0; i--) {
    await store.checkToday(addDays(today, -i));
  }
  return store;
}

void main() {
  test(
    'Forecast uses actual weekly dates, ceiling, zero pace and completed goals',
    () {
      expect(laptop().forecast(today).contributions, 20);
      expect(laptop().forecast(today).finish, addDays(today, 140));
      expect(laptop().forecast(today).label(today), 'Через 20 недель');
      expect(laptop().forecast(today, extra: 100000).contributions, 14);
      expect(laptop(weekly: 0).forecast(today).finish, isNull);
      expect(laptop(weekly: 0).forecast(today).label(today), 'Задай свой темп');
      expect(
        laptop(saved: 8100000).forecast(today).label(today),
        'Мечта сбылась',
      );
      expect(laptop(saved: 8100000).progress, 1);
      expect(
        laptop().dueOnOrAfter(DateTime(2026, 10, 27)),
        DateTime(2026, 11, 2),
      );
    },
  );

  test(
    'Goal reserve covers remaining scheduled contributions, caps remaining and avoids double reserve',
    () async {
      final store = await fixture();
      await store.saveGoal(laptop());
      expect(laptop().reserveIn(today, today), 400000);
      expect(laptop().reserveIn(DateTime(2026, 9), today), 0);
      expect(laptop(saved: 7900000).reserveIn(today, today), 100000);
      expect(
        store.dreamsReserveFor(today, today),
        500000,
      ); // manual reserve is larger
      await store.saveGoal(laptop(weekly: 400000));
      expect(store.dreamsReserveFor(today, today), 800000);
    },
  );

  test(
    'Analytics excludes income, separates months and compares equal elapsed days',
    () {
      final entries = [
        expense('current', 13200, today),
        expense('old', 10000, DateTime(2026, 9, 12)),
        expense('later', 90000, DateTime(2026, 9, 22)),
        expense('salary', 1000000, today, income: true),
      ];
      final stats = ExpenseAnalytics.from(entries, today, today);
      expect(stats.total, 13200);
      expect(stats.categories.single.amount, 13200);
      expect(stats.observation, 'Кафе: на 32% больше');
      expect(
        ExpenseAnalytics.from([entries.first], today, today).observation,
        contains('новая статья'),
      );
      expect(ExpenseAnalytics.from([], today, today).total, 0);
      final march = ExpenseAnalytics.from(
        [
          expense('a', 100, DateTime(2026, 3, 28)),
          expense('b', 100, DateTime(2026, 2, 28)),
          expense('c', 900, DateTime(2026, 3, 31)),
        ],
        DateTime(2026, 3),
        DateTime(2026, 3, 31),
      );
      expect(march.total, 1000);
      expect(march.observation, contains('том же уровне'));
      expect(march.comparison, contains('28 дней'));
    },
  );

  test(
    'Streak crosses month boundary, tolerates today pending and resets after missed day',
    () {
      final days = {
        for (var i = 0; i < 7; i++) dayKey(DateTime(2026, 9, 29 + i)),
      };
      expect(currentStreak(days, DateTime(2026, 10, 5)), 7);
      expect(currentStreak(days, DateTime(2026, 10, 6)), 7);
      expect(currentStreak(days, DateTime(2026, 10, 7)), 0);
      expect(longestStreak(days), 7);
      expect(civilDaysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
    },
  );

  test(
    'Goals, profile, preferences and permanent badges survive restart and legacy migration',
    () async {
      final store = await fixture();
      for (var i = 6; i >= 0; i--) {
        await store.checkToday(addDays(today, -i));
      }
      await store.checkToday(today);
      expect(store.checkedDays.length, 7);
      await store.saveGoal(laptop(saved: 8000000));
      await store.deleteGoal('laptop');
      await store.saveProfile('Алексей', 'new@example.ru');
      await store.savePreferences(reminders: false, support: false);
      final restored = DiaryStore(await SharedPreferences.getInstance())
        ..load();
      expect(restored.name, 'Алексей');
      expect(restored.email, 'new@example.ru');
      expect(restored.remindersEnabled, false);
      expect(restored.supportEnabled, false);
      expect(restored.badges, containsAll(['week', 'goal']));
      expect(restored.checkedDays.length, 7);
      final old =
          jsonDecode(restored.preferences.getString(DiaryStore.storageKey)!)
              as Map<String, dynamic>;
      for (final key in [
        'goals',
        'checkedDays',
        'badges',
        'remindersEnabled',
        'supportEnabled',
      ]) {
        old.remove(key);
      }
      await restored.preferences.setString(
        DiaryStore.storageKey,
        jsonEncode(old),
      );
      final migrated = DiaryStore(restored.preferences)..load();
      expect(migrated.recovered, false);
      expect(migrated.name, 'Алексей');
      expect(migrated.goals, isEmpty);
      expect(migrated.remindersEnabled, true);
    },
  );

  testWidgets(
    'Diary → create goal → preview/cancel/apply forecast → daily check → overview',
    (tester) async {
      final store = await fixture();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(KopiApp(store: store, clock: () => today));
      await tapText(tester, 'Мечты');
      await tapText(tester, '+ Новая мечта');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Новый ноутбук');
      await tester.enterText(fields.at(1), '80000');
      await tester.enterText(fields.at(2), '40000');
      await tester.enterText(fields.at(3), '2000');
      await tapText(tester, 'Сохранить мечту');
      expect(find.byType(ForecastScreen), findsOneWidget);
      expect(store.goals.single.weekly, 200000);
      final slider = find.byKey(const ValueKey('goal-extra-slider'));
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(90, 0));
      await tester.pumpAndSettle();
      expect(store.goals.single.weekly, 200000);
      await tapText(tester, 'Выбрать этот план');
      await tapText(tester, 'Оставить прежний');
      expect(store.goals.single.weekly, 200000);
      await tapText(tester, 'Выбрать этот план');
      await tapText(tester, 'Подтвердить план');
      expect(store.goals.single.weekly, greaterThan(200000));
      expect(store.dreamsReserveFor(today, today), greaterThan(500000));
      await tapText(tester, 'Мечты');
      await tapText(tester, 'Маленькие шаги и достижения →');
      await tapText(tester, 'Я проверил учёт за сегодня');
      expect(store.checkedDays.length, 1);
      await tapText(tester, 'Сегодня уже отмечено ✓');
      expect(store.checkedDays.length, 1);
      await tapText(tester, 'Обзор');
      expect(find.text('Наблюдения'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Profile settings, edit, budget return, help and logout are connected',
    (tester) async {
      final store = await fixture();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(KopiApp(store: store, clock: () => today));
      await tester.tap(find.byTooltip('Профиль'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tapText(tester, 'Напоминания');
      await tapText(tester, 'Поддержка Копи');
      expect(store.remindersEnabled, false);
      expect(store.supportEnabled, false);
      await tapText(tester, 'Изменить профиль');
      await tester.enterText(find.byType(TextFormField).first, 'Алексей');
      await tester.enterText(
        find.byType(TextFormField).last,
        'alexey@example.ru',
      );
      await tapText(tester, 'Сохранить профиль');
      expect(find.text('Алексей'), findsOneWidget);
      await tapText(tester, 'Мой бюджет');
      await tapText(tester, 'Сохранить мой план');
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tapText(tester, 'Обучение и помощь');
      await tapText(tester, 'Понятно');
      await tapText(tester, 'Выйти из дневника');
      expect(store.signedIn, false);
      expect(find.text('Рады видеть снова'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Populated progress screens fit narrow and enlarged layouts', (
    tester,
  ) async {
    final store = await sample();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.6]) {
        tester.view.physicalSize = Size(width, 740);
        for (final page in [
          FinancePage.analytics,
          FinancePage.goals,
          FinancePage.forecast,
          FinancePage.achievements,
          FinancePage.profile,
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: kopiTheme(),
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(
                  textScaler: TextScaler.linear(scale),
                  viewInsets: const EdgeInsets.only(bottom: 180),
                ),
                child: child!,
              ),
              home: FinanceFlow(
                store: store,
                initial: page,
                goalId: 'laptop',
                clock: () => today,
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
  });

  testWidgets('Export remaining five screens', (tester) async {
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
    final store = await sample();
    for (final entry in {
      '11-analytics': FinancePage.analytics,
      '12-goals': FinancePage.goals,
      '13-forecast': FinancePage.forecast,
      '14-achievements': FinancePage.achievements,
      '15-profile': FinancePage.profile,
    }.entries) {
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
                goalId: 'laptop',
                clock: () => today,
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
        await File(
          'previews/${entry.key}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
