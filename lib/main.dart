import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/diary.dart';
import 'ui/design.dart';
import 'ui/education.dart';
import 'ui/screens.dart';
import 'ui/finance_flow.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: KopiColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final store = DiaryStore(await SharedPreferences.getInstance())..load();
  runApp(KopiApp(store: store));
}

class KopiApp extends StatelessWidget {
  final DiaryStore store;
  final DateTime Function()? clock;
  const KopiApp({super.key, required this.store, this.clock});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Копи · твой финансовый дневник',
    debugShowCheckedModeBanner: false,
    theme: kopiTheme(),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: AppFlow(store: store, clock: clock ?? DateTime.now),
  );
}

enum Screen { welcome, login, register, budget, diary }

class AppFlow extends StatefulWidget {
  final DiaryStore store;
  final DateTime Function() clock;
  const AppFlow({super.key, required this.store, required this.clock});
  @override
  State<AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<AppFlow> with WidgetsBindingObserver {
  late Screen screen;
  late DateTime selectedMonth;
  late DateTime today;
  Timer? timer;
  bool editingBudget = false;
  DiaryStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    today = widget.clock();
    selectedMonth = DateTime(today.year, today.month);
    screen = store.signedIn
        ? (store.setupDone ? Screen.diary : Screen.budget)
        : (store.introduced ? Screen.login : Screen.welcome);
    WidgetsBinding.instance.addObserver(this);
    store.addListener(refresh);
    timer = Timer.periodic(const Duration(seconds: 30), (_) => checkDate());
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  void checkDate() {
    final now = widget.clock();
    if (today.year == now.year &&
        today.month == now.month &&
        today.day == now.day) {
      return;
    }
    setState(() {
      if (monthKey(selectedMonth) == monthKey(today)) {
        selectedMonth = DateTime(now.year, now.month);
      }
      today = now;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkDate();
  }

  @override
  void dispose() {
    timer?.cancel();
    store.removeListener(refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void go(Screen next) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => screen = next);
  }

  void openBudget() {
    editingBudget = true;
    go(Screen.budget);
  }

  Future<void> openFinance(
    FinancePage page, {
    Entry? entry,
    PaymentOccurrence? occurrence,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FinanceFlow(
          store: store,
          initial: page,
          clock: widget.clock,
          initialDate:
              occurrence?.date ??
              (monthKey(selectedMonth) == monthKey(today)
                  ? dateOnly(today)
                  : selectedMonth),
          entry: entry,
          occurrence: occurrence,
          onBudget: openBudget,
          onLogout: () async {
            await store.logout();
            if (mounted) go(Screen.login);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (screen) {
      Screen.welcome => WelcomeScreen(
        onRegister: () => go(Screen.register),
        onLogin: () => go(Screen.login),
      ),
      Screen.login || Screen.register => AuthScreen(
        key: ValueKey(screen),
        register: screen == Screen.register,
        store: store,
        onBack: () => go(Screen.welcome),
        onSwitch: () =>
            go(screen == Screen.login ? Screen.register : Screen.login),
        onComplete: () {
          editingBudget = false;
          selectedMonth = DateTime(today.year, today.month);
          go(store.setupDone ? Screen.diary : Screen.budget);
        },
      ),
      Screen.budget => BudgetScreen(
        key: ValueKey('budget-${monthKey(selectedMonth)}'),
        month: selectedMonth,
        initial: store.budgets[monthKey(selectedMonth)],
        onBack: () => go(editingBudget ? Screen.diary : Screen.login),
        onSave: (budget) async {
          await store.saveBudget(selectedMonth, budget);
          if (mounted) go(Screen.diary);
        },
      ),
      Screen.diary => DiaryScreen(
        store: store,
        month: selectedMonth,
        today: today,
        onMonth: (offset) => setState(
          () => selectedMonth = DateTime(
            selectedMonth.year,
            selectedMonth.month + offset,
          ),
        ),
        onBudget: openBudget,
        onProfile: () => openFinance(FinancePage.profile),
        onDreams: () => openFinance(FinancePage.goals),
        onOverview: () => openFinance(FinancePage.analytics),
        onHistory: () => openFinance(FinancePage.history),
        onOperation: () => openFinance(FinancePage.operation),
        onCalendar: () => openFinance(FinancePage.calendar),
        onSubscriptions: () => openFinance(FinancePage.subscriptions),
        onEntry: (entry) => openFinance(FinancePage.operation, entry: entry),
        onPayment: (occurrence) =>
            openFinance(FinancePage.payment, occurrence: occurrence),
        onLogout: () async {
          await store.logout();
          if (mounted) go(Screen.login);
        },
      ),
    };
    return PopScope(
      canPop:
          screen == Screen.diary ||
          screen == Screen.welcome ||
          (screen == Screen.login && store.introduced),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (screen == Screen.budget) {
          go(editingBudget ? Screen.diary : Screen.login);
        } else {
          go(Screen.welcome);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: EducationHost(
                  key: ValueKey(screen),
                  store: store,
                  topic: screen.name,
                  child: page,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
