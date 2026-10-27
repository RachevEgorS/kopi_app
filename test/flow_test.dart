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
import 'package:kopi_finance_app/ui/screens.dart';

Future<DiaryStore> emptyStore() async {
  SharedPreferences.setMockInitialValues({});
  return DiaryStore(await SharedPreferences.getInstance())
    ..load()
    ..educationSkipped = true;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('First-run registration → current budget → diary → restart', (
    tester,
  ) async {
    final store = await emptyStore();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      KopiApp(store: store, clock: () => DateTime(2026, 10, 26)),
    );
    expect(find.text('Деньги\nв своём ритме'), findsOneWidget);
    await tapText(tester, 'Начать свой дневник');
    await tapText(tester, 'Создать дневник');
    expect(find.text('Проверь адрес почты'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Аня');
    await tester.enterText(find.byType(TextFormField).at(1), 'anya@example.ru');
    await tester.enterText(find.byType(TextFormField).at(2), 'demo12345');
    await tapText(tester, 'Создать дневник');
    await tapText(tester, 'Продолжить в деморежиме');
    expect(find.text('План на октябрь'), findsOneWidget);
    for (final (i, value) in ['60000', '50000', '11000', '5000'].indexed) {
      await tester.enterText(find.byType(TextFormField).at(i), value);
    }
    await tapText(tester, 'Сохранить мой план');
    expect(find.text('Можно потратить сегодня'), findsOneWidget);
    expect(find.text('5 666,66 ₽'), findsOneWidget);
    await tester.tap(find.byTooltip('Следующий месяц'));
    await tester.pumpAndSettle();
    expect(find.text('Ноябрь 2026'), findsOneWidget);
    expect(find.text('— ₽'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    final restored = DiaryStore(store.preferences)
      ..load()
      ..educationSkipped = true;
    await tester.pumpWidget(
      KopiApp(store: restored, clock: () => DateTime(2026, 10, 26)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Можно потратить сегодня'), findsOneWidget);
    expect(find.text('Деньги\nв своём ритме'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Skip budget and add expense updates totals without duplicates', (
    tester,
  ) async {
    final store = await emptyStore();
    await store.enterDemo('Аня', 'anya@example.ru');
    await tester.pumpWidget(
      KopiApp(store: store, clock: () => DateTime(2026, 10, 26)),
    );
    await tapText(tester, 'Добавить позже');
    await tester.tap(find.byTooltip('Добавить расход'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '450');
    await tester.enterText(find.byType(TextFormField).at(1), 'Кофе с собой');
    await tapText(tester, 'Записать расход');
    expect(store.entries.length, 1);
    expect(find.text('Кофе с собой'), findsOneWidget);
    expect(find.text('450 ₽'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Five screens fit narrow screens and enlarged text', (
    tester,
  ) async {
    final store = await emptyStore();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 600.0]) {
      tester.view.physicalSize = Size(width, 740);
      for (final scale in [1.0, 1.6]) {
        final screens = <Widget>[
          WelcomeScreen(onRegister: () {}, onLogin: () {}),
          AuthScreen(
            register: false,
            store: store,
            onBack: () {},
            onSwitch: () {},
            onComplete: () {},
          ),
          AuthScreen(
            register: true,
            store: store,
            onBack: () {},
            onSwitch: () {},
            onComplete: () {},
          ),
          BudgetScreen(
            month: DateTime(2026, 10),
            onBack: () {},
            onSave: (_) async {},
          ),
          DiaryScreen(
            store: store,
            month: DateTime(2026, 10),
            today: DateTime(2026, 10, 26),
            onMonth: (_) {},
            onBudget: () {},
            onLogout: () async {},
          ),
        ];
        for (final screen in screens) {
          await tester.pumpWidget(
            MaterialApp(
              theme: kopiTheme(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 740),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Scaffold(body: SafeArea(child: screen)),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.runtimeType}, width $width, text $scale',
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  });

  testWidgets('Export five reference previews using bundled fonts', (
    tester,
  ) async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final (family, asset) in [
      ('Inter', 'Inter.ttf'),
      ('PTSerif', 'PTSerif-Regular.ttf'),
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$asset'))).load();
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await emptyStore();
    await store.enterDemo('Аня', 'anya@example.ru');
    const budget = Budget(
      income: 6000000,
      limit: 5000000,
      reserve: 1100000,
      dreams: 500000,
    );
    await store.saveBudget(DateTime(2026, 10), budget);
    final screens = <String, Widget>{
      '01-welcome': WelcomeScreen(onRegister: () {}, onLogin: () {}),
      '02-login': AuthScreen(
        register: false,
        store: store,
        onBack: () {},
        onSwitch: () {},
        onComplete: () {},
      ),
      '03-register': AuthScreen(
        register: true,
        store: store,
        onBack: () {},
        onSwitch: () {},
        onComplete: () {},
      ),
      '04-budget': BudgetScreen(
        month: DateTime(2026, 10),
        initial: budget,
        onBack: () {},
        onSave: (_) async {},
      ),
      '05-diary': DiaryScreen(
        store: store,
        month: DateTime(2026, 10),
        today: DateTime(2026, 10, 26),
        onMonth: (_) {},
        onBudget: () {},
        onLogout: () async {},
      ),
    };
    for (final entry in screens.entries) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: kopiTheme(),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                child: entry.value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (entry.key == '05-diary') {
        await tester.tap(find.byTooltip('Профиль'));
        await tester.pumpAndSettle();
        await tapText(tester, 'Посмотреть пример дневника');
      }
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
