import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'progress.dart';

const monthNames = [
  'январь',
  'февраль',
  'март',
  'апрель',
  'май',
  'июнь',
  'июль',
  'август',
  'сентябрь',
  'октябрь',
  'ноябрь',
  'декабрь',
];
String monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';
String monthTitle(DateTime date) {
  final name = monthNames[date.month - 1];
  return '${name[0].toUpperCase()}${name.substring(1)} ${date.year}';
}

/// All arithmetic uses integer kopecks; no floating point money conversion.
int? parseMoney(String text) {
  final value = text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
}

String money(int kopecks, {bool currency = true}) {
  final value = kopecks.abs();
  final whole = (value ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]} ',
  );
  final cents = value % 100;
  return '${kopecks < 0 ? '−' : ''}$whole${cents == 0 ? '' : ',${cents.toString().padLeft(2, '0')}'}${currency ? ' ₽' : ''}';
}

class Budget {
  final int income, limit, reserve, dreams;
  const Budget({
    required this.income,
    required this.limit,
    required this.reserve,
    required this.dreams,
  });
  Map<String, dynamic> toJson() => {
    'income': income,
    'limit': limit,
    'reserve': reserve,
    'dreams': dreams,
  };
  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    income: json['income'] as int,
    limit: json['limit'] as int,
    reserve: json['reserve'] as int,
    dreams: json['dreams'] as int,
  );
}

class Entry {
  final String id, title, category;
  final int amount;
  final DateTime date;
  final bool isIncome;
  final String? paymentOccurrence;
  const Entry({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    this.isIncome = false,
    this.paymentOccurrence,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'amount': amount,
    'date': date.toIso8601String(),
    'isIncome': isIncome,
    'paymentOccurrence': paymentOccurrence,
  };
  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String,
    amount: json['amount'] as int,
    date: DateTime.parse(json['date'] as String),
    isIncome: json['isIncome'] as bool? ?? false,
    paymentOccurrence: json['paymentOccurrence'] as String?,
  );
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
String dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
const monthGenitives = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];
String dayLabel(DateTime date) =>
    '${date.day} ${monthGenitives[date.month - 1]}';
String reminderLabel(int days) => switch (days) {
  -1 => 'Не напоминать',
  0 => 'В день платежа',
  1 => 'За 1 день',
  _ => 'За $days дня',
};

class PlannedPayment {
  final String id, title;
  final int amount, reminderDays;
  final DateTime start;
  final bool monthly;
  const PlannedPayment({
    required this.id,
    required this.title,
    required this.amount,
    required this.start,
    this.monthly = false,
    this.reminderDays = 1,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'start': start.toIso8601String(),
    'monthly': monthly,
    'reminderDays': reminderDays,
  };
  factory PlannedPayment.fromJson(Map<String, dynamic> json) => PlannedPayment(
    id: json['id'] as String,
    title: json['title'] as String,
    amount: json['amount'] as int,
    start: DateTime.parse(json['start'] as String),
    monthly: json['monthly'] as bool,
    reminderDays: json['reminderDays'] as int,
  );
  PaymentOccurrence? inMonth(DateTime month) {
    if (!monthly) {
      return monthKey(start) == monthKey(month)
          ? PaymentOccurrence(this, dateOnly(start))
          : null;
    }
    if (DateTime(
      month.year,
      month.month,
    ).isBefore(DateTime(start.year, start.month))) {
      return null;
    }
    return PaymentOccurrence(
      this,
      DateTime(
        month.year,
        month.month,
        min(start.day, DateTime(month.year, month.month + 1, 0).day),
      ),
    );
  }

  PaymentOccurrence nextFrom(DateTime today) {
    if (!monthly) return PaymentOccurrence(this, dateOnly(start));
    if (dateOnly(start).isAfter(dateOnly(today))) {
      return PaymentOccurrence(this, dateOnly(start));
    }
    final current = inMonth(today)!;
    return current.date.isBefore(dateOnly(today))
        ? inMonth(DateTime(today.year, today.month + 1))!
        : current;
  }
}

class PaymentOccurrence {
  final PlannedPayment payment;
  final DateTime date;
  const PaymentOccurrence(this.payment, this.date);
  String get key =>
      '${payment.id}@${monthKey(date)}-${date.day.toString().padLeft(2, '0')}';
}

class DailyAllowance {
  final int free, days;
  const DailyAllowance(this.free, this.days);
  int get amount => max(0, free ~/ days);
  static DailyAllowance calculate({
    required int limit,
    required int spent,
    required int available,
    required int reserve,
    required int dreams,
    required int days,
  }) => DailyAllowance(
    min(limit - spent, available) - reserve - dreams,
    max(1, days),
  );
}

class DiaryStore extends ChangeNotifier {
  final SharedPreferences preferences;
  DiaryStore(this.preferences);
  bool introduced = false, signedIn = false, setupDone = false;
  bool recovered = false;
  String name = '', email = '';
  Map<String, Budget> budgets = {};
  List<Entry> entries = [];
  List<PlannedPayment> payments = [];
  List<SavingGoal> goals = [];
  Set<String> checkedDays = {}, badges = {};
  bool remindersEnabled = true, supportEnabled = true;
  Set<String> seenEducation = {};
  bool educationSkipped = false;
  static const storageKey = 'kopi.frontend.v1';

