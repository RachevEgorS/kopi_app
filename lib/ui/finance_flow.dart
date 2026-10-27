import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/diary.dart';
import 'design.dart';
import 'education.dart';
import 'screens.dart' show ScreenTop, BudgetScreen;
import '../data/progress.dart';
import 'progress_pages.dart';
import 'finance_pages.dart';
import 'finance_widgets.dart';

enum FinancePage {
  history,
  operation,
  calendar,
  payment,
  subscriptions,
  analytics,
  goals,
  forecast,
  achievements,
  profile,
}

class FinanceFlow extends StatefulWidget {
  final DiaryStore store;
  final FinancePage initial;
  final DateTime Function() clock;
  final DateTime? initialDate;
  final String? goalId;
  final Entry? entry;
  final PaymentOccurrence? occurrence;
  final VoidCallback onBudget;
  final Future<void> Function() onLogout;
  const FinanceFlow({
    super.key,
    required this.store,
    required this.initial,
    required this.clock,
    this.initialDate,
    this.entry,
    this.goalId,
    this.occurrence,
    required this.onBudget,
    required this.onLogout,
  });
  @override
  State<FinanceFlow> createState() => _FinanceFlowState();
}

class _Page {
  final FinancePage page;
  final String? goalId;
  final Entry? entry;
  final PaymentOccurrence? occurrence;
  final bool monthly;
  const _Page(
    this.page, {
    this.entry,
    this.goalId,
    this.occurrence,
    this.monthly = false,
  });
}

