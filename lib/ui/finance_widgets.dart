import 'package:flutter/material.dart';
import '../data/diary.dart';
import 'design.dart';

class KopiNavigation extends StatelessWidget {
  final String selected;
  final VoidCallback onDiary, onCalendar, onAdd, onDreams, onOverview;
  const KopiNavigation({
    super.key,
    required this.selected,
    required this.onDiary,
    required this.onCalendar,
    required this.onAdd,
    required this.onDreams,
    required this.onOverview,
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: KopiColors.background,
      border: Border(top: BorderSide(color: KopiColors.line, width: .7)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
      child: Row(
        children: [
          _Tab('Дневник', Glyph.home, selected == 'diary', onDiary),
          _Tab('Календарь', Glyph.calendar, selected == 'calendar', onCalendar),
          Expanded(
            child: Center(
              child: IconButton.filled(
                tooltip: 'Добавить расход',
                onPressed: onAdd,
                style: IconButton.styleFrom(
                  backgroundColor: KopiColors.accent,
                  minimumSize: const Size(48, 48),
                ),
                icon: const LineIcon(Glyph.plus, size: 22),
              ),
            ),
          ),
          _Tab('Мечты', Glyph.flag, selected == 'dreams', onDreams),
          _Tab('Обзор', Glyph.overview, selected == 'overview', onOverview),
        ],
      ),
    ),
  );
}

class _Tab extends StatelessWidget {
  final String label;
  final Glyph glyph;
  final bool selected;
  final VoidCallback onTap;
  const _Tab(this.label, this.glyph, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LineIcon(
                    glyph,
                    size: selected ? 26 : 21,
                    color: selected
                        ? KopiColors.berry
                        : const Color(0xFFAA9B9D),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    textAlign: TextAlign.center,
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
    ),
  );
}

class FinanceHeading extends StatelessWidget {
  final String title, subtitle;
  const FinanceHeading(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(title),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: KopiColors.muted,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class SoftSegments extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onSelect;
  const SoftSegments({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFF1E8EE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              selected: selected == i,
              child: TextButton(
                onPressed: onSelect == null ? null : () => onSelect!(i),
                style: TextButton.styleFrom(
                  backgroundColor: selected == i
                      ? KopiColors.background
                      : Colors.transparent,
                  foregroundColor: KopiColors.ink,
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class FinanceEmpty extends StatelessWidget {
  final String message;
  const FinanceEmpty(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 8),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          color: KopiColors.muted,
          height: 1.8,
        ),
      ),
    ),
  );
}

class FinanceRow extends StatelessWidget {
  final String title, subtitle, amount;
  final Glyph icon;
  final Color color;
  final VoidCallback onTap;
  final bool income;
  const FinanceRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onTap,
    this.icon = Glyph.movie,
    this.color = KopiColors.lavender,
    this.income = false,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      constraints: const BoxConstraints(minHeight: 62),
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
            child: Center(child: LineIcon(icon, size: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, height: 1.4)),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.5,
                    color: KopiColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            fit: FlexFit.tight,
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: income ? const Color(0xFF69815F) : KopiColors.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class EntryTile extends StatelessWidget {
  final Entry entry;
  final VoidCallback onTap;
  const EntryTile({super.key, required this.entry, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final (icon, color) = entry.isIncome
        ? (Glyph.bag, KopiColors.sage)
        : switch (entry.category) {
            'Кафе' => (Glyph.coffee, KopiColors.sand),
            'Продукты' => (Glyph.bag, KopiColors.sage),
            'Транспорт' => (Glyph.bus, KopiColors.lavender),
            'Платежи' || 'Подписки' => (Glyph.movie, KopiColors.lavender),
            _ => (Glyph.bag, KopiColors.soft),
          };
    return FinanceRow(
      title: entry.title,
      subtitle: '${dayLabel(entry.date)} · ${entry.category}',
      amount: '${entry.isIncome ? '+' : '−'}${money(entry.amount)}',
      onTap: onTap,
      icon: icon,
      color: color,
      income: entry.isIncome,
    );
  }
}

class DateField extends StatelessWidget {
  final String label;
  final DateTime date, first, last;
  final ValueChanged<DateTime> onChanged;
  const DateField({
    super.key,
    required this.label,
    required this.date,
    required this.first,
    required this.last,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 23),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: KopiColors.muted),
        ),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date.isBefore(first)
                  ? first
                  : date.isAfter(last)
                  ? last
                  : date,
              firstDate: first,
              lastDate: last,
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: KopiColors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dateLabel(date),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const LineIcon(
                  Glyph.calendar,
                  size: 17,
                  color: KopiColors.muted,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class ChoiceField<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> choices;
  final ValueChanged<T> onChanged;
  const ChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 23),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: KopiColors.muted),
        ),
        DropdownButtonFormField<T>(
          key: ValueKey('$label-$value'),
          initialValue: value,
          isExpanded: true,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: KopiColors.ink,
          ),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(vertical: 12),
            isDense: true,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: KopiColors.line),
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 17,
            color: KopiColors.muted,
          ),
          items: choices.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    ),
  );
}

Future<bool> confirmRemoval(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KopiColors.background,
        title: Heading(title, size: 24),
        content: Text(message, style: const TextStyle(height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Оставить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: KopiColors.error),
            ),
          ),
        ],
      ),
    ) ??
    false;