  void load() {
    final source = preferences.getString(storageKey);
    if (source == null) return;
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      introduced = json['introduced'] as bool;
      signedIn = json['signedIn'] as bool;
      setupDone = json['setupDone'] as bool;
      name = json['name'] as String;
      email = json['email'] as String;
      budgets = (json['budgets'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, Budget.fromJson(v as Map<String, dynamic>)),
      );
      entries = (json['entries'] as List)
          .map((v) => Entry.fromJson(v as Map<String, dynamic>))
          .toList();
      payments = (json['payments'] as List? ?? [])
          .map((v) => PlannedPayment.fromJson(v as Map<String, dynamic>))
          .toList();
      goals = (json['goals'] as List? ?? [])
          .map((v) => SavingGoal.fromJson(v as Map<String, dynamic>))
          .toList();
      checkedDays = (json['checkedDays'] as List? ?? []).cast<String>().toSet();
      badges = (json['badges'] as List? ?? []).cast<String>().toSet();
      seenEducation = (json['seenEducation'] as List? ?? [])
          .cast<String>()
          .toSet();
      educationSkipped = json['educationSkipped'] as bool? ?? false;
      remindersEnabled = json['remindersEnabled'] as bool? ?? true;
      supportEnabled = json['supportEnabled'] as bool? ?? true;
      if (entries.isNotEmpty) badges.add('first');
      if (goals.any((g) => g.complete)) badges.add('goal');
      if (longestStreak(checkedDays) >= 7) badges.add('week');
    } catch (_) {
      recovered = true;
      signedIn = false;
      setupDone = false;
      budgets = {};
      entries = [];
      payments = [];
      goals = [];
      checkedDays = {};
      badges = {};
    }
  }

  Future<void> _save() async {
    final success = await preferences.setString(
      storageKey,
      jsonEncode({
        'introduced': introduced,
        'signedIn': signedIn,
        'setupDone': setupDone,
        'name': name,
        'email': email,
        'budgets': budgets.map((k, v) => MapEntry(k, v.toJson())),
        'entries': entries.map((e) => e.toJson()).toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
        'goals': goals.map((g) => g.toJson()).toList(),
        'checkedDays': checkedDays.toList(),
        'badges': badges.toList(),
        'seenEducation': seenEducation.toList(),
        'educationSkipped': educationSkipped,
        'remindersEnabled': remindersEnabled,
        'supportEnabled': supportEnabled,
      }),
    );
    if (!success) {
      throw StateError('Не удалось сохранить данные на устройстве.');
    }
    notifyListeners();
  }