class _FinanceFlowState extends State<FinanceFlow> with WidgetsBindingObserver {
  late _Page current;
  final List<_Page> stack = [];
  final search = TextEditingController();
  int filter = 0;
  late DateTime selected;
  Timer? timer;
  DateTime get today => dateOnly(widget.clock());
  @override
  void initState() {
    super.initState();
    current = _Page(
      widget.initial,
      entry: widget.entry,
      goalId: widget.goalId,
      occurrence: widget.occurrence,
    );
    selected = widget.initialDate ?? today;
    widget.store.addListener(refresh);
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    widget.store.removeListener(refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  void open(_Page page) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      stack.add(current);
      current = page;
    });
  }

  void back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (stack.isEmpty) {
      Navigator.pop(context);
    } else {
      setState(() => current = stack.removeLast());
    }
  }

  void calendar() {
    if (current.page == FinancePage.calendar) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      stack.clear();
      current = const _Page(FinancePage.calendar);
    });
  }

  void add() {
    if (current.page != FinancePage.operation) {
      open(const _Page(FinancePage.operation));
    }
  }

  void editPayment(PaymentOccurrence occurrence) =>
      open(_Page(FinancePage.payment, occurrence: occurrence));
  void help() {
    final (title, message) = switch (current.page) {
      FinancePage.history => (
        'Все записи рядом',
        'Ищи по названию, категории или дате. Фильтры отделяют доходы от расходов. Нажми на запись, чтобы изменить её или удалить.',
      ),
      FinancePage.operation => (
        'Одна запись — один шаг',
        'Выбери расход или доход, укажи сумму и дату. Заметку можно оставить пустой. Доходы здесь — новые поступления сверх доступной суммы, которую ты указал в месячном плане.',
      ),
      FinancePage.calendar => (
        'Дни без неожиданностей',
        'Точки отмечают дни с платежами. Выбери день, чтобы увидеть записи. Ежемесячные платежи повторяются автоматически; если в месяце нет нужного числа, используем его последний день. Отметить оплату можно в день платежа или позже.',
      ),
      FinancePage.payment => (
        'Важное под рукой',
        'Платёж появится в календаре. Ежемесячный — ещё и в регулярных платежах. Настройка напоминания сохраняется, но уведомления пока не отправляются. Приложение не выполняет оплату и не отменяет подписку. Отметка оплаты создаёт расход и освобождает резерв.',
      ),
      FinancePage.subscriptions => (
        'Что повторяется каждый месяц',
        'Здесь все ежемесячные планы и их общая сумма. Нажми на платёж, чтобы изменить его. Удаление записи в Копи не отключает подписку в сервисе.',
      ),
      _ => (
        'Копи рядом',
        'Все данные сохраняются на этом устройстве. В мечтах можно задать сумму и темп накоплений, в обзоре — посмотреть расходы, а в достижениях — отметить проверку учёта.',
      ),
    };
    showKopiMessage(context, title, message);
  }

  void profile() {
    if (current.page != FinancePage.profile) {
      open(const _Page(FinancePage.profile));
    }
  }

  void tab(FinancePage page) {
    if (current.page == page) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      stack.clear();
      current = _Page(page);
    });
  }

  Future<void> editGoal([SavingGoal? goal]) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: KopiColors.background,
      builder: (_) =>
          GoalEditor(store: widget.store, today: today, initial: goal),
    );
    if (!mounted || result == null) return;
    if (result == 'deleted') {
      if (current.page == FinancePage.forecast) back();
    } else if (goal == null) {
      open(_Page(FinancePage.forecast, goalId: result));
    }
  }

  Future<void> budget() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (ctx) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: EducationHost(
                store: widget.store,
                topic: 'budget',
                child: BudgetScreen(
                  month: selected,
                  initial: widget.store.budgets[monthKey(selected)],
                  onBack: () => Navigator.pop(ctx),
                  onSave: (value) async {
                    await widget.store.saveBudget(selected, value);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final goal = widget.store.goals
        .where((g) => g.id == current.goalId)
        .firstOrNull;
    final content = switch (current.page) {
      FinancePage.history => HistoryScreen(
        store: widget.store,
        search: search,
        filter: filter,
        onFilter: (v) => setState(() => filter = v),
        onSearch: refresh,
        onEdit: (entry) => open(_Page(FinancePage.operation, entry: entry)),
        onAdd: add,
      ),
      FinancePage.operation => OperationScreen(
        key: ValueKey(current.entry?.id ?? 'new-operation'),
        store: widget.store,
        today: today,
        initial: current.entry,
        onComplete: back,
      ),
      FinancePage.calendar => CalendarScreen(
        store: widget.store,
        selected: selected,
        today: today,
        onSelect: (date) => setState(() => selected = date),
        onMonth: (delta) => setState(() {
          final month = DateTime(selected.year, selected.month + delta);
          selected = DateTime(
            month.year,
            month.month,
            min(selected.day, DateTime(month.year, month.month + 1, 0).day),
          );
        }),
        onPayment: editPayment,
        onAdd: () => open(const _Page(FinancePage.payment)),
        onSubscriptions: () => open(const _Page(FinancePage.subscriptions)),
      ),
      FinancePage.payment => PaymentScreen(
        key: ValueKey(
          current.occurrence?.key ?? 'new-payment-${current.monthly}',
        ),
        store: widget.store,
        date: selected,
        today: today,
        initial: current.occurrence?.payment,
        occurrence: current.occurrence,
        monthly: current.monthly,
        onComplete: back,
      ),
      FinancePage.subscriptions => SubscriptionsScreen(
        store: widget.store,
        today: today,
        onEdit: editPayment,
        onAdd: () => open(const _Page(FinancePage.payment, monthly: true)),
      ),
      FinancePage.analytics => AnalyticsScreen(
        store: widget.store,
        month: selected,
        today: today,
        onMonth: (delta) => setState(
          () => selected = DateTime(selected.year, selected.month + delta),
        ),
        onSubscriptions: () => open(const _Page(FinancePage.subscriptions)),
        onAdd: add,
      ),
      FinancePage.goals => GoalsScreen(
        store: widget.store,
        today: today,
        onGoal: (g) => open(_Page(FinancePage.forecast, goalId: g.id)),
        onAdd: () => editGoal(),
        onAchievements: () => open(const _Page(FinancePage.achievements)),
      ),
      FinancePage.forecast =>
        goal == null
            ? Center(
                child: TextButton(
                  onPressed: () => tab(FinancePage.goals),
                  child: const Text('Выбрать мечту'),
                ),
              )
            : ForecastScreen(
                key: ValueKey(goal.id),
                store: widget.store,
                goal: goal,
                today: today,
                onEdit: () => editGoal(goal),
              ),
      FinancePage.achievements => AchievementsScreen(
        store: widget.store,
        today: today,
      ),
      FinancePage.profile => ProfileScreen(
        store: widget.store,
        onBudget: budget,
        onSubscriptions: () => open(const _Page(FinancePage.subscriptions)),
        onAchievements: () => open(const _Page(FinancePage.achievements)),
        onHelp: () => showEducation(context, store: widget.store),
        onLogout: () async {
          await widget.onLogout();
          if (context.mounted) Navigator.pop(context);
        },
      ),
    };
    return PopScope(
      canPop: stack.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: EducationHost(
        store: widget.store,
        topic: current.page.name,
        child: Scaffold(
          backgroundColor: KopiColors.background,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    ScreenTop(
                      brand: [
                        FinancePage.calendar,
                        FinancePage.goals,
                        FinancePage.analytics,
                      ].contains(current.page),
                      onBack: back,
                      onHelp: help,
                      onProfile: profile,
                    ),
                    Expanded(child: content),
                    KopiNavigation(
                      selected:
                          [
                            FinancePage.calendar,
                            FinancePage.payment,
                            FinancePage.subscriptions,
                          ].contains(current.page)
                          ? 'calendar'
                          : current.page == FinancePage.analytics
                          ? 'overview'
                          : [
                              FinancePage.goals,
                              FinancePage.forecast,
                              FinancePage.achievements,
                            ].contains(current.page)
                          ? 'dreams'
                          : 'diary',
                      onDiary: () => Navigator.pop(context),
                      onCalendar: calendar,
                      onAdd: add,
                      onDreams: () => tab(FinancePage.goals),
                      onOverview: () => tab(FinancePage.analytics),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
