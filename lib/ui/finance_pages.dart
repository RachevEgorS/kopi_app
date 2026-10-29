import 'dart:math';
import 'package:flutter/material.dart';
import '../data/diary.dart';
import 'design.dart';
import 'finance_widgets.dart';

class HistoryScreen extends StatelessWidget {
  final DiaryStore store;
  final TextEditingController search;
  final int filter;
  final ValueChanged<int> onFilter;
  final ValueChanged<Entry> onEdit;
  final VoidCallback onAdd, onSearch;
  const HistoryScreen({
    super.key,
    required this.store,
    required this.search,
    required this.filter,
    required this.onFilter,
    required this.onEdit,
    required this.onAdd,
    required this.onSearch,
  });
  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final entries =
        store.entries
            .where(
              (e) =>
                  (filter == 0 || (filter == 2) == e.isIncome) &&
                  '${e.title} ${e.category} ${dateLabel(e.date)}'
                      .toLowerCase()
                      .contains(query),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinanceHeading(
            'История',
            'Маленькие записи складываются в ясную картину.',
          ),
          TextField(
            controller: search,
            onChanged: (_) => onSearch(),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Найти запись',
              hintStyle: const TextStyle(color: KopiColors.muted, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KopiColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KopiColors.line),
              ),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Очистить поиск',
                      onPressed: () {
                        search.clear();
                        onSearch();
                      },
                      icon: const Icon(Icons.close, size: 17),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          SoftSegments(
            labels: const ['Все', 'Расходы', 'Доходы'],
            selected: filter,
            onSelect: onFilter,
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            FinanceEmpty(
              query.isEmpty && filter == 0
                  ? 'Здесь появятся твои записи.\nНачни с одного расхода или дохода.'
                  : 'Ничего не найдено.\nПопробуй другой запрос или фильтр.',
            ),
          ...entries.map(
            (entry) => EntryTile(entry: entry, onTap: () => onEdit(entry)),
          ),
          const SizedBox(height: 20),
          KopiButton('+ Добавить запись', onPressed: onAdd, secondary: true),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class OperationScreen extends StatefulWidget {
  final DiaryStore store;
  final DateTime today;
  final Entry? initial;
  final VoidCallback onComplete;
  const OperationScreen({
    super.key,
    required this.store,
    required this.today,
    this.initial,
    required this.onComplete,
  });
  @override
  State<OperationScreen> createState() => _OperationScreenState();
}

class _OperationScreenState extends State<OperationScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController amount, note;
  late final String id;
  late bool income;
  late String category;
  late DateTime date;
  bool busy = false;
  String? error;
  List<String> get categories => income
      ? ['Зарплата', 'Подработка', 'Подарок', 'Другое']
      : [
          'Кафе',
          'Продукты',
          'Транспорт',
          'Дом',
          'Покупки',
          'Подписки',
          'Платежи',
          'Другое',
        ];
  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    id = e?.id ?? widget.store.newId();
    income = e?.isIncome ?? false;
    category = e?.category ?? 'Кафе';
    date = e?.date ?? dateOnly(widget.today);
    amount = TextEditingController(
      text: e == null ? '' : money(e.amount, currency: false),
    );
    note = TextEditingController(text: e?.title ?? '');
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    final entry = Entry(
      id: id,
      title: note.text.trim().isEmpty ? category : note.text.trim(),
      category: category,
      amount: parseMoney(amount.text)!,
      date: dateOnly(date),
      isIncome: income,
      paymentOccurrence: widget.initial?.paymentOccurrence,
    );
    try {
      if (widget.initial == null) {
        await widget.store.addEntry(entry);
      } else {
        await widget.store.updateEntry(entry);
      }
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не получилось сохранить запись. Попробуй ещё раз.';
        });
      }
    }
  }

  Future<void> remove() async {
    if (busy) return;
    final yes = await confirmRemoval(
      context,
      'Удалить запись?',
      widget.initial?.paymentOccurrence == null
          ? 'Она исчезнет из истории, а суммы в дневнике пересчитаются.'
          : 'Расход исчезнет из истории. Платёж снова будет отмечен как неоплаченный.',
    );
    if (!yes || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.deleteEntry(id);
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не получилось удалить запись.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinanceHeading(
            widget.initial == null ? 'Новая запись' : 'Твоя запись',
            'Пара секунд — и всё на своём месте.',
          ),
          SoftSegments(
            labels: const ['Расход', 'Доход'],
            selected: income ? 1 : 0,
            onSelect: busy || widget.initial?.paymentOccurrence != null
                ? null
                : (value) => setState(() {
                    income = value == 1;
                    category = categories.first;
                  }),
          ),
          const SizedBox(height: 25),
          KopiField(
            label: 'Сумма, ₽',
            hint: '0',
            controller: amount,
            moneyInput: true,
            validator: (v) => (parseMoney(v ?? '') ?? 0) <= 0
                ? 'Введи сумму больше нуля, до двух знаков после запятой'
                : null,
          ),
          ChoiceField(
            label: 'Категория',
            value: category,
            choices: {
              for (final c in {...categories, category}) c: c,
            },
            onChanged: (v) => setState(() => category = v),
          ),
          KopiField(
            label: 'Заметка',
            hint: income ? 'Например, зарплата' : 'Например, кофе с собой',
            controller: note,
            action: TextInputAction.done,
            validator: (v) => (v ?? '').trim().length > 100
                ? 'Сократи заметку до 100 символов'
                : null,
          ),
          DateField(
            label: 'Дата',
            date: date,
            first: DateTime(min(2020, date.year)),
            last: widget.today,
            onChanged: (v) => setState(() => date = v),
          ),
          if (widget.initial?.paymentOccurrence != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 18),
              child: Text(
                'Расход связан с оплатой в календаре.',
                style: TextStyle(fontSize: 11, color: KopiColors.muted),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                error!,
                style: const TextStyle(color: KopiColors.error),
              ),
            ),
          KopiButton(
            widget.initial == null
                ? (income ? 'Записать доход' : 'Записать расход')
                : 'Сохранить изменения',
            onPressed: save,
            busy: busy,
          ),
          if (widget.initial != null)
            Center(
              child: TextButton(
                onPressed: busy ? null : remove,
                child: const Text(
                  'Удалить запись',
                  style: TextStyle(color: KopiColors.error, fontSize: 12),
                ),
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
    ),
  );
}

