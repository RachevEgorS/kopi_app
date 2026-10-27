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
import 'package:kopi_finance_app/ui/education.dart';
import 'package:kopi_finance_app/ui/finance_flow.dart';
import 'package:kopi_finance_app/ui/goal_icons.dart';
import 'package:kopi_finance_app/ui/progress_pages.dart';
import 'finance_test.dart' show fixture;
import 'flow_test.dart' show tapText;
import 'progress_test.dart' show sample, today;

Future<void> settleEducation(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

void phone(WidgetTester tester, {double width = 390}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('48 unique icon ids and backward-compatible existing goal symbols', () {
    expect(goalIcons.length, 48);
    expect(goalIcons.map((item) => item.id).toSet().length, 48);
    expect(goalIconById('laptop').line, Glyph.laptop);
    expect(goalIconById('leaf').line, Glyph.leaf);
    expect(goalIconById('flag').line, Glyph.flag);
    expect(goalIconById('unknown-legacy').id, 'laptop');
  });

  testWidgets(
    'First-visit cards close, do not repeat, skip persists and help reopens',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = DiaryStore(await SharedPreferences.getInstance())..load();
      phone(tester);
      await tester.pumpWidget(KopiApp(store: store, clock: () => today));
      await settleEducation(tester);
      expect(find.text('Привет, это Копи'), findsOneWidget);
      await tapText(tester, 'Теперь понятно');
      expect(store.seenEducation, contains('welcome'));
      await tapText(tester, 'Начать свой дневник');
      await settleEducation(tester);
      expect(find.text('Всего три поля'), findsOneWidget);
      await tester.tap(find.byTooltip('Закрыть подсказку'));
      await tester.pumpAndSettle();
      expect(store.seenEducation, contains('register'));
      await tester.tap(find.byTooltip('Назад'));
      await settleEducation(tester);
      expect(find.byType(EducationCard), findsNothing);
      await tapText(tester, 'У меня уже есть аккаунт');
      await settleEducation(tester);
      expect(find.text('С возвращением'), findsOneWidget);
      await tapText(tester, 'Пропустить');
      expect(store.educationSkipped, true);
      await tester.tap(find.byTooltip('Помощь'));
      await tester.pumpAndSettle();
      expect(find.byType(EducationCard), findsOneWidget);
      await tapText(tester, 'Теперь понятно');
      await tester.pumpWidget(const SizedBox());
      final restored = DiaryStore(store.preferences)..load();
      expect(restored.educationSkipped, true);
      expect(
        restored.seenEducation,
        containsAll(['welcome', 'register', 'login']),
      );
      await restored.resetEducation();
      expect(restored.seenEducation, isEmpty);
      expect(restored.educationSkipped, false);
      expect((DiaryStore(store.preferences)..load()).educationSkipped, false);
    },
  );

  testWidgets('Tab education never replaces forms or repeats on return', (
    tester,
  ) async {
    final store = await fixture();
    store.educationSkipped = false;
    phone(tester);
    await tester.pumpWidget(KopiApp(store: store, clock: () => today));
    await settleEducation(tester);
    expect(find.text('Сколько можно сегодня'), findsOneWidget);
    await tapText(tester, 'Теперь понятно');
    await tapText(tester, 'Мечты');
    await settleEducation(tester);
    expect(find.text('Для того, что важно'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(store.seenEducation, contains('goals'));
    await tapText(tester, 'Обзор');
    await settleEducation(tester);
    expect(find.text('Замечай закономерности'), findsOneWidget);
    await tapText(tester, 'Теперь понятно');
    await tapText(tester, 'Мечты');
    await settleEducation(tester);
    expect(find.byType(EducationCard), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Search/select icon updates editor, saved card and forecast after reload',
    (tester) async {
      final store = await sample();
      phone(tester);
      await tester.pumpWidget(KopiApp(store: store, clock: () => today));
      await tapText(tester, 'Мечты');
      await tapText(tester, 'Новый ноутбук');
      await tapText(tester, 'Изменить мечту и накопления');
      await tester.ensureVisible(find.byKey(const ValueKey('goal-icon-field')));
      await tester.tap(find.byKey(const ValueKey('goal-icon-field')));
      await tester.pumpAndSettle();
      expect(find.byType(GoalIconPicker), findsOneWidget);
      final search = find.descendant(
        of: find.byType(GoalIconPicker),
        matching: find.byType(TextField),
      );
      await tester.enterText(search, 'машина');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('choose-icon-car')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choose-icon-car')));
      await tester.pumpAndSettle();
      expect(find.byType(GoalIconPicker), findsNothing);
      await tapText(tester, 'Сохранить мечту');
      expect(store.goals.first.icon, 'car');
      expect(
        tester
            .widget<GoalSymbol>(
              find.descendant(
                of: find.byType(ForecastScreen),
                matching: find.byType(GoalSymbol),
              ),
            )
            .id,
        'car',
      );
      expect((DiaryStore(store.preferences)..load()).goals.first.icon, 'car');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'All education cards and icon picker fit 320px with large text and keyboard',
    (tester) async {
      phone(tester, width: 320);
      for (final topic in educationTopics.keys) {
        await tester.pumpWidget(
          MaterialApp(
            theme: kopiTheme(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 844),
                textScaler: TextScaler.linear(1.6),
              ),
              child: Scaffold(body: EducationCard(topic: topic)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: topic);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: kopiTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 844),
              textScaler: TextScaler.linear(1.6),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: const Scaffold(body: GoalIconPicker(selected: 'laptop')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'несуществующий');
      await tester.pumpAndSettle();
      expect(find.textContaining('Такого значка пока нет'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Export onboarding card and goal icon picker', (tester) async {
    for (final (family, asset) in [
      ('Inter', 'assets/fonts/Inter.ttf'),
      ('PTSerif', 'assets/fonts/PTSerif-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
    phone(tester);
    SharedPreferences.setMockInitialValues({});
    final store = DiaryStore(await SharedPreferences.getInstance());
    final key = GlobalKey();
    Future<void> capture(String file) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'previews/$file.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: KopiApp(store: store, clock: () => today),
      ),
    );
    await settleEducation(tester);
    await capture('16-education');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: kopiTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => chooseGoalIcon(context, 'laptop'),
                child: const Text('Значки'),
              ),
            ),
          ),
        ),
      ),
    );
    await tapText(tester, 'Значки');
    await capture('17-goal-icons');
    await tester.pumpWidget(const SizedBox());
    final financeStore = await fixture(sample: true);
    financeStore.educationSkipped = false;
    final progressStore = await sample();
    progressStore.educationSkipped = false;
    for (final page in [
      FinancePage.history,
      FinancePage.operation,
      FinancePage.calendar,
      FinancePage.payment,
      FinancePage.subscriptions,
      FinancePage.analytics,
      FinancePage.goals,
      FinancePage.forecast,
      FinancePage.achievements,
      FinancePage.profile,
    ]) {
      final selectedStore = page.index >= FinancePage.analytics.index
          ? progressStore
          : financeStore;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: kopiTheme(),
            home: FinanceFlow(
              store: selectedStore,
              goalId: 'laptop',
              initial: page,
              initialDate: today,
              clock: () => today,
              onBudget: () {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      await settleEducation(tester);
      expect(find.text(educationTopics[page.name]!.$1), findsOneWidget);
      await capture('education-${page.name}');
      await tapText(tester, 'Теперь понятно');
      expect(selectedStore.seenEducation, contains(page.name));
      await tester.pumpWidget(const SizedBox());
    }
  });
}
