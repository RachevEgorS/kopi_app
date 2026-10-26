import 'dart:math';
import 'package:flutter/material.dart';
import '../data/diary.dart';
import 'design.dart';
import 'finance_widgets.dart';

const _pad = EdgeInsets.symmetric(horizontal: 28);

class ScreenTop extends StatelessWidget {
  final VoidCallback? onBack, onProfile;
  final VoidCallback onHelp;
  final bool brand;
  const ScreenTop({
    super.key,
    this.onBack,
    this.onProfile,
    required this.onHelp,
    this.brand = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
    child: Row(
      children: [
        if (brand)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: MediaQuery.withNoTextScaling(child: const Brand()),
          )
        else
          IconButton(
            tooltip: 'Назад',
            onPressed: onBack,
            icon: const LineIcon(Glyph.back, size: 20, color: KopiColors.ink),
          ),
        const Spacer(),
        HelpButton(onPressed: onHelp),
        if (onProfile != null)
          IconButton(
            tooltip: 'Профиль',
            onPressed: onProfile,
            icon: const LineIcon(Glyph.person, size: 22, color: KopiColors.ink),
          ),
      ],
    ),
  );
}

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onRegister, onLogin;
  const WelcomeScreen({
    super.key,
    required this.onRegister,
    required this.onLogin,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: bounds.maxHeight),
        child: IntrinsicHeight(
          child: Column(
            children: [
              ScreenTop(
                brand: true,
                onHelp: () => showKopiMessage(
                  context,
                  'Привет, это Копи',
                  'Твой спокойный финансовый дневник. Планируй месяц, замечай расходы и оставляй место для своих мечт. Начни с регистрации или войди в дневник.',
                ),
              ),
              SizedBox(height: (bounds.maxHeight * .1).clamp(28.0, 90.0)),
              const Flower(size: 82),
              const SizedBox(height: 34),
              const Heading(
                'Деньги\nв своём ритме',
                size: 38,
                align: TextAlign.center,
              ),
              const SizedBox(height: 26),
              const Text(
                'Немного внимания сегодня',
                style: TextStyle(fontSize: 12, color: KopiColors.muted),
              ),
              const SizedBox(height: 13),
              const Text(
                'Больше спокойствия завтра',
                style: TextStyle(fontSize: 12, color: KopiColors.muted),
              ),
              const SizedBox(height: 37),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Feature(Glyph.leaf, 'Мягкая привычка'),
                  SizedBox(width: 14),
                  _Feature(Glyph.flag, 'Свои мечты'),
                  SizedBox(width: 14),
                  _Feature(Glyph.calendar, 'Всё по плану'),
                ],
              ),
              const SizedBox(height: 40),
              Padding(
                padding: _pad,
                child: Column(
                  children: [
                    KopiButton('Начать свой дневник', onPressed: onRegister),
                    const SizedBox(height: 13),
                    KopiButton(
                      'У меня уже есть аккаунт',
                      onPressed: onLogin,
                      secondary: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              const Text(
                'Копи · твой финансовый дневник',
                style: TextStyle(fontSize: 12, color: KopiColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const Spacer(),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Feature extends StatelessWidget {
  final Glyph icon;
  final String label;
  const _Feature(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Flexible(
    child: Column(
      children: [
        LineIcon(icon, size: 20, color: const Color(0xFFAC91B7)),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, color: KopiColors.muted),
        ),
      ],
    ),
  );
}

class AuthScreen extends StatefulWidget {
  final bool register;
  final DiaryStore store;
  final VoidCallback onBack, onSwitch, onComplete;
  const AuthScreen({
    super.key,
    required this.register,
    required this.store,
    required this.onBack,
    required this.onSwitch,
    required this.onComplete,
  });
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool busy = false, confirming = false;
  String? error;
  @override
  void initState() {
    super.initState();
    if (!widget.register) email.text = widget.store.email;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || confirming || !form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      confirming = true;
      error = null;
    });
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KopiColors.background,
        title: const Heading('Попробуем дневник?'),
        content: const Text(
          'Сейчас доступен деморежим на этом устройстве. Аккаунт пока не создаётся, пароль не проверяется и не сохраняется. Используй вымышленную почту. Настоящий вход подключим позже.',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Назад'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Продолжить в деморежиме'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => confirming = false);
    if (proceed != true) {
      setState(() => busy = false);
      return;
    }
    setState(() => busy = true);
    try {
      await widget.store.enterDemo(
        widget.register ? name.text : widget.store.name,
        email.text,
      );
      password.clear();
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не получилось сохранить данные. Попробуй ещё раз.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTop(
            onBack: widget.onBack,
            onHelp: () => showKopiMessage(
              context,
              widget.register ? 'Всего три поля' : 'С возвращением',
              'Это первая версия интерфейса. Для знакомства с дневником введи вымышленные данные. Сетевой вход и восстановление пароля появятся после подключения аккаунтов.',
            ),
          ),
          Padding(
            padding: _pad,
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Heading(
                    widget.register ? 'Познакомимся?' : 'Рады видеть снова',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.register
                        ? 'Три поля — и у тебя свой денежный дневник.'
                        : 'Твой дневник ждёт тебя.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: KopiColors.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (widget.register)
                    KopiField(
                      label: 'Как тебя зовут',
                      hint: 'Твоё имя',
                      controller: name,
                      autofillHints: const [AutofillHints.givenName],
                      validator: (v) => (v ?? '').trim().length < 2
                          ? 'Введи имя, хотя бы 2 символа'
                          : null,
                    ),
                  KopiField(
                    label: 'Почта',
                    hint: 'name@example.ru',
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) =>
                        RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch((v ?? '').trim())
                        ? null
                        : 'Проверь адрес почты',
                  ),
                  KopiField(
                    label: 'Пароль',
                    hint: '••••••••',
                    controller: password,
                    password: true,
                    action: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    validator: (v) => (v ?? '').length < 8
                        ? 'Нужно не менее 8 символов'
                        : null,
                  ),
                  if (!widget.register)
                    Transform.translate(
                      offset: const Offset(0, -16),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () => showKopiMessage(
                          context,
                          'Восстановление доступа',
                          'Восстановление по почте будет доступно после подключения аккаунтов. Письмо сейчас не отправляется. В деморежиме можно продолжить с вымышленной почтой и любым паролем от 8 символов.',
                        ),
                        child: const Text(
                          'Не помню пароль',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  SizedBox(height: widget.register ? 58 : 39),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: KopiColors.error),
                      ),
                    ),
                  KopiButton(
                    widget.register ? 'Создать дневник' : 'Войти в дневник',
                    onPressed: submit,
                    busy: busy,
                  ),
                  const SizedBox(height: 13),
                  KopiButton(
                    widget.register
                        ? 'Уже есть аккаунт? Войти'
                        : 'Создать аккаунт',
                    onPressed: busy ? null : widget.onSwitch,
                    secondary: true,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class BudgetScreen extends StatefulWidget {
  final DateTime month;
  final Budget? initial;
  final VoidCallback onBack;
  final Future<void> Function(Budget?) onSave;
  const BudgetScreen({
    super.key,
    required this.month,
    this.initial,
    required this.onBack,
    required this.onSave,
  });
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final form = GlobalKey<FormState>();
  late final List<TextEditingController> fields;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    fields = [b?.income, b?.limit, b?.reserve, b?.dreams]
        .map(
          (v) => TextEditingController(
            text: v == null ? '' : money(v, currency: false),
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> save({bool skip = false}) async {
    if (busy || (!skip && !form.currentState!.validate())) return;
    setState(() {
      busy = true;
      error = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    final values = fields.map((f) => parseMoney(f.text) ?? 0).toList();
    try {
      await widget.onSave(
        skip
            ? null
            : Budget(
                income: values[0],
                limit: values[1],
                reserve: values[2],
                dreams: values[3],
              ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'План не сохранился. Попробуй ещё раз.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenTop(
          onBack: widget.onBack,
          onHelp: () => showKopiMessage(
            context,
            'Оставим место для важного',
            'В доход укажи уже доступные деньги на месяц — ожидаемую зарплату пока не учитывай. Лимит — максимум всех расходов. Резерв платежей и деньги на мечты вычитаются из суммы для ежедневных трат. Ненужный резерв можно оставить пустым. План можно изменить в профиле.',
          ),
        ),
        Padding(
          padding: _pad,
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Heading('План на ${monthNames[widget.month.month - 1]}'),
                const SizedBox(height: 8),
                const Text(
                  'Оставим место и для нужного, и для приятного.',
                  style: TextStyle(
                    fontSize: 12,
                    color: KopiColors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                for (var i = 0; i < 4; i++)
                  KopiField(
                    label: [
                      'Доход за месяц, ₽',
                      'Лимит всех расходов, ₽',
                      'Резерв будущих платежей, ₽',
                      'Отложить на мечты, ₽',
                    ][i],
                    controller: fields[i],
                    hint: ['60 000', '50 000', '0', '0'][i],
                    moneyInput: true,
                    action: i == 3
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onSubmitted: i == 3 ? (_) => save() : null,
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty && i >= 2) return null;
                      return parseMoney(v ?? '') == null
                          ? 'Введи сумму от 0, не более двух знаков после запятой'
                          : null;
                    },
                  ),
                const SizedBox(height: 58),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: KopiColors.error),
                    ),
                  ),
                KopiButton(
                  'Сохранить мой план',
                  onPressed: () => save(),
                  busy: busy,
                ),
                const SizedBox(height: 12),
                KopiButton(
                  'Добавить позже',
                  onPressed: busy ? null : () => save(skip: true),
                  secondary: true,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class DiaryScreen extends StatefulWidget {
  final DiaryStore store;
  final DateTime month, today;
  final ValueChanged<int> onMonth;
  final VoidCallback onBudget;
  final Future<void> Function() onLogout;
  final VoidCallback? onHistory, onOperation, onCalendar, onSubscriptions;
  final ValueChanged<Entry>? onEntry;
  final ValueChanged<PaymentOccurrence>? onPayment;
  const DiaryScreen({
    super.key,
    required this.store,
    required this.month,
    required this.today,
    required this.onMonth,
    required this.onBudget,
    required this.onLogout,
    this.onHistory,
    this.onOperation,
    this.onCalendar,
    this.onSubscriptions,
    this.onEntry,
    this.onPayment,
  });
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  bool examples = false;
  List<Entry> get previewEntries => [
    Entry(
      id: 'demo-coffee',
      title: 'Кофе с собой',
      category: 'Кафе',
      amount: 45000,
      date: widget.today,
    ),
    Entry(
      id: 'demo-food',
      title: 'Продукты на неделю',
      category: 'Продукты',
      amount: 218000,
      date: widget.today,
    ),
    Entry(
      id: 'demo-bus',
      title: 'Поездка домой',
      category: 'Транспорт',
      amount: 32000,
      date: widget.today,
    ),
  ];
  void later(String title) => showKopiMessage(
    context,
    title,
    'Этот раздел появится на следующем этапе. Сейчас можно настроить месячный бюджет, добавить расход и посмотреть дневной ориентир.',
  );

  Future<void> profile() async {
    await showModalBottomSheet<void>(
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
              const SizedBox(height: 16),
              const Text(
                'Деморежим · данные на этом устройстве',
                style: TextStyle(fontSize: 11, color: KopiColors.berry),
              ),
              const SizedBox(height: 20),
              KopiButton(
                'Мой бюджет',
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onBudget();
                },
              ),
              const SizedBox(height: 12),
              if (widget.onSubscriptions != null) ...[
                KopiButton(
                  'Регулярные платежи',
                  secondary: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onSubscriptions!();
                  },
                ),
                const SizedBox(height: 12),
              ],
              KopiButton(
                examples
                    ? 'Вернуться к моим записям'
                    : 'Посмотреть пример дневника',
                secondary: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => examples = !examples);
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
                  } catch (_) {
                    if (mounted) {
                      showKopiMessage(
                        context,
                        'Не получилось выйти',
                        'Попробуй ещё раз. Твои записи сохранены.',
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
  }

  Future<void> history(List<Entry> entries) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: KopiColors.background,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Heading('Все записи'),
              const SizedBox(height: 8),
              Text(
                monthTitle(widget.month),
                style: const TextStyle(color: KopiColors.muted),
              ),
              const SizedBox(height: 20),
              if (entries.isEmpty)
                const _Empty(
                  'Здесь будет история твоих расходов.\nНачни с одной небольшой записи.',
                ),
              ...entries.map((entry) => ExpenseRow(entry: entry)),
              const SizedBox(height: 20),
              KopiButton('Готово', onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> addExpense() async {
    if (examples) {
      showKopiMessage(
        context,
        'Это пример дневника',
        'Чтобы добавить свой расход, открой профиль и вернись к своим записям. Примеры не сохраняются в твоём дневнике.',
      );
      return;
    }
    if (widget.onOperation != null) {
      widget.onOperation!();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: KopiColors.background,
      builder: (ctx) => ExpenseSheet(store: widget.store, today: widget.today),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budget = examples
        ? const Budget(
            income: 6000000,
            limit: 5000000,
            reserve: 1100000,
            dreams: 500000,
          )
        : widget.store.budgets[monthKey(widget.month)];
    final entries = examples
        ? previewEntries
        : widget.store
              .entriesFor(widget.month)
              .where((e) => !e.isIncome)
              .toList();
    final income = examples ? 6000000 : widget.store.incomeFor(widget.month);
    final reserve = examples ? 1100000 : widget.store.reserveFor(widget.month);
    final upcoming = widget.store
        .paymentsFor(widget.month)
        .where((p) => !widget.store.isPaid(p))
        .toList();
    final spent = examples
        ? 1820000
        : entries.fold<int>(0, (sum, e) => sum + e.amount);
    final isCurrent = monthKey(widget.month) == monthKey(widget.today);
    final isPast = widget.month.isBefore(
      DateTime(widget.today.year, widget.today.month),
    );
    final days =
        DateTime(widget.month.year, widget.month.month + 1, 0).day -
        (isCurrent ? widget.today.day - 1 : 0);
    final allowance = budget == null
        ? null
        : DailyAllowance.calculate(
            limit: budget.limit,
            spent: spent,
            available: income - spent,
            reserve: reserve,
            dreams: budget.dreams,
            days: days,
          );
    final progress = budget == null || budget.limit == 0
        ? (spent > 0 ? 1.0 : 0.0)
        : (spent / budget.limit).clamp(0.0, 1.0);
    return Column(
      children: [
        ScreenTop(
          brand: true,
          onProfile: profile,
          onHelp: () => showKopiMessage(
            context,
            'Сколько можно сегодня',
            'Берём меньшую сумму: остаток лимита или доступные деньги. Вычитаем резерв неоплаченных платежей и деньги на мечты. Делим на оставшиеся дни месяца, включая сегодня.\n\nОжидаемую зарплату не учитываем. Если денег не хватает, показываем 0 ₽ и дефицит.',
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: _pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Предыдущий месяц',
                      onPressed: () => widget.onMonth(-1),
                      icon: const LineIcon(Glyph.back, size: 13),
                    ),
                    Expanded(
                      child: Text(
                        monthTitle(widget.month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Следующий месяц',
                      onPressed: () => widget.onMonth(1),
                      icon: const LineIcon(Glyph.next, size: 13),
                    ),
                  ],
                ),
                if (examples)
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Center(
                      child: Text(
                        'Пример · вымышленные записи',
                        style: TextStyle(fontSize: 11, color: KopiColors.berry),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    isCurrent
                        ? 'Можно потратить сегодня'
                        : isPast
                        ? 'Свободный остаток месяца'
                        : 'Ориентир на день',
                    style: const TextStyle(
                      fontSize: 12,
                      color: KopiColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Heading(
                    budget == null
                        ? '— ₽'
                        : money(
                            isPast
                                ? max(0, allowance!.free)
                                : allowance!.amount,
                          ),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 9),
                Center(
                  child: TextButton(
                    onPressed: budget == null
                        ? widget.onBudget
                        : () => showKopiMessage(
                            context,
                            'Твой дневной ориентир',
                            'Лимит: ${money(budget.limit)}\nПотрачено: ${money(spent)}\nДоступный остаток: ${money(income - spent)}\nРезерв платежей: ${money(reserve)}\nНа мечты: ${money(budget.dreams)}\n${isPast ? 'Свободный остаток' : 'Осталось дней: $days\nСвободная сумма'}: ${money(allowance!.free)}\n\nРезерв — большая из двух сумм: оставшийся резерв плана или неоплаченные платежи месяца. Так запланированное не вычитается дважды.\n\nОриентир помогает планировать, а решение всегда за тобой.',
                          ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Text(
                          budget == null
                              ? 'Добавить план на месяц →'
                              : 'Платежи и накопления уже учтены',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: KopiColors.muted,
                          ),
                        ),
                        if (budget != null)
                          const Icon(
                            Icons.info_outline,
                            size: 11,
                            color: KopiColors.muted,
                          ),
                      ],
                    ),
                  ),
                ),
                if (allowance != null && allowance.free < 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Center(
                      child: Text(
                        'Не хватает ${money(-allowance.free)} · можно изменить план',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: KopiColors.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 22),
                Row(
                  children: [
                    _Metric('Доход за месяц', money(income)),
                    _Metric('Потрачено', money(spent)),
                  ],
                ),
                const SizedBox(height: 23),
                Semantics(
                  label:
                      'Израсходовано ${(progress * 100).round()} процентов лимита',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF0EAE9),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFE8B5CC),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Расходы за месяц',
                      style: TextStyle(fontSize: 10, color: KopiColors.muted),
                    ),
                    Flexible(
                      child: Text(
                        budget == null
                            ? 'Лимит не задан'
                            : 'Лимит ${money(budget.limit)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: KopiColors.muted,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionTitle('Расходы', 'Все записи →', () {
                  if (widget.onHistory != null && !examples) {
                    widget.onHistory!();
                  } else {
                    history(entries);
                  }
                }),
                if (entries.isEmpty)
                  const _Empty(
                    'Пока без записей\nНажми «+», чтобы добавить первый расход.',
                  ),
                ...entries
                    .take(3)
                    .map(
                      (entry) => InkWell(
                        onTap: widget.onEntry == null || examples
                            ? null
                            : () => widget.onEntry!(entry),
                        child: ExpenseRow(entry: entry),
                      ),
                    ),
                const SizedBox(height: 13),
                _SectionTitle(
                  'Скоро',
                  'Календарь →',
                  widget.onCalendar ?? () => later('Календарь'),
                ),
                if (examples)
                  ExpenseRow(
                    entry: Entry(
                      id: 'movie',
                      title: 'Кино и сериалы',
                      category: 'Подписка · завтра',
                      amount: 149000,
                      date: widget.today,
                    ),
                    payment: true,
                  )
                else if (upcoming.isNotEmpty)
                  ...upcoming
                      .take(3)
                      .map(
                        (p) => FinanceRow(
                          title: p.payment.title,
                          subtitle:
                              '${dayLabel(p.date)} · ${p.date.isBefore(dateOnly(widget.today)) ? 'Ожидает оплаты' : 'Запланировано'}',
                          amount: money(p.payment.amount),
                          onTap: () => widget.onPayment?.call(p),
                        ),
                      )
                else
                  const _Empty(
                    'Здесь появятся ближайшие платежи.\nПока всё спокойно.',
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: KopiColors.background,
            border: Border(top: BorderSide(color: KopiColors.line, width: .7)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
            child: Row(
              children: [
                _NavItem(
                  'Дневник',
                  Glyph.home,
                  selected: true,
                  onTap: () {
                    if (!isCurrent) {
                      widget.onMonth(
                        (widget.today.year - widget.month.year) * 12 +
                            widget.today.month -
                            widget.month.month,
                      );
                    }
                  },
                ),
                _NavItem(
                  'Календарь',
                  Glyph.calendar,
                  onTap: widget.onCalendar ?? () => later('Календарь'),
                ),
                Expanded(
                  child: Center(
                    child: IconButton.filled(
                      tooltip: 'Добавить расход',
                      onPressed: addExpense,
                      style: IconButton.styleFrom(
                        backgroundColor: KopiColors.accent,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const LineIcon(Glyph.plus, size: 22),
                    ),
                  ),
                ),
                _NavItem('Мечты', Glyph.flag, onTap: () => later('Мечты')),
                _NavItem('Обзор', Glyph.overview, onTap: () => later('Обзор')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  const _Metric(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: KopiColors.muted),
        ),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 17)),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title, link;
  final VoidCallback onTap;
  const _SectionTitle(this.title, this.link, this.onTap);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(child: Heading(title, size: 23)),
      Flexible(
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.only(left: 12),
            minimumSize: const Size(48, 48),
          ),
          child: Text(
            link,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.right,
          ),
        ),
      ),
    ],
  );
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        height: 1.8,
        color: KopiColors.muted,
      ),
    ),
  );
}

class ExpenseRow extends StatelessWidget {
  final Entry entry;
  final bool payment;
  const ExpenseRow({super.key, required this.entry, this.payment = false});
  @override
  Widget build(BuildContext context) {
    final (icon, color) = payment
        ? (Glyph.movie, const Color(0xFFE3D8ED))
        : switch (entry.category) {
            'Кафе' => (Glyph.coffee, KopiColors.sand),
            'Продукты' => (Glyph.bag, KopiColors.sage),
            'Транспорт' => (Glyph.bus, KopiColors.lavender),
            _ => (Glyph.bag, KopiColors.soft),
          };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KopiColors.line, width: .6)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: LineIcon(icon, size: 23)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 5),
                Text(
                  entry.category,
                  style: const TextStyle(fontSize: 10, color: KopiColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${payment ? '' : '−'}${money(entry.amount)}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final Glyph icon;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem(
    this.label,
    this.icon, {
    this.selected = false,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LineIcon(
                  icon,
                  size: selected ? 26 : 21,
                  color: selected ? KopiColors.berry : const Color(0xFFAA9B9D),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: selected ? KopiColors.berry : KopiColors.muted,
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

class ExpenseSheet extends StatefulWidget {
  final DiaryStore store;
  final DateTime today;
  const ExpenseSheet({super.key, required this.store, required this.today});
  @override
  State<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<ExpenseSheet> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(), note = TextEditingController();
  String category = 'Кафе';
  late DateTime date = widget.today;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.store.addEntry(
        Entry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: note.text.trim().isEmpty ? category : note.text.trim(),
          category: category,
          amount: parseMoney(amount.text)!,
          date: date,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не получилось сохранить запись. Попробуй ещё раз.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        28,
        8,
        28,
        28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Heading('Небольшая запись'),
            const SizedBox(height: 24),
            KopiField(
              label: 'Сумма расхода, ₽',
              controller: amount,
              hint: '0',
              moneyInput: true,
              validator: (v) => (parseMoney(v ?? '') ?? 0) <= 0
                  ? 'Введи сумму больше нуля'
                  : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Категория',
                labelStyle: TextStyle(fontSize: 12, color: KopiColors.muted),
              ),
              items: [
                'Кафе',
                'Продукты',
                'Транспорт',
                'Покупки',
                'Другое',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
            const SizedBox(height: 24),
            KopiField(
              label: 'Заметка · необязательно',
              controller: note,
              hint: 'Например, кофе с собой',
              action: TextInputAction.done,
            ),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2020),
                  lastDate: widget.today,
                );
                if (picked != null && mounted) setState(() => date = picked);
              },
              child: Text(
                'Дата: ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
              ),
            ),
            const SizedBox(height: 20),
            if (error != null)
              Text(error!, style: const TextStyle(color: KopiColors.error)),
            KopiButton('Записать расход', onPressed: submit, busy: busy),
          ],
        ),
      ),
    ),
  );
}