  Future<void> enterDemo(String newName, String newEmail) async {
    final old = (introduced, signedIn, name, email);
    introduced = true;
    signedIn = true;
    name = newName.trim().isEmpty ? 'Друг' : newName.trim();
    email = newEmail.trim();
    try {
      await _save();
    } catch (_) {
      introduced = old.$1;
      signedIn = old.$2;
      name = old.$3;
      email = old.$4;
      rethrow;
    }
  }

  Future<void> saveBudget(DateTime month, Budget? budget) async {
    final key = monthKey(month), previous = budgets[monthKey(month)];
    final wasDone = setupDone;
    if (budget != null) budgets[key] = budget;
    setupDone = true;
    try {
      await _save();
    } catch (_) {
      setupDone = wasDone;
      if (previous == null) {
        budgets.remove(key);
      } else {
        budgets[key] = previous;
      }
      rethrow;
    }
  }

  Future<void> addEntry(Entry entry) async {
    if (entry.amount <= 0) throw ArgumentError('Сумма должна быть больше нуля');
    if (entries.any((e) => e.id == entry.id)) return;
    entries.add(entry);
    final hadFirst = badges.contains('first');
    badges.add('first');
    try {
      await _save();
    } catch (_) {
      entries.remove(entry);
      if (!hadFirst) badges.remove('first');
      rethrow;
    }
  }

