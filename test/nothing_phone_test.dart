import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kopi_finance_app/data/diary.dart';
import 'package:kopi_finance_app/data/notification_onboarding.dart';
import 'package:kopi_finance_app/main.dart';
import 'package:kopi_finance_app/ui/design.dart';
import 'package:kopi_finance_app/ui/finance_flow.dart';
import 'package:kopi_finance_app/ui/finance_pages.dart';
import 'package:kopi_finance_app/ui/goal_icons.dart';
import 'package:kopi_finance_app/ui/screens.dart';
import 'finance_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kopi/notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'Notification denial is remembered across launches and concurrent checks',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'requestPost');
        calls++;
        return false;
      });
      final onboarding = NotificationOnboarding();
      await Future.wait([
        onboarding.requestOnce(prefs),
        onboarding.requestOnce(prefs),
      ]);
      await NotificationOnboarding().requestOnce(prefs);
      expect(calls, 1);
      expect(prefs.getBool(NotificationOnboarding.preferenceKey), true);
    },
  );

  test(
    'A missing native bridge can retry next launch without a polling loop',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        calls++;
        throw PlatformException(code: 'unavailable');
      });
      final onboarding = NotificationOnboarding();
      await onboarding.requestOnce(prefs);
      await onboarding.requestOnce(prefs);
      expect(calls, 1);
      expect(prefs.getBool(NotificationOnboarding.preferenceKey), isNull);
      await NotificationOnboarding().requestOnce(prefs);
      expect(calls, 2);
    },
  );

  testWidgets('Income has a plus, expense a minus, scheduled payment no sign', (
    tester,
  ) async {
    Entry entry(bool income) => Entry(
      id: '$income',
      title: 'Запись',
      category: 'Кафе',
      amount: 200000,
      date: DateTime(2026, 11, 2),
      isIncome: income,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ExpenseRow(entry: entry(true)),
              ExpenseRow(entry: entry(false)),
              ExpenseRow(entry: entry(false), payment: true),
            ],
          ),
        ),
      ),
    );
    expect(find.text('+${money(200000)}'), findsOneWidget);
    expect(find.text('−${money(200000)}'), findsOneWidget);
    expect(find.text(money(200000)), findsOneWidget);
  });

  testWidgets(
    'Selected dream icon remains square and new icons are searchable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: kopiTheme(),
          home: const Scaffold(body: GoalIconPicker(selected: 'watch')),
        ),
      );
      final watch = find.byWidgetPredicate(
        (w) => w is GoalSymbol && w.id == 'watch',
      );
      expect(tester.getSize(watch), const Size(40, 40));
      expect(tester.widget<GoalSymbol>(watch).selected, true);
      expect(
        tester.getSize(find.byKey(const ValueKey('choose-icon-watch'))).height,
        lessThan(90),
      );
      await tester.enterText(find.byType(TextField), 'стоматолог');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('choose-icon-dentist')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Calendar summary gives access to every payment on a busy day', (
    tester,
  ) async {
    final store = await fixture();
    final day = DateTime(2026, 11, 2);
    store.payments = List.generate(
      4,
      (i) => PlannedPayment(
        id: '$i',
        title: 'Платёж $i',
        amount: 10000,
        start: day,
        monthly: true,
      ),
    );
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: kopiTheme(),
        home: Scaffold(
          body: CalendarScreen(
            store: store,
            selected: day,
            today: day,
            onSelect: (_) {},
            onMonth: (_) {},
            onPayment: (p) => opened = p.payment.id,
            onAdd: () {},
            onSubscriptions: () {},
          ),
        ),
      ),
    );
    expect(find.text('Платёж 3'), findsNothing);
    await tester.ensureVisible(find.text('Все платежи дня (4) →'));
    await tester.tap(find.text('Все платежи дня (4) →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Платёж 3'));
    await tester.pumpAndSettle();
    expect(opened, '3');
    expect(find.text('Платёж 3'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Capture compact phone screens at 360 by 800 with safe areas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
    for (final (family, asset) in [
      ('Inter', 'assets/fonts/Inter.ttf'),
      ('PTSerif', 'assets/fonts/PTSerif-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
    final store = await fixture(sample: true);
    final today = DateTime(2026, 11, 2);
    await store.saveBudget(
      today,
      const Budget(
        income: 6000000,
        limit: 99999999999,
        reserve: 0,
        dreams: 1000000,
        simplePlan: true,
      ),
    );
    store.entries = [
      for (var i = 0; i < 4; i++)
        Entry(
          id: '$i',
          title: i == 0 ? 'Зарплата' : 'Покупка $i',
          category: i == 0 ? 'Зарплата' : 'Кафе',
          amount: i == 0 ? 6000000 : 25000,
          date: today,
          isIncome: i == 0,
        ),
    ];
    store.payments = List.generate(
      4,
      (i) => PlannedPayment(
        id: '$i',
        title: 'Подписка $i',
        amount: 80000,
        start: today,
        monthly: true,
      ),
    );
    for (final page in [
      null,
      FinancePage.calendar,
      FinancePage.analytics,
      FinancePage.achievements,
      FinancePage.profile,
    ]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: page == null
              ? KopiApp(store: store, clock: () => today)
              : MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: kopiTheme(),
                  home: FinanceFlow(
                    store: store,
                    initial: page,
                    initialDate: today,
                    clock: () => today,
                    onBudget: () {},
                    onLogout: () async {},
                  ),
                ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$page');
      final scrolls = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .map((s) => s.position.maxScrollExtent)
          .toList();
      expect(
        scrolls,
        everyElement(0.0),
        reason: '${page?.name ?? 'diary'} should fit at the default font size',
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'previews/nothing-${page?.name ?? 'diary'}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
  });
}
