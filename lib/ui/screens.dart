import 'finance_pages.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/diary.dart';
import '../data/cloud_errors.dart';
import 'design.dart';
import 'education.dart';
import 'finance_widgets.dart';

const _pad = EdgeInsets.symmetric(horizontal: 20);

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
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
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
        HelpButton(onPressed: EducationHost.helpOf(context) ?? onHelp),
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
    if (widget.store.isCloud) {
      await submitCloud();
      return;
    }
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

  Future<void> submitCloud() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final ready = await widget.store.authenticate(
        email: email.text,
        password: password.text,
        name: widget.register ? name.text : null,
      );
      if (!mounted) return;
      password.clear();
      setState(() => busy = false);
      if (ready) {
        widget.onComplete();
        return;
      }
      await showKopiMessage(
        context,
        'Проверь почту',
        'Если адрес доступен для регистрации, на ${email.text.trim()} придёт письмо. Подтверди почту по ссылке и вернись в Копи, чтобы войти. Проверь также папку «Спам».',
      );
      if (mounted && widget.register) widget.onSwitch();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = cloudError(e);
        });
      }
    }
  }

  Future<void> forgotPassword() async {
    if (busy) return;
    if (!widget.store.isCloud) {
      await showKopiMessage(
        context,
        'Восстановление доступа',
        'В локальном примере восстановление не подключено.',
      );
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      setState(() => error = 'Сначала укажи свою почту в поле выше.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.resetPassword(email.text);
      if (!mounted) return;
      setState(() => busy = false);
      await showKopiMessage(
        context,
        'Письмо для восстановления',
        'Если аккаунт с этой почтой существует, придёт ссылка для смены пароля. Открой её на этом устройстве.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = cloudError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenTop(
            onBack: widget.onBack,
            onHelp: () => showKopiMessage(
              context,
              widget.register ? 'Всего три поля' : 'С возвращением',
              'Введи свою почту и пароль. После регистрации подтверди адрес по ссылке в письме. Если забыл пароль, укажи почту и нажми «Не помню пароль».',
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
                          : (v ?? '').trim().length > 80
                          ? 'Не больше 80 символов'
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
                    autofillHints: [
                      widget.register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    validator: (v) => widget.register && (v ?? '').length < 8
                        ? 'Нужно не менее 8 символов'
                        : (v ?? '').isEmpty
                        ? 'Введи пароль'
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
                        onPressed: busy ? null : forgotPassword,
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
  final DiaryStore? store;
  final DateTime month;
  final Budget? initial;
  final VoidCallback onBack;
  final Future<void> Function(Budget?) onSave;
  const BudgetScreen({
    this.store,
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
  bool carryForward = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    carryForward = b?.carryForward ?? false;
    fields = [b?.income, b?.dreams, b?.reserve]
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
                limit: 99999999999,
                reserve: values[2],
                dreams: values[1],
                simplePlan: true,
                carryForward: carryForward,
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
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenTop(
          onBack: widget.onBack,
          onHelp: () => showKopiMessage(
            context,
            'Оставим место для важного',
            'Укажи общий доход месяца и сумму на мечты. Добавь кредит и подписки в обязательные платежи. Остальное распределим на повседневные покупки. Это план: он учитывает зарплату, даже если она поступит позже.',
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
                for (
                  var i = 0;
                  i <
                      (widget.initial?.reserve != null &&
                              widget.initial!.reserve > 0
                          ? 3
                          : 2);
                  i++
                )
                  KopiField(
                    label: [
                      'Доход за месяц, ₽',
                      'Отложить на мечты, ₽',
                      'Общий резерв прежнего плана, ₽',
                    ][i],
                    controller: fields[i],
                    hint: i == 0 ? '60 000' : '0',
                    moneyInput: true,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => (v ?? '').trim().isEmpty && i > 0
                        ? null
                        : parseMoney(v ?? '') == null
                        ? 'Укажи сумму от нуля'
                        : null,
                  ),
                const Text(
                  'Это план месяца, а не баланс банковского счёта. Зарплата, записанная в доходы, подтверждает план. Поступления сверх плана увеличивают бюджет.',
                  style: TextStyle(fontSize: 12, color: KopiColors.muted),
                ),
                const SizedBox(height: 20),
                const Heading('Обязательные платежи', size: 20),
                const Text(
                  'Добавь кредит, аренду и подписки с датами. Их суммы автоматически вычтем из денег на повседневные покупки.',
                  style: TextStyle(fontSize: 12, color: KopiColors.muted),
                ),
                if (widget.store != null) ...[
                  for (final item in widget.store!.paymentsFor(widget.month))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.payment.title),
                      trailing: Text(money(item.payment.amount)),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить платёж'),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (ctx) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Обязательный платёж'),
                            ),
                            body: SafeArea(
                              child: PaymentScreen(
                                store: widget.store!,
                                date: widget.month,
                                today: DateTime.now(),
                                onComplete: () => Navigator.pop(ctx),
                              ),
                            ),
                          ),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'На повседневные покупки: ${money((parseMoney(fields[0].text) ?? 0) - (parseMoney(fields[1].text) ?? 0) - max(parseMoney(fields[2].text) ?? 0, widget.store?.paymentsFor(widget.month).fold<int>(0, (sum, p) => sum + p.payment.amount) ?? 0))} в месяц',
                  style: const TextStyle(fontSize: 15),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Перенести остаток прошлого месяца'),
                  subtitle: const Text(
                    'Включи, если хочешь добавить неиспользованные деньги прошлого месяца.',
                  ),
                  value: carryForward,
                  onChanged: (v) => setState(() => carryForward = v),
                ),
                const SizedBox(height: 24),
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
  final VoidCallback? onHistory,
      onOperation,
      onCalendar,
      onSubscriptions,
      onProfile,
      onDreams,
      onOverview;
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
    this.onProfile,
    this.onDreams,
    this.onOverview,
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
              Text(
                widget.store.isCloud
                    ? 'Дневник сохранён в твоём аккаунте'
                    : 'Деморежим · данные на этом устройстве',
                style: const TextStyle(fontSize: 11, color: KopiColors.berry),
              ),
              const SizedBox(height: 20),
              KopiButton(
                'Мой бюджет',
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onBudget();
                },
              ),
              const SizedBox(height: 6),
              if (widget.onSubscriptions != null) ...[
                KopiButton(
                  'Регулярные платежи',
                  secondary: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onSubscriptions!();
                  },
                ),
                const SizedBox(height: 6),
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
              const SizedBox(height: 6),
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
    final income = examples
        ? 6000000
        : widget.store.incomeFor(widget.month) +
              widget.store.carriedFor(widget.month);
    final available = examples
        ? 4180000
        : widget.store.availableFor(widget.month);
    final reserve = examples ? 1100000 : widget.store.reserveFor(widget.month);
    final upcoming = widget.store
        .paymentsFor(widget.month)
        .where((p) => !widget.store.isPaid(p))
        .toList();
    final spent = examples ? 1820000 : widget.store.spentFor(widget.month);
    final savedThisMonth = examples
        ? 0
        : widget.store.contributionsFor(widget.month);
    final isCurrent = monthKey(widget.month) == monthKey(widget.today);
    final isPast = widget.month.isBefore(
      DateTime(widget.today.year, widget.today.month),
    );
    final days =
        DateTime(widget.month.year, widget.month.month + 1, 0).day -
        (isCurrent ? widget.today.day - 1 : 0);
    final dreams = examples
        ? 500000
        : widget.store.dreamsReserveFor(widget.month, widget.today);
    final allowance = budget == null
        ? null
        : DailyAllowance.calculate(
            limit: budget.limit,
            spent: spent,
            available: available,
            reserve: reserve,
            dreams: dreams,
            days: days,
            spentToday: isCurrent && !examples
                ? widget.store.everydaySpentOn(widget.today)
                : 0,
          );
    final previewCount = MediaQuery.sizeOf(context).height >= 900 ? 2 : 1;
    final progressTotal = budget?.simplePlan == true
        ? income
        : (budget?.limit ?? 0);
    final progress = budget == null || progressTotal == 0
        ? (spent > 0 ? 1.0 : 0.0)
        : (spent / progressTotal).clamp(0.0, 1.0);
    return Column(
      children: [
        ScreenTop(
          brand: true,
          onProfile: widget.onProfile ?? profile,
          onHelp: () => showKopiMessage(
            context,
            'Сколько можно сегодня',
            'Из бюджета месяца вычитаем обязательные платежи, мечты и прошлые расходы. Распределяем на оставшиеся дни. Сегодняшние повседневные покупки вычитаем полностью: расход 500 ₽ уменьшает остаток на сегодня на 500 ₽. Завтра перерассчитаем план.',
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                const SizedBox(height: 8),
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
                const SizedBox(height: 6),
                Center(
                  child: Heading(
                    budget == null
                        ? '— ₽'
                        : money(
                            isPast
                                ? max(0, allowance!.free)
                                : allowance!.amount,
                          ),
                    size: 34,
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
                            'Доход плана: ${money(income)}\nПотрачено: ${money(spent)}\nИз них взносы в мечты: ${money(savedThisMonth)}\nОстаток бюджета: ${money(available)}\nОбязательные платежи: ${money(reserve)}\nНа мечты: ${money(dreams)}\nОсталось дней: $days\nСвободная сумма: ${money(allowance!.free)}\n\nСегодняшние повседневные расходы вычитаются из дневной суммы полностью. Оплату обязательного платежа отмечай в календаре, чтобы она освободила резерв.',
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Metric('Средства месяца', money(income)),
                    _Metric('Потрачено', money(spent)),
                  ],
                ),
                const SizedBox(height: 6),
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
                            : 'Бюджет ${money(progressTotal)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: KopiColors.muted,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SectionTitle(
                  'Доходы',
                  'Все записи →',
                  widget.onHistory ?? () {},
                ),
                if (!examples &&
                    widget.store
                        .entriesFor(widget.month)
                        .where((e) => e.isIncome)
                        .isEmpty)
                  const _Empty('Поступлений пока нет'),
                if (!examples)
                  ...widget.store
                      .entriesFor(widget.month)
                      .where((e) => e.isIncome)
                      .take(previewCount)
                      .map(
                        (e) => InkWell(
                          onTap: () => widget.onEntry?.call(e),
                          child: ExpenseRow(entry: e),
                        ),
                      ),
                const SizedBox(height: 8),
                _SectionTitle('Расходы', 'Все записи →', () {
                  if (widget.onHistory != null && !examples) {
                    widget.onHistory!();
                  } else {
                    history(entries);
                  }
                }),
                if (savedThisMonth > 0)
                  Text(
                    'Взносы в мечты за месяц: ${money(savedThisMonth)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (entries.isEmpty && savedThisMonth == 0)
                  const _Empty(
                    'Пока без записей\nНажми «+», чтобы добавить первый расход.',
                  ),
                ...entries
                    .take(previewCount)
                    .map(
                      (entry) => InkWell(
                        onTap: widget.onEntry == null || examples
                            ? null
                            : () => widget.onEntry!(entry),
                        child: ExpenseRow(entry: entry),
                      ),
                    ),
                const SizedBox(height: 8),
                _SectionTitle(
                  'Обязательные платежи',
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
                      .take(previewCount)
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
                const SizedBox(height: 4),
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
                _NavItem(
                  'Мечты',
                  Glyph.flag,
                  onTap: widget.onDreams ?? () => later('Мечты'),
                ),
                _NavItem(
                  'Обзор',
                  Glyph.overview,
                  onTap: widget.onOverview ?? () => later('Обзор'),
                ),
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
    children: [
      Expanded(child: Heading(title, size: 20)),
      TextButton(
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
      padding: const EdgeInsets.symmetric(vertical: 9),
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
            '${entry.isIncome
                ? '+'
                : payment
                ? ''
                : '−'}${money(entry.amount)}',
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
          id: widget.store.newId(),
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