  Future<void> updateEntry(Entry entry) async {
    if (entry.amount <= 0) throw ArgumentError('Сумма должна быть больше нуля');
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index < 0) throw StateError('Запись не найдена');
    final previous = entries[index];
    entries[index] = entry;
    try {
      await _save();
    } catch (_) {
      entries[index] = previous;
      rethrow;
    }
  }

  Future<void> deleteEntry(String id) async {
    final previous = List<Entry>.of(entries);
    entries.removeWhere((e) => e.id == id);
    try {
      await _save();
    } catch (_) {
      entries = previous;
      rethrow;
    }
  }

  Future<void> savePayment(PlannedPayment payment) async {
    if (payment.amount <= 0 || payment.title.trim().isEmpty) {
      throw ArgumentError('Укажи название и сумму');
    }
    final previous = List<PlannedPayment>.of(payments);
    final index = payments.indexWhere((p) => p.id == payment.id);
    if (index < 0) {
      payments.add(payment);
    } else {
      payments[index] = payment;
    }
    try {
      await _save();
    } catch (_) {
      payments = previous;
      rethrow;
    }
  }

  Future<void> deletePayment(String id) async {
    final previous = List<PlannedPayment>.of(payments);
    payments.removeWhere((p) => p.id == id);
    try {
      await _save();
    } catch (_) {
      payments = previous;
      rethrow;
    }
  }

  bool isPaid(PaymentOccurrence occurrence) =>
      entries.any((e) => e.paymentOccurrence == occurrence.key);

  Future<void> pay(PaymentOccurrence occurrence, DateTime today) async {
    if (isPaid(occurrence)) return;
    if (occurrence.date.isAfter(dateOnly(today))) {
      throw StateError('Отметить оплату можно в день платежа или позже');
    }
    await addEntry(
      Entry(
        id: 'payment:${occurrence.key}',
        title: occurrence.payment.title,
        category: 'Платежи',
        amount: occurrence.payment.amount,
        date: dateOnly(today),
        paymentOccurrence: occurrence.key,
      ),
    );
  }

  List<PaymentOccurrence> paymentsFor(DateTime month) =>
      payments
          .map((p) => p.inMonth(month))
          .whereType<PaymentOccurrence>()
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  int spentFor(DateTime month) => entriesFor(
    month,
  ).where((e) => !e.isIncome).fold(0, (sum, e) => sum + e.amount);
  int addedIncomeFor(DateTime month) => entriesFor(
    month,
  ).where((e) => e.isIncome).fold(0, (sum, e) => sum + e.amount);
  int incomeFor(DateTime month) =>
      (budgets[monthKey(month)]?.income ?? 0) + addedIncomeFor(month);

  /// Scheduled payments are covered by the manual reserve, not added twice.
  /// Paying creates an expense and releases the same part of the manual reserve.
  int reserveFor(DateTime month) {
    final paid = entriesFor(month)
        .where((e) => !e.isIncome && e.paymentOccurrence != null)
        .fold<int>(0, (sum, e) => sum + e.amount);
    final manual = max(0, (budgets[monthKey(month)]?.reserve ?? 0) - paid);
    final scheduled = paymentsFor(
      month,
    ).where((p) => !isPaid(p)).fold<int>(0, (sum, p) => sum + p.payment.amount);
    return max(manual, scheduled);
  }

  Future<void> logout() async {
    signedIn = false;
    try {
      await _save();
    } catch (_) {
      signedIn = true;
      rethrow;
    }
  }

  Future<void> finishEducation(String topic, {bool skipAll = false}) async {
    final previous = Set<String>.of(seenEducation), skipped = educationSkipped;
    seenEducation.add(topic);
    if (skipAll) educationSkipped = true;
    try {
      await _save();
    } catch (_) {
      seenEducation = previous;
      educationSkipped = skipped;
      rethrow;
    }
  }

  Future<void> resetEducation() async {
    final previous = Set<String>.of(seenEducation), skipped = educationSkipped;
    seenEducation = {};
    educationSkipped = false;
    try {
      await _save();
    } catch (_) {
      seenEducation = previous;
      educationSkipped = skipped;
      rethrow;
    }
  }

  Future<void> saveGoal(SavingGoal goal) async {
    if (goal.title.trim().isEmpty ||
        goal.target <= 0 ||
        goal.saved < 0 ||
        goal.weekly < 0) {
      throw ArgumentError('Проверь данные цели');
    }
    final previous = List<SavingGoal>.of(goals),
        previousBadges = Set<String>.of(badges);
    final index = goals.indexWhere((g) => g.id == goal.id);
    if (index < 0) {
      goals.add(goal);
    } else {
      goals[index] = goal;
    }
    if (goal.complete) badges.add('goal');
    try {
      await _save();
    } catch (_) {
      goals = previous;
      badges = previousBadges;
      rethrow;
    }
  }

  Future<void> deleteGoal(String id) async {
    final previous = List<SavingGoal>.of(goals);
    goals.removeWhere((g) => g.id == id);
    try {
      await _save();
    } catch (_) {
      goals = previous;
      rethrow;
    }
  }

  Future<void> checkToday(DateTime today) async {
    final key = dayKey(today);
    if (checkedDays.contains(key)) return;
    final previousBadges = Set<String>.of(badges);
    checkedDays.add(key);
    if (currentStreak(checkedDays, today) >= 7) badges.add('week');
    try {
      await _save();
    } catch (_) {
      checkedDays.remove(key);
      badges = previousBadges;
      rethrow;
    }
  }

  Future<void> saveProfile(String newName, String newEmail) async {
    if (newName.trim().length < 2 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(newEmail.trim())) {
      throw ArgumentError('Проверь имя и почту');
    }
    final previousName = name, previousEmail = email;
    name = newName.trim();
    email = newEmail.trim();
    try {
      await _save();
    } catch (_) {
      name = previousName;
      email = previousEmail;
      rethrow;
    }
  }

  Future<void> savePreferences({bool? reminders, bool? support}) async {
    final oldReminders = remindersEnabled, oldSupport = supportEnabled;
    remindersEnabled = reminders ?? remindersEnabled;
    supportEnabled = support ?? supportEnabled;
    try {
      await _save();
    } catch (_) {
      remindersEnabled = oldReminders;
      supportEnabled = oldSupport;
      rethrow;
    }
  }

  int dreamsReserveFor(DateTime month, DateTime today) {
    final planned = goals.fold<int>(
      0,
      (sum, goal) => sum + goal.reserveIn(month, today),
    );
    return max(budgets[monthKey(month)]?.dreams ?? 0, planned);
  }

  List<Entry> entriesFor(DateTime date) =>
      entries.where((e) => monthKey(e.date) == monthKey(date)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
}
