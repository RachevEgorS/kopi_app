import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/diary.dart';
import 'design.dart';
import 'screens.dart' show ScreenTop;
import 'finance_pages.dart';
import 'finance_widgets.dart';

enum FinancePage { history, operation, calendar, payment, subscriptions }

class FinanceFlow extends StatefulWidget {
  final DiaryStore store;
  final FinancePage initial;
  final DateTime Function() clock;
  final DateTime? initialDate;
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
    this.occurrence,
    required this.onBudget,
    required this.onLogout,
  });
  @override
  State<FinanceFlow> createState() => _FinanceFlowState();
}

class _Page {
  final FinancePage page;
  final Entry? entry;
  final PaymentOccurrence? occurrence;
  final bool monthly;
  const _Page(this.page, {this.entry, this.occurrence, this.monthly = false});
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
    };
    showKopiMessage(context, title, message);
  }

  Future<void> profile() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: KopiColors.background,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Heading(widget.store.name),
            const SizedBox(height: 8),
            Text(
              widget.store.email,
              style: const TextStyle(color: KopiColors.muted),
            ),
            const SizedBox(height: 12),
            const Text(
              'Деморежим · данные на этом устройстве',
              style: TextStyle(fontSize: 11, color: KopiColors.berry),
            ),
            const SizedBox(height: 22),
            KopiButton(
              'Мой бюджет',
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
                widget.onBudget();
              },
            ),
            const SizedBox(height: 12),
            KopiButton(
              'Регулярные платежи',
              secondary: true,
              onPressed: () {
                Navigator.pop(ctx);
                if (current.page != FinancePage.subscriptions) {
                  open(const _Page(FinancePage.subscriptions));
                }
              },
            ),
            const SizedBox(height: 12),
            KopiButton(
              'История записей',
              secondary: true,
              onPressed: () {
                Navigator.pop(ctx);
                if (current.page != FinancePage.history) {
                  open(const _Page(FinancePage.history));
                }
              },
            ),
            const SizedBox(height: 12),
            KopiButton(
              'Выйти из дневника',
              secondary: true,
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await widget.onLogout();
                  if (mounted) Navigator.pop(context);
                } catch (_) {
                  if (mounted) {
                    showKopiMessage(
                      context,
                      'Не получилось выйти',
                      'Попробуй ещё раз. Записи сохранены.',
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
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
    };
    return PopScope(
      canPop: stack.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: Scaffold(
        backgroundColor: KopiColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  ScreenTop(
                    brand: current.page == FinancePage.calendar,
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
                        : 'diary',
                    onDiary: () => Navigator.pop(context),
                    onCalendar: calendar,
                    onAdd: add,
                    onDreams: () => showKopiMessage(
                      context,
                      'Мечты',
                      'Экран целей добавим следующим этапом.',
                    ),
                    onOverview: () => showKopiMessage(
                      context,
                      'Обзор',
                      'Экран аналитики добавим следующим этапом.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
