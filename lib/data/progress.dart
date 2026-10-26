import 'dart:math';
import 'diary.dart' show Entry, dateOnly, monthKey;

String dayKey(DateTime value) =>
    '${monthKey(value)}-${value.day.toString().padLeft(2, '0')}';
DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);
int civilDaysBetween(DateTime start, DateTime end) => DateTime.utc(
  end.year,
  end.month,
  end.day,
).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
String plural(int count, String one, String few, String many) {
  final lastTwo = count.abs() % 100;
  if (lastTwo >= 11 && lastTwo <= 14) return many;
  return switch (count.abs() % 10) {
    1 => one,
    2 || 3 || 4 => few,
    _ => many,
  };
}

class SavingGoal {
  final String id, title, icon;
  final int target, saved, weekly;
  final DateTime nextContribution;
  const SavingGoal({
    required this.id,
    required this.title,
    required this.target,
    required this.saved,
    required this.weekly,
    required this.nextContribution,
    this.icon = 'laptop',
  });
  int get remaining => max(0, target - saved);
  bool get complete => saved >= target;
  double get progress => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);
  SavingGoal withWeekly(int value) => SavingGoal(
    id: id,
    title: title,
    target: target,
    saved: saved,
    weekly: value,
    nextContribution: nextContribution,
    icon: icon,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'target': target,
    'saved': saved,
    'weekly': weekly,
    'nextContribution': nextContribution.toIso8601String(),
    'icon': icon,
  };
  factory SavingGoal.fromJson(Map<String, dynamic> json) => SavingGoal(
    id: json['id'] as String,
    title: json['title'] as String,
    target: json['target'] as int,
    saved: json['saved'] as int,
    weekly: json['weekly'] as int,
    nextContribution: DateTime.parse(json['nextContribution'] as String),
    icon: json['icon'] as String? ?? 'laptop',
  );

  DateTime dueOnOrAfter(DateTime day) {
    final first = dateOnly(nextContribution), from = dateOnly(day);
    if (!first.isBefore(from)) return first;
    final weeks = (civilDaysBetween(first, from) + 6) ~/ 7;
    return addDays(first, weeks * 7);
  }

  GoalForecast forecast(DateTime today, {int extra = 0}) {
    final contribution = weekly + extra;
    if (complete) return const GoalForecast(0, null);
    if (contribution <= 0) return const GoalForecast(null, null);
    final count = (remaining + contribution - 1) ~/ contribution;
    // A very small contribution can imply millions of years. Keep the count,
    // but don't construct an out-of-range DateTime or a misleading target date.
    final first = dueOnOrAfter(today);
    final lastSafe = DateTime(9999, 12, 31);
    final days = (count - 1) * 7;
    final finish = days > civilDaysBetween(first, lastSafe)
        ? null
        : addDays(first, days);
    return GoalForecast(count, finish);
  }

  int reserveIn(DateTime month, DateTime today) {
    if (complete || weekly <= 0) return 0;
    final first = DateTime(month.year, month.month),
        end = DateTime(month.year, month.month + 1, 0);
    if (end.isBefore(dateOnly(today))) return 0;
    final from = first.isBefore(dateOnly(today)) ? dateOnly(today) : first;
    final due = dueOnOrAfter(from);
    if (due.isAfter(end)) return 0;
    final count = civilDaysBetween(due, end) ~/ 7 + 1;
    return min(remaining, weekly * count);
  }
}

class GoalForecast {
  final int? contributions;
  final DateTime? finish;
  const GoalForecast(this.contributions, this.finish);
  String label(DateTime today) {
    if (contributions == 0) return 'Мечта сбылась';
    if (contributions == null) return 'Задай свой темп';
    if (finish == null) return 'Нужен более высокий взнос';
    final days = civilDaysBetween(today, finish!);
    if (days == 0) return 'Можно достичь сегодня';
    final weeks = (days + 6) ~/ 7;
    return 'Через $weeks ${plural(weeks, 'неделю', 'недели', 'недель')}';
  }
}

int currentStreak(Set<String> days, DateTime today) {
  var day = dateOnly(today);
  if (!days.contains(dayKey(day))) day = addDays(day, -1);
  var count = 0;
  while (days.contains(dayKey(day))) {
    count++;
    day = addDays(day, -1);
  }
  return count;
}

int longestStreak(Set<String> days) {
  final sorted = days.map(DateTime.tryParse).whereType<DateTime>().toList()
    ..sort();
  var best = 0, run = 0;
  DateTime? previous;
  for (final date in sorted) {
    run = previous != null && civilDaysBetween(previous, date) == 1
        ? run + 1
        : 1;
    best = max(best, run);
    previous = date;
  }
  return best;
}

class ExpenseCategory {
  final String name;
  final int amount;
  const ExpenseCategory(this.name, this.amount);
}

class ExpenseAnalytics {
  final List<ExpenseCategory> categories;
  final int total;
  final String observation, comparison;
  const ExpenseAnalytics(
    this.categories,
    this.total,
    this.observation,
    this.comparison,
  );
  factory ExpenseAnalytics.from(
    List<Entry> entries,
    DateTime month,
    DateTime today,
  ) {
    final current = entries.where(
      (e) => !e.isIncome && monthKey(e.date) == monthKey(month),
    );
    final sums = <String, int>{};
    for (final entry in current) {
      sums.update(
        entry.category,
        (v) => v + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    final categories =
        sums.entries.map((e) => ExpenseCategory(e.key, e.value)).toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
    final total = categories.fold<int>(0, (sum, c) => sum + c.amount);
    if (total == 0) {
      return ExpenseAnalytics(
        categories,
        0,
        'Пока нет расходов',
        'Добавь первую запись — здесь появятся наблюдения.',
      );
    }
    if (DateTime(
      month.year,
      month.month,
    ).isAfter(DateTime(today.year, today.month))) {
      return ExpenseAnalytics(
        categories,
        total,
        'Расходы будущего месяца',
        'Сравнение появится, когда наступит этот месяц.',
      );
    }
    final previous = DateTime(month.year, month.month - 1);
    final isCurrent = monthKey(month) == monthKey(today);
    final cutoff = isCurrent
        ? min(today.day, DateTime(previous.year, previous.month + 1, 0).day)
        : null;
    final name = sums.containsKey('Кафе') ? 'Кафе' : categories.first.name;
    int sumIn(DateTime period) => entries
        .where(
          (e) =>
              !e.isIncome &&
              e.category == name &&
              monthKey(e.date) == monthKey(period) &&
              (cutoff == null || e.date.day <= cutoff),
        )
        .fold<int>(0, (sum, e) => sum + e.amount);
    final now = sumIn(month), before = sumIn(previous);
    final comparison = cutoff == null
        ? 'По сравнению с предыдущим месяцем.'
        : 'Сравниваем первые $cutoff ${plural(cutoff, 'день', 'дня', 'дней')} двух месяцев.';
    if (before == 0) {
      return ExpenseAnalytics(
        categories,
        total,
        now > 0
            ? '$name — новая статья расходов'
            : 'Для сравнения пока мало данных',
        now > 0
            ? 'В таком же периоде прошлого месяца записей не было.'
            : comparison,
      );
    }
    final change = ((now - before).abs() * 100 / before).round();
    final observation = change == 0
        ? '$name — примерно на том же уровне'
        : '$name: на $change% ${now > before ? 'больше' : 'меньше'}';
    return ExpenseAnalytics(categories, total, observation, comparison);
  }
}
