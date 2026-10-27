import 'dart:math';
import 'package:flutter/material.dart';
import '../data/diary.dart';
import '../data/progress.dart';
import 'design.dart';
import 'finance_widgets.dart';
import 'goal_icons.dart';

const _padding = EdgeInsets.symmetric(horizontal: 28);
const _small = TextStyle(fontSize: 12, color: KopiColors.muted, height: 1.5);
const _gold = Color(0xFFD4B471);

class AnalyticsScreen extends StatefulWidget {
  final DiaryStore store;
  final DateTime month, today;
  final ValueChanged<int> onMonth;
  final VoidCallback onSubscriptions, onAdd;
  const AnalyticsScreen({
    super.key,
    required this.store,
    required this.month,
    required this.today,
    required this.onMonth,
    required this.onSubscriptions,
    required this.onAdd,
  });
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool showAll = false;
  DiaryStore get store => widget.store;
  DateTime get month => widget.month;
  DateTime get today => widget.today;
  ValueChanged<int> get onMonth => widget.onMonth;
  VoidCallback get onSubscriptions => widget.onSubscriptions;
  VoidCallback get onAdd => widget.onAdd;
  @override
  Widget build(BuildContext context) {
    final stats = ExpenseAnalytics.from(store.entries, month, today);
    final subscriptions = store
        .paymentsFor(month)
        .where((p) => p.payment.monthly)
        .fold<int>(0, (sum, p) => sum + p.payment.amount);
    final colors = [
      KopiColors.accent,
      KopiColors.sage,
      KopiColors.lavender,
      KopiColors.sand,
      const Color(0xFFC3D6D3),
      const Color(0xFFD7C9C2),
    ];
    return SingleChildScrollView(
      padding: _padding,
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
                  monthTitle(month),
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
          const SizedBox(height: 22),
          Center(
            child: Semantics(
              label:
                  'Расходы за месяц: ${money(stats.total)}. ${stats.categories.map((c) => '${c.name}: ${money(c.amount)}').join('. ')}',
              child: ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _DonutPainter(stats.categories, colors),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(26),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Расходы за месяц',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: KopiColors.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Heading(money(stats.total), size: 25),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (stats.categories.isEmpty) ...[
            const FinanceEmpty('Расходов в этом месяце пока нет.'),
            KopiButton('+ Добавить запись', onPressed: onAdd, secondary: true),
          ],
          for (final (index, category)
              in (showAll ? stats.categories : stats.categories.take(3))
                  .indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: KopiColors.line, width: .6),
                ),
              ),
              child: Row(
                children: [
                  _IconTile(
                    icon: switch (category.name) {
                      'Продукты' => Glyph.bag,
                      'Дом' => Glyph.home,
                      'Кафе' => Glyph.coffee,
                      'Транспорт' => Glyph.bus,
                      'Подписки' || 'Платежи' => Glyph.movie,
                      _ => Glyph.bag,
                    },
                    color: colors[index % colors.length],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(category.amount * 100 / stats.total).round()}% расходов',
                          style: const TextStyle(
                            fontSize: 10,
                            color: KopiColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        money(category.amount),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (stats.categories.length > 3)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => showAll = !showAll),
                child: Text(
                  showAll
                      ? 'Свернуть категории ↑'
                      : 'Все категории (${stats.categories.length}) →',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Heading('Наблюдения', size: 24),
          const SizedBox(height: 20),
          Text(
            stats.observation,
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 6),
          Text(stats.comparison, style: _small),
          const SizedBox(height: 20),
          const Divider(),
          InkWell(
            onTap: onSubscriptions,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Подписки — ${money(subscriptions)} в месяц',
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Можно проверить, всеми ли ты пользуешься.',
                    style: _small,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<ExpenseCategory> values;
  final List<Color> colors;
  _DonutPainter(this.values, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * .13;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final total = values.fold<int>(0, (sum, c) => sum + c.amount);
    if (total == 0) {
      canvas.drawOval(rect, paint..color = KopiColors.line);
      return;
    }
    var angle = -pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i].amount / total * 2 * pi;
      canvas.drawArc(
        rect,
        angle,
        sweep,
        false,
        paint..color = colors[i % colors.length],
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.values != values;
}

class GoalsScreen extends StatelessWidget {
  final DiaryStore store;
  final DateTime today;
  final ValueChanged<SavingGoal> onGoal;
  final VoidCallback onAdd, onAchievements;
  const GoalsScreen({
    super.key,
    required this.store,
    required this.today,
    required this.onGoal,
    required this.onAdd,
    required this.onAchievements,
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: _padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FinanceHeading(
          'Мои мечты',
          'Откладываем понемногу. Двигаемся к своему.',
        ),
        if (store.goals.isEmpty)
          const FinanceEmpty(
            'На что хочется накопить?\nДобавь первую мечту и выбери удобный темп.',
          ),
        ...store.goals.map(
          (goal) => InkWell(
            key: ValueKey('goal-${goal.id}'),
            onTap: () => onGoal(goal),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: KopiColors.line, width: .7),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GoalSymbol(goal.icon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.title,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${money(goal.saved)} из ${money(goal.target)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: KopiColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(goal.progress * 100).floor()}%',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _GoalBar(goal),
                  const SizedBox(height: 9),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${money(goal.weekly)} в неделю',
                          style: const TextStyle(
                            fontSize: 11,
                            color: KopiColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          goal.complete
                              ? 'Мечта сбылась ✓'
                              : goal.icon == 'leaf'
                              ? goal.forecast(today).label(today)
                              : 'Посмотреть прогноз →',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11,
                            color: KopiColors.muted,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        KopiButton('+ Новая мечта', onPressed: onAdd, secondary: true),
        const SizedBox(height: 13),
        TextButton(
          onPressed: onAchievements,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
          ),
          child: const Row(
            children: [
              LineIcon(Glyph.star, color: _gold, size: 19),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Маленькие шаги и достижения →',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9A897B)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}

class ForecastScreen extends StatefulWidget {
  final DiaryStore store;
  final SavingGoal goal;
  final DateTime today;
  final VoidCallback onEdit;
  const ForecastScreen({
    super.key,
    required this.store,
    required this.goal,
    required this.today,
    required this.onEdit,
  });
  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  int extra = 0;
  bool busy = false;
  String? error;
  @override
  void didUpdateWidget(covariant ForecastScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goal.weekly != widget.goal.weekly ||
        oldWidget.goal.saved != widget.goal.saved) {
      extra = 0;
    }
  }

  Future<void> apply() async {
    if (busy || extra == 0 || widget.goal.complete) return;
    final proposed = widget.goal.weekly + extra;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KopiColors.background,
        title: const Heading('Выбрать новый темп?', size: 24),
        content: Text(
          'Откладывать ${money(proposed)} в неделю вместо ${money(widget.goal.weekly)}?\n\nСохраним план и пересчитаем резерв на мечты. Деньги автоматически не переводятся.',
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Оставить прежний'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Подтвердить план'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.saveGoal(widget.goal.withWeekly(proposed));
      if (mounted) {
        setState(() {
          extra = 0;
          busy = false;
        });
      }
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
  Widget build(BuildContext context) {
    final goal = widget.goal,
        forecast = widget.goal.forecast(widget.today, extra: extra);
    final maxExtra = max(500000, min(10000000, goal.weekly * 2));
    return SingleChildScrollView(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinanceHeading(
            goal.title,
            goal.complete
                ? 'Ты уже накопил на эту мечту.'
                : 'Мечта становится ближе с каждым шагом.',
          ),
          const SizedBox(height: 4),
          Center(child: GoalSymbol(goal.icon, size: 48, tile: false)),
          const SizedBox(height: 24),
          Center(child: Heading(money(goal.saved), size: 36)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'из ${money(goal.target)} · ${goal.complete ? 'цель достигнута' : '${(goal.progress * 100).floor()}% пути'}',
              style: _small,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 26),
          _GoalBar(goal),
          const SizedBox(height: 26),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ForecastMetric('Осталось', money(goal.remaining)),
              _ForecastMetric('Текущий план', '${money(goal.weekly)}/нед.'),
            ],
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EBF6),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Дополнительно к базовым ${money(goal.weekly)} в неделю',
                  style: const TextStyle(fontSize: 11, height: 1.6),
                ),
                const SizedBox(height: 10),
                Heading(forecast.label(widget.today), size: 25),
                if (!goal.complete) ...[
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFBDA6D0),
                      inactiveTrackColor: Colors.white,
                      thumbColor: const Color(0xFFAC91B9),
                      trackHeight: 5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 18,
                      ),
                    ),
                    child: Slider(
                      key: const ValueKey('goal-extra-slider'),
                      value: extra.toDouble().clamp(0, maxExtra.toDouble()),
                      min: 0,
                      max: maxExtra.toDouble(),
                      divisions: maxExtra ~/ 10000,
                      label: money(extra),
                      semanticFormatterCallback: (value) =>
                          'Дополнительно ${money(value.round())} в неделю',
                      onChanged: busy
                          ? null
                          : (value) => setState(() => extra = value.round()),
                    ),
                  ),
                  Text(
                    'Дополнительно: ${money(extra)} в неделю',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9983AC),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Это оценка срока при регулярных взносах. Увеличение накоплений уменьшает свободные деньги.',
            style: TextStyle(
              fontSize: 11,
              color: KopiColors.muted,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 27),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                error!,
                style: const TextStyle(color: KopiColors.error),
              ),
            ),
          KopiButton(
            goal.complete ? 'Мечта сбылась' : 'Выбрать этот план',
            onPressed: extra == 0 || goal.complete ? null : apply,
            busy: busy,
          ),
          Center(
            child: TextButton(
              onPressed: busy ? null : widget.onEdit,
              child: const Text(
                'Изменить мечту и накопления',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class AchievementsScreen extends StatefulWidget {
  final DiaryStore store;
  final DateTime today;
  const AchievementsScreen({
    super.key,
    required this.store,
    required this.today,
  });
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool busy = false;
  String? error;
  Future<void> check() async {
    if (busy || widget.store.checkedDays.contains(dayKey(widget.today))) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.checkToday(widget.today);
      if (mounted) setState(() => busy = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не получилось сохранить отметку.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store, today = widget.today;
    final streak = currentStreak(store.checkedDays, today),
        checked = store.checkedDays.contains(dayKey(today));
    return SingleChildScrollView(
      padding: _padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FinanceHeading(
            'Твои маленькие победы',
            'Регулярность важнее идеального результата.',
          ),
          const SizedBox(height: 35),
          const Center(child: Flower(size: 44, color: _gold)),
          const SizedBox(height: 20),
          Center(
            child: Heading(
              '$streak ${plural(streak, 'день', 'дня', 'дней')}',
              size: 36,
            ),
          ),
          const SizedBox(height: 9),
          Center(
            child: Text(
              streak == 0
                  ? 'Начни с внимания к своим деньгам.'
                  : 'Ты уделяешь внимание своим деньгам.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: KopiColors.muted),
            ),
          ),
          const SizedBox(height: 42),
          Row(
            children: [
              for (var i = 6; i >= 0; i--)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final day = addDays(today, -i);
                      final done = store.checkedDays.contains(dayKey(day));
                      return Semantics(
                        label:
                            '${dateLabel(day)}: ${done ? 'учёт проверен' : 'без отметки'}',
                        child: ExcludeSemantics(
                          child: Column(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done
                                      ? const Color(0xFFDDE6CE)
                                      : const Color(0xFFF0E9E8),
                                ),
                                child: Text(
                                  done ? '✓' : '·',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: done
                                        ? const Color(0xFF799064)
                                        : KopiColors.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                [
                                  'Пн',
                                  'Вт',
                                  'Ср',
                                  'Чт',
                                  'Пт',
                                  'Сб',
                                  'Вс',
                                ][day.weekday - 1],
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: KopiColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 35),
          if (error != null)
            Text(error!, style: const TextStyle(color: KopiColors.error)),
          KopiButton(
            checked ? 'Сегодня уже отмечено ✓' : 'Я проверил учёт за сегодня',
            onPressed: checked ? null : check,
            busy: busy,
          ),
          const SizedBox(height: 26),
          const Heading('Твои значки', size: 24),
          const SizedBox(height: 10),
          _BadgeRow(
            'Первый шаг',
            'Ты записал первую операцию',
            Glyph.leaf,
            KopiColors.sage,
            store.badges.contains('first') || store.entries.isNotEmpty,
          ),
          _BadgeRow(
            'Неделя внимания',
            '7 дней проверки учёта подряд',
            Glyph.star,
            KopiColors.sand,
            store.badges.contains('week'),
          ),
          _BadgeRow(
            'Мечта сбылась',
            'Ты накопил на свою цель',
            Glyph.flag,
            KopiColors.lavender,
            store.badges.contains('goal') || store.goals.any((g) => g.complete),
          ),
          const SizedBox(height: 20),
          if (store.supportEnabled)
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                'День без трат тоже считается. Главное — проверить записи, а не отказаться от нужного.',
                style: _small,
              ),
            ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final DiaryStore store;
  final VoidCallback onBudget, onSubscriptions, onAchievements, onHelp;
  final Future<void> Function() onLogout;
  const ProfileScreen({
    super.key,
    required this.store,
    required this.onBudget,
    required this.onSubscriptions,
    required this.onAchievements,
    required this.onHelp,
    required this.onLogout,
  });
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool busy = false;
  String? error;
  Future<void> preferences({bool? reminders, bool? support}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.savePreferences(
        reminders: reminders,
        support: support,
      );
      if (mounted) setState(() => busy = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Настройка не сохранилась. Попробуй ещё раз.';
        });
      }
    }
  }

  Future<void> logout() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onLogout();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не получилось выйти из дневника.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return SingleChildScrollView(
      padding: _padding,
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: Color(0xFFECD9E3),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Heading(
              store.name.trim().isEmpty
                  ? 'К'
                  : store.name.trim().characters.first.toUpperCase(),
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Heading(
            store.name.isEmpty ? 'Твой дневник' : store.name,
            size: 26,
            align: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(store.email, textAlign: TextAlign.center, style: _small),
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    backgroundColor: KopiColors.background,
                    builder: (_) => ProfileEditor(store: store),
                  ),
            child: const Text(
              'Изменить профиль',
              style: TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 12),
          _SettingRow(
            'Мой бюджет',
            'Доходы, лимиты и резервы',
            Glyph.bag,
            KopiColors.lavender,
            onTap: widget.onBudget,
          ),
          _SettingRow(
            'Регулярные платежи',
            'Подписки и обязательные расходы',
            Glyph.calendar,
            KopiColors.sand,
            onTap: widget.onSubscriptions,
          ),
          _SettingRow(
            'Напоминания',
            'Настройка демонстрационного режима',
            Glyph.bell,
            KopiColors.sand,
            value: store.remindersEnabled ? 'Вкл.' : 'Выкл.',
            toggle: store.remindersEnabled,
            onTap: busy
                ? null
                : () => preferences(reminders: !store.remindersEnabled),
          ),
          _SettingRow(
            'Поддержка Копи',
            'Мягкие подсказки и отметки',
            Glyph.leaf,
            KopiColors.sage,
            value: store.supportEnabled ? 'Вкл.' : 'Выкл.',
            toggle: store.supportEnabled,
            onTap: busy
                ? null
                : () => preferences(support: !store.supportEnabled),
          ),
          _SettingRow(
            'Мои достижения',
            'Маленькие шаги каждый день',
            Glyph.star,
            KopiColors.sand,
            onTap: widget.onAchievements,
          ),
          const SizedBox(height: 18),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                error!,
                style: const TextStyle(color: KopiColors.error),
              ),
            ),
          KopiButton(
            'Обучение и помощь',
            onPressed: widget.onHelp,
            secondary: true,
          ),
          const SizedBox(height: 7),
          TextButton(
            onPressed: busy ? null : logout,
            child: const Text(
              'Выйти из дневника',
              style: TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class GoalEditor extends StatefulWidget {
  final DiaryStore store;
  final DateTime today;
  final SavingGoal? initial;
  const GoalEditor({
    super.key,
    required this.store,
    required this.today,
    this.initial,
  });
  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, target, saved, weekly;
  late final String id;
  late DateTime next;
  late String icon;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final goal = widget.initial;
    id = goal?.id ?? 'goal-${DateTime.now().microsecondsSinceEpoch}';
    title = TextEditingController(text: goal?.title ?? '');
    target = TextEditingController(
      text: goal == null ? '' : money(goal.target, currency: false),
    );
    saved = TextEditingController(
      text: goal == null ? '' : money(goal.saved, currency: false),
    );
    weekly = TextEditingController(
      text: goal == null ? '' : money(goal.weekly, currency: false),
    );
    next = goal?.dueOnOrAfter(widget.today) ?? addDays(widget.today, 7);
    icon = goal?.icon ?? 'laptop';
  }

  @override
  void dispose() {
    title.dispose();
    target.dispose();
    saved.dispose();
    weekly.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final goal = SavingGoal(
      id: id,
      title: title.text.trim(),
      target: parseMoney(target.text)!,
      saved: parseMoney(saved.text) ?? 0,
      weekly: parseMoney(weekly.text) ?? 0,
      nextContribution: next,
      icon: icon,
    );
    try {
      await widget.store.saveGoal(goal);
      if (mounted) Navigator.pop(context, goal.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не получилось сохранить мечту.';
        });
      }
    }
  }

  Future<void> remove() async {
    if (busy) return;
    final yes = await confirmRemoval(
      context,
      'Удалить мечту?',
      'Её план исчезнет из списка и прогноза. Денежные переводы не выполняются, полученные значки останутся.',
    );
    if (!yes || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.store.deleteGoal(id);
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не получилось удалить мечту.';
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
            Heading(widget.initial == null ? 'Новая мечта' : 'Твоя мечта'),
            const SizedBox(height: 24),
            KopiField(
              label: 'Название мечты',
              hint: 'Например, новый ноутбук',
              controller: title,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Дай мечте название'
                  : v!.trim().length > 70
                  ? 'Не больше 70 символов'
                  : null,
            ),
            KopiField(
              label: 'Нужно накопить, ₽',
              hint: '80 000',
              controller: target,
              moneyInput: true,
              validator: (v) => (parseMoney(v ?? '') ?? 0) <= 0
                  ? 'Введи сумму больше нуля'
                  : null,
            ),
            KopiField(
              label: 'Уже накоплено, ₽',
              hint: '0',
              controller: saved,
              moneyInput: true,
              validator: (v) =>
                  (v ?? '').trim().isEmpty || parseMoney(v!) != null
                  ? null
                  : 'Проверь сумму',
            ),
            KopiField(
              label: 'Откладывать в неделю, ₽',
              hint: '0',
              controller: weekly,
              moneyInput: true,
              action: TextInputAction.done,
              validator: (v) =>
                  (v ?? '').trim().isEmpty || parseMoney(v!) != null
                  ? null
                  : 'Проверь сумму',
            ),
            DateField(
              label: 'Ближайший взнос',
              date: next,
              first: widget.today,
              last: DateTime(max(next.year, widget.today.year + 20), 12, 31),
              onChanged: (date) => setState(() => next = date),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: InkWell(
                key: const ValueKey('goal-icon-field'),
                borderRadius: BorderRadius.circular(12),
                onTap: busy
                    ? null
                    : () async {
                        final chosen = await chooseGoalIcon(context, icon);
                        if (chosen != null && mounted) {
                          setState(() => icon = chosen);
                        }
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      GoalSymbol(icon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Значок мечты', style: _small),
                            const SizedBox(height: 4),
                            Text(goalIconById(icon).label),
                          ],
                        ),
                      ),
                      const Text(
                        'Выбрать →',
                        style: TextStyle(fontSize: 12, color: KopiColors.berry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Text(
              '«Уже накоплено» — деньги, которые ты отложил отдельно. Здесь мы отмечаем прогресс; деньги не переводятся и не списываются повторно.',
              style: TextStyle(
                fontSize: 11,
                color: KopiColors.muted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            if (error != null)
              Text(error!, style: const TextStyle(color: KopiColors.error)),
            KopiButton('Сохранить мечту', onPressed: save, busy: busy),
            if (widget.initial != null)
              Center(
                child: TextButton(
                  onPressed: busy ? null : remove,
                  child: const Text(
                    'Удалить мечту',
                    style: TextStyle(color: KopiColors.error, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class ProfileEditor extends StatefulWidget {
  final DiaryStore store;
  const ProfileEditor({super.key, required this.store});
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name = TextEditingController(
        text: widget.store.name,
      ),
      email = TextEditingController(text: widget.store.email);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.saveProfile(name.text, email.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не получилось сохранить профиль.';
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
            const Heading('Изменить профиль'),
            const SizedBox(height: 24),
            KopiField(
              label: 'Имя',
              controller: name,
              validator: (v) => (v ?? '').trim().length < 2
                  ? 'Введи имя, хотя бы 2 символа'
                  : (v ?? '').trim().length > 60
                  ? 'Не больше 60 символов'
                  : null,
            ),
            KopiField(
              label: 'Почта',
              controller: email,
              keyboardType: TextInputType.emailAddress,
              action: TextInputAction.done,
              validator: (v) =>
                  RegExp(
                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                  ).hasMatch((v ?? '').trim())
                  ? null
                  : 'Проверь адрес почты',
            ),
            const Text(
              'Изменения сохраняются в демопрофиле на этом устройстве. Письмо подтверждения не отправляется.',
              style: _small,
            ),
            const SizedBox(height: 20),
            if (error != null)
              Text(error!, style: const TextStyle(color: KopiColors.error)),
            KopiButton('Сохранить профиль', onPressed: save, busy: busy),
          ],
        ),
      ),
    ),
  );
}

Future<void> showEducation(
  BuildContext context, {
  DiaryStore? store,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: KopiColors.background,
  builder: (ctx) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Heading('В своём ритме'),
          const SizedBox(height: 20),
          for (final item in const [
            (
              'План на месяц',
              'Укажи доступные деньги, лимит и резервы. Новые доходы добавляются через «+». Ожидаемую зарплату пока не учитываем.',
            ),
            (
              'Записи и календарь',
              'История хранит расходы и доходы. В календаре планируются платежи. Отметка оплаты создаёт один расход и освобождает резерв.',
            ),
            (
              'Мечты и прогноз',
              'Задай цель, накопленную сумму и недельный взнос. Ползунок только моделирует срок: новый темп сохраняется после подтверждения.',
            ),
            (
              'Маленькие шаги',
              'Проверяй учёт, даже если сегодня не было трат. Одна отметка в день продолжает серию. Значки выдаются за внимание и прогресс, а не за отказ от необходимого.',
            ),
            (
              'Пока это деморежим',
              'Данные сохраняются на этом устройстве. Настройки напоминаний не отправляют уведомления. Копи не переводит деньги и не отменяет подписки.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Heading(item.$1, size: 21),
                  const SizedBox(height: 7),
                  Text(item.$2, style: _small),
                ],
              ),
            ),
          if (store != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: KopiButton(
                'Показывать подсказки снова',
                secondary: true,
                onPressed: () async {
                  try {
                    await store.resetEducation();
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (_) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Не получилось сохранить настройку. Попробуй ещё раз.',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          KopiButton('Понятно', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    ),
  ),
);

class _IconTile extends StatelessWidget {
  final Glyph icon;
  final Color color;
  const _IconTile({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: LineIcon(icon, size: 22),
  );
}

class _GoalBar extends StatelessWidget {
  final SavingGoal goal;
  const _GoalBar(this.goal);
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Накоплено ${(goal.progress * 100).floor()} процентов',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: LinearProgressIndicator(
        value: goal.progress,
        minHeight: 8,
        backgroundColor: const Color(0xFFF0EAE9),
        valueColor: AlwaysStoppedAnimation(
          goal.icon == 'leaf'
              ? const Color(0xFFB5CAA0)
              : const Color(0xFFC0ABD2),
        ),
      ),
    ),
  );
}

class _ForecastMetric extends StatelessWidget {
  final String label, value;
  const _ForecastMetric(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(label, textAlign: TextAlign.center, style: _small),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ],
    ),
  );
}

class _BadgeRow extends StatelessWidget {
  final String title, subtitle;
  final Glyph icon;
  final Color color;
  final bool earned;
  const _BadgeRow(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.earned,
  );
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$title. $subtitle. ${earned ? 'Получен' : 'Ещё впереди'}',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: KopiColors.line, width: .6)),
        ),
        child: Row(
          children: [
            _IconTile(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: KopiColors.muted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            Icon(
              earned ? Icons.check : Icons.favorite_border,
              size: earned ? 18 : 14,
              color: earned ? KopiColors.ink : KopiColors.muted,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SettingRow extends StatelessWidget {
  final String title, subtitle, value;
  final Glyph icon;
  final Color color;
  final VoidCallback? onTap;
  final bool? toggle;
  const _SettingRow(
    this.title,
    this.subtitle,
    this.icon,
    this.color, {
    required this.onTap,
    this.value = '›',
    this.toggle,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    toggled: toggle,
    button: true,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: KopiColors.line, width: .6)),
        ),
        child: Row(
          children: [
            _IconTile(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: KopiColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(value, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    ),
  );
}