class CalendarScreen extends StatelessWidget {
  final DiaryStore store;
  final DateTime selected, today;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<int> onMonth;
  final ValueChanged<PaymentOccurrence> onPayment;
  final VoidCallback onAdd, onSubscriptions;
  const CalendarScreen({
    super.key,
    required this.store,
    required this.selected,
    required this.today,
    required this.onSelect,
    required this.onMonth,
    required this.onPayment,
    required this.onAdd,
    required this.onSubscriptions,
  });
  @override
  Widget build(BuildContext context) {
    final first = DateTime(selected.year, selected.month);
    final count = DateTime(selected.year, selected.month + 1, 0).day;
    final offset = first.weekday - 1;
    final weeks = ((count + offset) / 7).ceil();
    final occurrences = store.paymentsFor(selected);
    final daily = occurrences.where((p) => p.date.day == selected.day).toList();
    final cellHeight = max(
      48.0,
      MediaQuery.textScalerOf(context).scale(13) + 28,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Предыдущий месяц',
                onPressed: () => onMonth(-1),
                icon: const LineIcon(Glyph.back, size: 13),
              ),
              Expanded(
                child: Text(
                  monthTitle(selected),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              IconButton(
                tooltip: 'Следующий месяц',
                onPressed: () => onMonth(1),
                icon: const LineIcon(Glyph.next, size: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final weekday in ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'])
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: const TextStyle(
                        fontSize: 10,
                        color: KopiColors.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          for (var week = 0; week < weeks; week++)
            Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(
                    child: Builder(
                      builder: (ctx) {
                        final day = week * 7 + weekday - offset + 1;
                        if (day < 1 || day > count) {
                          return SizedBox(height: cellHeight);
                        }
                        final date = DateTime(
                          selected.year,
                          selected.month,
                          day,
                        );
                        final chosen = day == selected.day;
                        final isToday = dateOnly(today) == date;
                        final hasPayment = occurrences.any(
                          (p) => p.date.day == day,
                        );
                        return Semantics(
                          label:
                              '${dateLabel(date)}${hasPayment ? ', есть платежи' : ''}${isToday ? ', сегодня' : ''}',
                          selected: chosen,
                          button: true,
                          child: InkWell(
                            key: ValueKey('calendar-day-$day'),
                            onTap: () => onSelect(date),
                            borderRadius: BorderRadius.circular(26),
                            child: SizedBox(
                              height: cellHeight,
                              child: ExcludeSemantics(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: chosen
                                            ? KopiColors.accent
                                            : null,
                                        shape: BoxShape.circle,
                                        border: isToday && !chosen
                                            ? Border.all(
                                                color: KopiColors.accent,
                                              )
                                            : null,
                                      ),
                                      child: Text(
                                        '$day',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: hasPayment
                                            ? KopiColors.berry
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(child: Heading(dayLabel(selected), size: 23)),
              TextButton(
                onPressed: onSubscriptions,
                child: const Text('Подписки →', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          if (daily.isEmpty)
            const FinanceEmpty('На этот день ничего не запланировано.'),
          ...daily.map(
            (p) => FinanceRow(
              title: p.payment.title,
              subtitle: store.isPaid(p)
                  ? 'Оплачено · расход в истории'
                  : '${p.payment.monthly ? 'Каждый месяц' : 'Один раз'} · ${reminderLabel(p.payment.reminderDays)}',
              amount: money(p.payment.amount),
              onTap: () => onPayment(p),
            ),
          ),
          const SizedBox(height: 23),
          KopiButton(
            '+ Запланировать платёж',
            onPressed: onAdd,
            secondary: true,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3ECE0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Напоминание не отменяет подписку. Отключить её можно в самом сервисе.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF9B8D76),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  final DiaryStore store;
  final DateTime date, today;
  final PlannedPayment? initial;
  final PaymentOccurrence? occurrence;
  final bool monthly;
  final VoidCallback onComplete;
  const PaymentScreen({
    super.key,
    required this.store,
    required this.date,
    required this.today,
    this.initial,
    this.occurrence,
    this.monthly = false,
    required this.onComplete,
  });
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, amount;
  late final String id;
  late DateTime date;
  late bool monthly;
  late int reminder;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    id = p?.id ?? widget.store.newId();
    title = TextEditingController(text: p?.title ?? '');
    amount = TextEditingController(
      text: p == null ? '' : money(p.amount, currency: false),
    );
    date = p?.start ?? widget.date;
    monthly = p?.monthly ?? widget.monthly;
    reminder = p?.reminderDays ?? 1;
  }

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await widget.store.savePayment(
        PlannedPayment(
          id: id,
          title: title.text.trim(),
          amount: parseMoney(amount.text)!,
          start: dateOnly(date),
          monthly: monthly,
          reminderDays: reminder,
        ),
      );
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не получилось сохранить платёж. Попробуй ещё раз.';
        });
      }
    }
  }

  Future<void> remove() async {
    if (busy) return;
    final yes = await confirmRemoval(
      context,
      'Удалить план платежа?',
      'Он исчезнет из календаря${monthly ? ' и списка регулярных платежей' : ''}. Уже записанные расходы останутся в истории. Подписка в самом сервисе не отменится.',
    );
    if (!yes || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.deletePayment(id);
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не получилось удалить платёж.';
        });
      }
    }
  }

  Future<void> pay() async {
    if (busy || widget.occurrence == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KopiColors.background,
        title: const Heading('Платёж уже оплачен?', size: 24),
        content: Text(
          'Запишем расход ${money(widget.occurrence!.payment.amount)} за сегодня и освободим его резерв. Приложение не переводит деньги. Используется сохранённая сумма платежа.',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Назад'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Да, записать оплату'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.pay(widget.occurrence!, widget.today);
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не получилось записать оплату.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final occurrence = widget.occurrence;
    final paid = occurrence != null && widget.store.isPaid(occurrence);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FinanceHeading(
              'Платёж и напоминание',
              'Чтобы важное не потерялось среди дел.',
            ),
            KopiField(
              label: 'Название',
              hint: 'Например, интернет',
              controller: title,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Как называется платёж?'
                  : v!.trim().length > 70
                  ? 'Название — не длиннее 70 символов'
                  : null,
            ),
            KopiField(
              label: 'Сумма, ₽',
              hint: '0',
              controller: amount,
              moneyInput: true,
              action: TextInputAction.done,
              validator: (v) => (parseMoney(v ?? '') ?? 0) <= 0
                  ? 'Введи сумму больше нуля, до двух знаков после запятой'
                  : null,
            ),
            DateField(
              label: monthly ? 'Дата первого платежа' : 'Дата платежа',
              date: date,
              first: DateTime(min(2020, date.year)),
              last: DateTime(max(widget.today.year + 20, date.year), 12, 31),
              onChanged: (v) => setState(() => date = v),
            ),
            ChoiceField(
              label: 'Повтор',
              value: monthly,
              choices: const {false: 'Один раз', true: 'Каждый месяц'},
              onChanged: (v) => setState(() => monthly = v),
            ),
            ChoiceField(
              label: 'Напомнить',
              value: reminder,
              choices: const {
                -1: 'Не напоминать',
                0: 'В день платежа',
                1: 'За 1 день',
                3: 'За 3 дня',
              },
              onChanged: (v) => setState(() => reminder = v),
            ),
            const Text(
              'Запись появится в календаре. Реальные уведомления в этой версии не отправляются.',
              style: TextStyle(
                fontSize: 11,
                color: KopiColors.muted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  error!,
                  style: const TextStyle(color: KopiColors.error),
                ),
              ),
            KopiButton('Сохранить платёж', onPressed: save, busy: busy),
            if (occurrence != null) ...[
              const SizedBox(height: 12),
              if (paid)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Оплачено · расход сохранён в истории',
                    style: TextStyle(color: Color(0xFF69815F), fontSize: 12),
                  ),
                )
              else if (!occurrence.date.isAfter(dateOnly(widget.today)))
                KopiButton(
                  'Отметить оплаченным',
                  secondary: true,
                  onPressed: busy ? null : pay,
                ),
            ],
            if (widget.initial != null)
              Center(
                child: TextButton(
                  onPressed: busy ? null : remove,
                  child: const Text(
                    'Удалить платёж',
                    style: TextStyle(color: KopiColors.error, fontSize: 12),
                  ),
                ),
              ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class SubscriptionsScreen extends StatelessWidget {
  final DiaryStore store;
  final DateTime today;
  final ValueChanged<PaymentOccurrence> onEdit;
  final VoidCallback onAdd;
  const SubscriptionsScreen({
    super.key,
    required this.store,
    required this.today,
    required this.onEdit,
    required this.onAdd,
  });
  @override
  Widget build(BuildContext context) {
    final recurring = store.payments.where((p) => p.monthly).toList()
      ..sort(
        (a, b) => a.nextFrom(today).date.compareTo(b.nextFrom(today).date),
      );
    final total = recurring.fold<int>(0, (sum, p) => sum + p.amount);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinanceHeading(
            'Регулярные платежи',
            'Всё, что повторяется из месяца в месяц.',
          ),
          const Center(
            child: Text(
              'Запланировано в месяц',
              style: TextStyle(fontSize: 12, color: KopiColors.muted),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Heading(money(total), size: 38)),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Подписки, коммунальные услуги и другие платежи',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: KopiColors.muted,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 26),
          const Divider(),
          if (recurring.isEmpty)
            const FinanceEmpty(
              'Регулярных платежей пока нет.\nДобавь подписку, интернет или оплату дома.',
            ),
          ...recurring.map((p) {
            final next = p.nextFrom(today);
            return FinanceRow(
              title: p.title,
              subtitle:
                  '${dayLabel(next.date)} · ${reminderLabel(p.reminderDays)}',
              amount: money(p.amount),
              onTap: () => onEdit(next),
              color: const Color(0xFFE3D8ED),
            );
          }),
          const SizedBox(height: 20),
          KopiButton(
            '+ Добавить регулярный платёж',
            onPressed: onAdd,
            secondary: true,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
