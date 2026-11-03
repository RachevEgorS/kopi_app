import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'cloud_config.dart';
import 'cloud_errors.dart';
import 'diary.dart';
import 'progress.dart';
import 'notification_import.dart';

/// Server-confirmed writes; the old demo store is never uploaded or overwritten.
class CloudDiaryStore extends DiaryStore {
  final SupabaseClient client;
  CloudDiaryStore(super.preferences, this.client);
  @override
  bool get isCloud => true;
  String? userId;
  String? connectionError;
  String? pendingEmail;
  bool loading = true, refreshing = false, recoveringPassword = false;
  int _epoch = 0;
  bool _disposed = false;
  StreamSubscription<AuthState>? _authSubscription;
  Future<void>? _activation;
  Future<void> _queue = Future.value();
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _failedWrites = [];
  bool _offline = false;
  bool _progressMigrated = false;
  int get pendingCount => _pending.length;
  int get failedWriteCount => _failedWrites.length;
  String get _cacheKey => 'kopi.cloud.cache.v2.$userId';
  static const _introKey = 'kopi.cloud.introduced';
  String get _localKey => 'kopi.cloud.user.$userId';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    introduced = preferences.getBool(_introKey) ?? false;
    _authSubscription = client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          recoveringPassword = true;
        }
        unawaited(_activate(state.session?.user));
      },
      onError: (Object error, StackTrace stack) {
        connectionError = cloudError(error);
        _notify();
      },
    );
    await _activate(client.auth.currentUser);
  }

  // A new identity invalidates every in-flight read/write before clearing data.
  Future<void> _activate(User? user) {
    if (_activation != null && user?.id == userId) return _activation!;
    if (!loading && user?.id == userId) {
      email = user?.email ?? '';
      _notify();
      return _syncNotificationSession();
    }
    final epoch = ++_epoch;
    _clear();
    userId = user?.id;
    email = user?.email ?? '';
    loading = user != null;
    connectionError = null;
    if (user == null) recoveringPassword = false;
    _loadLocal();
    if (user != null && _loadCache()) {
      signedIn = true;
      loading = false;
    }
    _notify();
    final task = () async {
      try {
        await NotificationBridge.account(user?.id);
        if (user == null) return;
        await _syncNotificationSession();
        if (await _flushPending(user.id, epoch)) {
          await _download(user.id, epoch);
        }
        if (epoch != _epoch) return;
        signedIn = true;
        introduced = true;
        await preferences.setBool(_introKey, true);
      } catch (error) {
        if (epoch == _epoch) {
          connectionError = cloudError(error);
          _offline = _networkError(error);
        }
      } finally {
        if (epoch == _epoch) {
          loading = false;
          _notify();
        }
      }
    }();
    _activation = task;
    unawaited(
      task.whenComplete(() {
        if (epoch == _epoch) _activation = null;
      }),
    );
    return task;
  }

  void _clear() {
    _notificationRevision = null;
    refreshing = false;
    signedIn = false;
    setupDone = false;
    name = '';
    email = '';
    pendingEmail = null;
    budgets = {};
    entries = [];
    payments = [];
    goals = [];
    contributions = [];
    _pending = [];
    _failedWrites = [];
    _offline = false;
    _progressMigrated = false;
    checkedDays = {};
    badges = {};
    seenEducation = {};
    educationSkipped = false;
    remindersEnabled = true;
    supportEnabled = true;
  }

  void _loadLocal() {
    try {
      final data =
          jsonDecode(
                (userId == null ? null : preferences.getString(_localKey)) ??
                    preferences.getString('kopi.cloud.education') ??
                    '{}',
              )
              as Map<String, dynamic>;
      setupDone = data['setupDone'] == true;
      checkedDays = (data['checkedDays'] as List? ?? []).cast<String>().toSet();
      badges = (data['badges'] as List? ?? []).cast<String>().toSet();
      seenEducation = (data['seenEducation'] as List? ?? [])
          .cast<String>()
          .toSet();
      educationSkipped = data['educationSkipped'] == true;
    } catch (_) {
      /* A damaged UI preference must not hide the server diary. */
    }
  }

  Future<void> _saveLocal() async {
    if (userId == null) {
      // Pre-login tutorials are device preferences, separate from account data.
      await preferences.setString(
        'kopi.cloud.education',
        jsonEncode({
          'seenEducation': seenEducation.toList(),
          'educationSkipped': educationSkipped,
        }),
      );
      return;
    }
    final success = await preferences.setString(
      _localKey,
      jsonEncode({
        'setupDone': setupDone,
        'checkedDays': checkedDays.toList(),
        'badges': badges.toList(),
        'seenEducation': seenEducation.toList(),
        'educationSkipped': educationSkipped,
      }),
    );
    if (!success) throw StateError('Не удалось сохранить настройки устройства');
  }

  Future<List<Map<String, dynamic>>> _all(String table, String owner) async {
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 500) {
      final page = await client
          .from(table)
          .select()
          .eq('user_id', owner)
          .order('id')
          .range(offset, offset + 499);
      rows.addAll(page);
      if (page.length < 500) return rows;
    }
  }

  Future<void> _download(String owner, int epoch) async {
    final data = await Future.wait<dynamic>([
      client.from('profiles').select().eq('user_id', owner).single(),
      _all('monthly_budgets', owner),
      _all('transactions', owner),
      _all('planned_payments', owner),
      _all('savings_goals', owner),
      _all('goal_contributions', owner),
      _all('user_progress', owner),
    ]);
    if (epoch != _epoch || client.auth.currentUser?.id != owner) return;
    final profile = data[0] as Map<String, dynamic>;
    final nextBudgets = <String, Budget>{};
    for (final row in data[1] as List<Map<String, dynamic>>) {
      nextBudgets[(row['month'] as String).substring(0, 7)] = Budget(
        income: row['income_kopecks'] as int,
        limit: row['limit_kopecks'] as int,
        reserve: row['reserve_kopecks'] as int,
        dreams: row['dreams_kopecks'] as int,
        plannedIncome: row['planned_income_kopecks'] as int? ?? 0,
        carryForward: row['carry_forward'] == true,
        simplePlan: row['simple_plan'] == true,
      );
    }
    final nextEntries = (data[2] as List<Map<String, dynamic>>)
        .map(entryFromRow)
        .toList();
    final nextPayments = (data[3] as List<Map<String, dynamic>>)
        .map(
          (row) => PlannedPayment(
            id: row['id'] as String,
            title: row['title'] as String,
            amount: row['amount_kopecks'] as int,
            start: DateTime.parse(row['start_on'] as String),
            monthly: row['monthly'] as bool,
            reminderDays: row['reminder_days'] as int,
            reminderMinute: row['reminder_minute'] as int? ?? 540,
            repeatMinutes: row['repeat_minutes'] as int? ?? 0,
          ),
        )
        .toList();
    final nextGoals = (data[4] as List<Map<String, dynamic>>)
        .map(
          (row) => SavingGoal(
            id: row['id'] as String,
            title: row['title'] as String,
            icon: row['icon'] as String,
            target: row['target_kopecks'] as int,
            saved: row['saved_kopecks'] as int,
            weekly: row['weekly_kopecks'] as int,
            nextContribution: DateTime.parse(
              row['next_contribution_on'] as String,
            ),
          ),
        )
        .toList();
    contributions = (data[5] as List<Map<String, dynamic>>)
        .map(
          (r) => GoalContribution(
            id: r['id'] as String,
            goalId: r['goal_id'] as String,
            amount: r['amount_kopecks'] as int,
            date: DateTime.parse(r['contributed_on'] as String),
          ),
        )
        .toList();
    final progress = {
      for (final row in data[6] as List<Map<String, dynamic>>)
        row['id'] as String: row['value'] == true,
    };
    if (!_progressMigrated) {
      final legacy = {
        for (final day in checkedDays) 'day:$day': true,
        for (final badge in badges) 'badge:$badge': true,
        for (final topic in seenEducation) 'education:$topic': true,
        if (educationSkipped) 'education:skipped': true,
      };
      final missing = legacy.entries
          .where((e) => !progress.containsKey(e.key))
          .toList();
      if (missing.isNotEmpty) {
        _pending.add({
          'table': 'user_progress',
          'conflict': 'user_id,id',
          'rows': [
            for (final e in missing) {'id': e.key, 'value': e.value},
          ],
        });
        for (final e in missing) {
          progress[e.key] = e.value;
        }
      }
      _progressMigrated = true;
    }
    if (progress.isNotEmpty) {
      checkedDays = progress.entries
          .where((e) => e.key.startsWith('day:') && e.value)
          .map((e) => e.key.substring(4))
          .toSet();
      badges = progress.entries
          .where((e) => e.key.startsWith('badge:') && e.value)
          .map((e) => e.key.substring(6))
          .toSet();
      seenEducation = progress.entries
          .where(
            (e) =>
                e.key.startsWith('education:') &&
                e.key != 'education:skipped' &&
                e.value,
          )
          .map((e) => e.key.substring(10))
          .toSet();
      educationSkipped = progress['education:skipped'] == true;
    }
    name = profile['display_name'] as String;
    remindersEnabled = profile['reminders_enabled'] as bool;
    supportEnabled = profile['support_enabled'] as bool;
    budgets = nextBudgets;
    entries = nextEntries;
    payments = nextPayments;
    goals = nextGoals
        .map(
          (g) => g.withSaved(
            g.saved +
                contributions
                    .where((c) => c.goalId == g.id)
                    .fold<int>(0, (s, c) => s + c.amount),
          ),
        )
        .toList();
    setupDone = setupDone || budgets.isNotEmpty;
    if (entries.isNotEmpty) badges.add('first');
    if (goals.any((g) => g.complete)) badges.add('goal');
    if (longestStreak(checkedDays) >= 7) badges.add('week');
    await _persistCache();
    await _scheduleReminders();
  }

  static Entry entryFromRow(Map<String, dynamic> row) => Entry(
    id: row['id'] as String,
    title: row['title'] as String,
    category: row['category'] as String,
    amount: row['amount_kopecks'] as int,
    date: DateTime.parse(row['occurred_on'] as String),
    isIncome: row['kind'] == 'income',
    incomeInOpening: row['income_in_opening'] == true,
    // Keep paid reserve semantics even after the plan is deleted.
    paymentOccurrence: row['payment_on'] == null
        ? null
        : '${row['planned_payment_id'] ?? 'deleted:${row['id']}'}@${row['payment_on']}',
  );

  Future<void> refreshCloud() async {
    if (loading || refreshing || userId == null) return;
    if (!signedIn) {
      loading = true;
      await _activate(client.auth.currentUser);
      return;
    }
    refreshing = true;
    _notify();
    final epoch = _epoch, owner = userId!;
    try {
      // Serialize refresh with writes so an old response cannot undo a saved row.
      await _serialize(owner, epoch, () async {
        if (await _flushPending(owner, epoch)) {
          await _download(owner, epoch);
          if (epoch == _epoch) connectionError = null;
        }
      });
    } catch (error) {
      if (epoch == _epoch) {
        connectionError = cloudError(error);
        _offline = _networkError(error);
      }
    } finally {
      if (epoch == _epoch) {
        refreshing = false;
        _notify();
      }
    }
  }

  Future<void> _serialize(
    String owner,
    int epoch,
    Future<void> Function() action,
  ) {
    final result = _queue.then((_) async {
      _requireOwner(owner, epoch);
      await action();
    });
    _queue = result.catchError((Object _) {});
    return result;
  }

  void _requireOwner(String owner, int epoch) {
    if (epoch != _epoch ||
        userId != owner ||
        client.auth.currentUser?.id != owner) {
      throw const AuthException('Session changed', code: 'invalid_credentials');
    }
  }

  Future<void> _write(
    Future<void> Function(String owner) remote,
    void Function() commit,
  ) {
    final owner = userId, epoch = _epoch;
    if (owner == null || !signedIn) {
      return Future.error(const AuthException('Sign in required'));
    }
    return _serialize(owner, epoch, () async {
      await remote(owner);
      _requireOwner(owner, epoch);
      commit();
      connectionError = null;
      // Server data is already committed: a local preference error must not ask
      // the user to repeat a financial write that succeeded.
      try {
        await _saveLocal();
        await _persistCache();
        await _scheduleReminders();
      } catch (_) {
        /* Only UI preferences remain local. */
      }
      _notify();
    });
  }

  @override
  Future<bool> authenticate({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = name == null
        ? await client.auth.signInWithPassword(
            email: email.trim(),
            password: password,
          )
        : await client.auth.signUp(
            email: email.trim(),
            password: password,
            data: {'display_name': name.trim()},
            emailRedirectTo: CloudConfig.redirectUrl,
          );
    introduced = true;
    await preferences.setBool(_introKey, true);
    if (response.session == null) return false;
    await _activate(response.user);
    return signedIn;
  }

  @override
  Future<void> resetPassword(String email) => client.auth.resetPasswordForEmail(
    email.trim(),
    redirectTo: CloudConfig.redirectUrl,
  );

  Future<void> changeRecoveredPassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
    recoveringPassword = false;
    _notify();
  }

  @override
  Future<void> logout() async {
    await NotificationBridge.account(null);
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      if (client.auth.currentSession != null || !_networkError(e)) rethrow;
    }
    await _activate(null);
  }

  Future<void> _syncNotificationSession() async {
    final session = client.auth.currentSession;
    if (session == null || session.user.id != userId) return;
    try {
      await NotificationBridge.session(
        session.user.id,
        session.accessToken,
        session.expiresAt ?? 0,
      );
    } catch (_) {
      /* Foreground diary stays usable if the native module is unavailable. */
    }
  }

  int? _notificationRevision;
  bool _importingNotifications = false;
  Future<void> importNotification(Map<String, dynamic> notification) async {
    final owner = userId;
    if (owner == null || notification['owner'] != owner) {
      throw StateError('Аккаунт изменился');
    }
    final operation = parseBankNotification(notification['text'] as String);
    if (operation == null) throw StateError('Не удалось распознать операцию');
    final source = notification['id'] as String;
    final id = const Uuid().v5(
      Namespace.url.value,
      'kopi:notification:$owner:$source',
    );
    late Entry saved;
    await _write(
      (user) async {
        await client
            .from('transactions')
            .upsert(
              {
                'id': id,
                'user_id': user,
                'kind': operation.income ? 'income' : 'expense',
                'amount_kopecks': operation.amount,
                'title': operation.title,
                'category': operation.category,
                'occurred_on': dayKey(
                  DateTime.fromMillisecondsSinceEpoch(
                    notification['timestamp'] as int,
                  ),
                ),
                'source': 'notification',
                'source_ref': source,
              },
              onConflict: 'id',
              ignoreDuplicates: true,
            );
        saved = entryFromRow(
          await client
              .from('transactions')
              .select()
              .eq('user_id', user)
              .eq('id', id)
              .single(),
        );
      },
      () {
        entries = [...entries.where((e) => e.id != id), saved];
        badges.add('first');
      },
    );
    if (userId == owner) await NotificationBridge.ack(owner, source);
  }

  Future<void> importAutomaticNotifications() async {
    if (!NotificationBridge.supported ||
        !signedIn ||
        _importingNotifications ||
        recoveringPassword) {
      return;
    }
    final owner = userId!;
    _importingNotifications = true;
    try {
      final status = await NotificationBridge.status(owner);
      final revision = status['revision'] as int?;
      if (revision != null && revision != _notificationRevision) {
        await refreshCloud();
        if (userId != owner) return;
        if (connectionError == null) _notificationRevision = revision;
      }
      if (status['permission'] != true ||
          status['enabled'] != true ||
          status['automatic'] != true) {
        return;
      }
      for (final row in await NotificationBridge.pending(owner)) {
        if (userId != owner || !signedIn) return;
        final current = await NotificationBridge.status(owner);
        if (current['enabled'] != true ||
            current['automatic'] != true ||
            current['permission'] != true) {
          return;
        }
        if (!(current['packages'] as List).contains(row['package'])) continue;
        if (row['confirmed'] == true || row['editing'] == true) continue;
        final parsed = parseBankNotification(row['text'] as String);
        final date = DateTime.fromMillisecondsSinceEpoch(
          row['timestamp'] as int,
        );
        if (parsed != null &&
            !parsed.income &&
            !paymentsFor(
              date,
            ).any((p) => p.payment.amount == parsed.amount && !isPaid(p))) {
          await importNotification(row);
        }
      }
    } catch (_) {
      // Keep pending items for retry/review. Never acknowledge a failed write.
    } finally {
      _importingNotifications = false;
    }
  }

  @override
  Future<void> saveBudget(DateTime month, Budget? budget) async {
    if (budget == null) {
      setupDone = true;
      await _saveLocal();
      await _persistCache();
      _notify();
      return;
    }
    await _mutate(
      {
        'table': 'monthly_budgets',
        'conflict': 'user_id,month',
        'row': {
          'month': '${monthKey(month)}-01',
          'income_kopecks': budget.income,
          'limit_kopecks': budget.limit,
          'reserve_kopecks': budget.reserve,
          'dreams_kopecks': budget.dreams,
          'planned_income_kopecks': budget.plannedIncome,
          'carry_forward': budget.carryForward,
          'simple_plan': budget.simplePlan,
        },
      },
      () {
        budgets[monthKey(month)] = budget;
        setupDone = true;
      },
    );
  }

  Map<String, dynamic> _entryRow(Entry e, String owner) {
    final parts = e.paymentOccurrence?.split('@');
    return {
      'id': e.id,
      'user_id': owner,
      'kind': e.isIncome ? 'income' : 'expense',
      'amount_kopecks': e.amount,
      'title': e.title,
      'category': e.category,
      'occurred_on': dayKey(e.date),
      'income_in_opening': e.isIncome && e.incomeInOpening,
      'planned_payment_id': parts == null || parts.first.startsWith('deleted:')
          ? null
          : parts.first,
      'payment_on': parts?.last,
      if (parts != null) 'source': 'planned_payment',
    };
  }

  @override
  Future<void> addEntry(Entry entry) async {
    if (entry.amount <= 0) throw ArgumentError('Укажи сумму');
    if (entries.any((e) => e.id == entry.id)) return;
    await _mutate(
      {
        'table': 'transactions',
        'ignore': true,
        'row': _entryRow(entry, userId!),
      },
      () {
        entries.add(entry);
        badges.add('first');
      },
    );
  }

  @override
  Future<void> updateEntry(Entry entry) async {
    if (entry.amount <= 0) throw ArgumentError('Укажи сумму');
    await _mutate(
      {'table': 'transactions', 'row': _entryRow(entry, userId!)},
      () {
        entries = [...entries.where((e) => e.id != entry.id), entry];
      },
    );
  }

  @override
  Future<void> deleteEntry(String id) =>
      _mutate({'table': 'transactions', 'delete': id}, () {
        entries.removeWhere((e) => e.id == id);
      });
  @override
  Future<void> savePayment(PlannedPayment payment) => _mutate(
    {
      'table': 'planned_payments',
      'row': {
        'id': payment.id,
        'title': payment.title,
        'amount_kopecks': payment.amount,
        'start_on': dayKey(payment.start),
        'monthly': payment.monthly,
        'reminder_days': payment.reminderDays,
        'reminder_minute': payment.reminderMinute,
        'repeat_minutes': payment.repeatMinutes,
      },
    },
    () {
      payments = [...payments.where((p) => p.id != payment.id), payment];
    },
  );
  @override
  Future<void> deletePayment(String id) =>
      _mutate({'table': 'planned_payments', 'delete': id}, () {
        payments.removeWhere((p) => p.id == id);
        entries = [
          for (final e in entries)
            if (e.paymentOccurrence?.startsWith('$id@') ?? false)
              Entry(
                id: e.id,
                title: e.title,
                category: e.category,
                amount: e.amount,
                date: e.date,
                isIncome: e.isIncome,
                incomeInOpening: e.incomeInOpening,
                paymentOccurrence:
                    'deleted:${e.id}@${e.paymentOccurrence!.split('@').last}',
              )
            else
              e,
        ];
      });
  @override
  Future<void> pay(PaymentOccurrence occurrence, DateTime today) async {
    if (isPaid(occurrence)) return;
    if (occurrence.date.isAfter(dateOnly(today))) {
      throw StateError('Платёж ещё не наступил');
    }
    await addEntry(
      Entry(
        id: const Uuid().v5(
          Namespace.url.value,
          'kopi:$userId:${occurrence.key}',
        ),
        title: occurrence.payment.title,
        category: 'Платежи',
        amount: occurrence.payment.amount,
        date: dateOnly(today),
        paymentOccurrence: occurrence.key,
      ),
    );
  }

  @override
  Future<void> saveGoal(SavingGoal goal) async {
    final contributed = contributions
        .where((c) => c.goalId == goal.id)
        .fold<int>(0, (s, c) => s + c.amount);
    if (goal.saved < contributed) {
      throw ArgumentError(
        'Накоплено меньше суммы взносов. Сначала удали ошибочный взнос.',
      );
    }
    await _mutate(
      {
        'table': 'savings_goals',
        'row': {
          'id': goal.id,
          'title': goal.title,
          'icon': goal.icon,
          'target_kopecks': goal.target,
          'saved_kopecks': goal.saved - contributed,
          'weekly_kopecks': goal.weekly,
          'next_contribution_on': dayKey(goal.nextContribution),
        },
      },
      () {
        goals = [...goals.where((g) => g.id != goal.id), goal];
        if (goal.complete) badges.add('goal');
      },
    );
  }

  @override
  Future<void> deleteGoal(String id) =>
      _mutate({'table': 'savings_goals', 'delete': id}, () {
        goals.removeWhere((g) => g.id == id);
        contributions.removeWhere((c) => c.goalId == id);
      });
  @override
  Future<void> addContribution(GoalContribution contribution) async {
    final item = contribution;
    if (contributions.any((c) => c.id == item.id)) return;
    if (item.amount <= 0 || !goals.any((g) => g.id == item.goalId)) {
      throw ArgumentError('Укажи цель и сумму');
    }
    await _mutate(
      {
        'table': 'goal_contributions',
        'ignore': true,
        'row': {
          'id': item.id,
          'goal_id': item.goalId,
          'amount_kopecks': item.amount,
          'contributed_on': dayKey(item.date),
        },
      },
      () {
        contributions.add(item);
        goals = goals
            .map(
              (g) =>
                  g.id == item.goalId ? g.withSaved(g.saved + item.amount) : g,
            )
            .toList();
        if (goals.any((g) => g.complete)) badges.add('goal');
      },
    );
  }

  @override
  Future<void> deleteContribution(String id) async {
    final item = contributions.firstWhere((c) => c.id == id);
    await _mutate({'table': 'goal_contributions', 'delete': id}, () {
      contributions.removeWhere((c) => c.id == id);
      goals = goals
          .map(
            (g) => g.id == item.goalId
                ? g.withSaved(max(0, g.saved - item.amount))
                : g,
          )
          .toList();
    });
  }

  @override
  Future<void> saveProfile(String newName, String newEmail) async {
    await _write(
      (owner) async {
        if (newEmail.trim() != email) {
          await client.auth.updateUser(
            UserAttributes(email: newEmail.trim()),
            emailRedirectTo: CloudConfig.redirectUrl,
          );
          pendingEmail = newEmail.trim();
        }
        await client
            .from('profiles')
            .update({'display_name': newName.trim()})
            .eq('user_id', owner)
            .select('user_id')
            .single();
      },
      () {
        name = newName.trim();
        email = client.auth.currentUser?.email ?? email;
      },
    );
  }

  @override
  Future<void> savePreferences({bool? reminders, bool? support}) => _mutate(
    {
      'table': 'profiles',
      'conflict': 'user_id',
      'row': {
        'display_name': name,
        'reminders_enabled': reminders ?? remindersEnabled,
        'support_enabled': support ?? supportEnabled,
      },
    },
    () {
      remindersEnabled = reminders ?? remindersEnabled;
      supportEnabled = support ?? supportEnabled;
    },
  );

  Future<void> _progress(Map<String, bool> values, void Function() commit) =>
      _mutate({
        'table': 'user_progress',
        'conflict': 'user_id,id',
        'rows': [
          for (final e in values.entries) {'id': e.key, 'value': e.value},
        ],
      }, commit);
  @override
  Future<void> finishEducation(String topic, {bool skipAll = false}) async {
    if (userId == null) {
      seenEducation.add(topic);
      educationSkipped = educationSkipped || skipAll;
      await _saveLocal();
      _notify();
      return;
    }
    await _progress(
      {'education:$topic': true, if (skipAll) 'education:skipped': true},
      () {
        seenEducation.add(topic);
        educationSkipped = educationSkipped || skipAll;
      },
    );
  }

  @override
  Future<void> resetEducation() async {
    if (userId == null) {
      seenEducation = {};
      educationSkipped = false;
      await _saveLocal();
      _notify();
      return;
    }
    await _progress(
      {
        for (final topic in seenEducation) 'education:$topic': false,
        'education:skipped': false,
      },
      () {
        seenEducation = {};
        educationSkipped = false;
      },
    );
  }

  @override
  Future<void> checkToday(DateTime today) async {
    final days = {...checkedDays, dayKey(today)};
    await _progress(
      {
        'day:${dayKey(today)}': true,
        for (final badge in badges) 'badge:$badge': true,
        if (currentStreak(days, today) >= 7) 'badge:week': true,
      },
      () {
        checkedDays = days;
        if (currentStreak(days, today) >= 7) badges.add('week');
      },
    );
  }

  Map<String, dynamic> _snapshot() => {
    'progressMigrated': _progressMigrated,
    'name': name,
    'email': email,
    'setupDone': setupDone,
    'budgets': budgets.map((k, v) => MapEntry(k, v.toJson())),
    'entries': entries.map((e) => e.toJson()).toList(),
    'payments': payments.map((e) => e.toJson()).toList(),
    'goals': goals.map((e) => e.toJson()).toList(),
    'contributions': contributions.map((e) => e.toJson()).toList(),
    'checkedDays': checkedDays.toList(),
    'badges': badges.toList(),
    'seenEducation': seenEducation.toList(),
    'educationSkipped': educationSkipped,
    'remindersEnabled': remindersEnabled,
    'supportEnabled': supportEnabled,
  };
  void _restore(Map<String, dynamic> data) {
    _progressMigrated = data['progressMigrated'] == true;
    name = data['name'] as String? ?? '';
    email = data['email'] as String? ?? email;
    setupDone = data['setupDone'] == true;
    budgets = (data['budgets'] as Map).map(
      (k, v) => MapEntry(
        k as String,
        Budget.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
    );
    entries = (data['entries'] as List)
        .map((v) => Entry.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
    payments = (data['payments'] as List)
        .map(
          (v) => PlannedPayment.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList();
    goals = (data['goals'] as List)
        .map((v) => SavingGoal.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
    contributions = (data['contributions'] as List? ?? [])
        .map(
          (v) => GoalContribution.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList();
    checkedDays = (data['checkedDays'] as List).cast<String>().toSet();
    badges = (data['badges'] as List).cast<String>().toSet();
    seenEducation = (data['seenEducation'] as List).cast<String>().toSet();
    educationSkipped = data['educationSkipped'] == true;
    remindersEnabled = data['remindersEnabled'] != false;
    supportEnabled = data['supportEnabled'] != false;
  }

  bool _loadCache() {
    try {
      final source = preferences.getString(_cacheKey);
      if (source == null) return false;
      final data = jsonDecode(source) as Map<String, dynamic>;
      _restore(Map<String, dynamic>.from(data['state'] as Map));
      _pending = (data['pending'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      _failedWrites = (data['failedWrites'] as List? ?? const [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistCache() async {
    if (userId == null) return;
    if (!await preferences.setString(
      _cacheKey,
      jsonEncode({
        'state': _snapshot(),
        'pending': _pending,
        'failedWrites': _failedWrites,
      }),
    )) {
      throw StateError('Не удалось сохранить данные на устройстве');
    }
  }

  bool _networkError(Object e) =>
      e is http.ClientException ||
      e is AuthRetryableFetchException ||
      e is TimeoutException ||
      e.runtimeType.toString() == 'SocketException';
  Future<void> _send(Map<String, dynamic> command, String owner) async {
    final table = command['table'] as String;
    if (command['delete'] != null) {
      await client
          .from(table)
          .delete()
          .eq('user_id', owner)
          .eq('id', command['delete'] as String);
      return;
    }
    if (table == 'profiles') {
      await client
          .from(table)
          .update(Map<String, dynamic>.from(command['row'] as Map))
          .eq('user_id', owner)
          .select('user_id')
          .single();
      return;
    }
    final Object rows = command['rows'] != null
        ? (command['rows'] as List)
              .map(
                (v) => {
                  ...Map<String, dynamic>.from(v as Map),
                  'user_id': owner,
                },
              )
              .toList()
        : {
            ...Map<String, dynamic>.from(command['row'] as Map),
            'user_id': owner,
          };
    await client
        .from(table)
        .upsert(
          rows,
          onConflict: command['conflict'] as String? ?? 'id',
          ignoreDuplicates: command['ignore'] == true,
        );
  }

  Future<bool> _flushPending(String owner, int epoch) async {
    while (_pending.isNotEmpty) {
      _requireOwner(owner, epoch);
      final command = _pending.first;
      try {
        await _send(command, owner).timeout(const Duration(seconds: 8));
      } catch (e) {
        connectionError = cloudError(e);
        if (_networkError(e)) {
          _offline = true;
          return false;
        }
        if (_permanentWriteError(e)) {
          _pending.removeAt(0);
          _failedWrites.add({'command': command, 'error': cloudError(e)});
          // The local edit remains visible and recoverable; quarantine this
          // server-rejected command so unrelated edits can keep syncing.
          await _persistCache();
          connectionError = 'Некоторые изменения требуют проверки.';
          continue;
        }
        rethrow;
      }
      _requireOwner(owner, epoch);
      final sent = _pending.removeAt(0);
      try {
        await _persistCache();
      } catch (_) {
        _pending.insert(0, sent);
        rethrow;
      }
    }
    _offline = false;
    return true;
  }

  bool _permanentWriteError(Object error) =>
      error is PostgrestException &&
      const {
        '23502',
        '23503',
        '23505',
        '23514',
        '22P02',
        '22003',
        '42P01',
        '42703',
        '42501',
        'PGRST204',
        'PGRST205',
      }.contains(error.code);

  Future<void> retryFailedWrites() async {
    if (_failedWrites.isEmpty || userId == null) return;
    final owner = userId!, epoch = _epoch;
    await _serialize(owner, epoch, () async {
      _pending.addAll(
        _failedWrites.map(
          (item) => Map<String, dynamic>.from(item['command'] as Map),
        ),
      );
      _failedWrites = [];
      await _persistCache();
      _notify();
      try {
        final synced = await _flushPending(owner, epoch);
        connectionError = !synced
            ? 'Нет связи. Изменения пока ждут отправки.'
            : _failedWrites.isEmpty
            ? null
            : 'Некоторые изменения всё ещё требуют проверки.';
      } catch (e) {
        if (epoch == _epoch) connectionError = cloudError(e);
      }
      _notify();
    });
  }

  Future<void> _mutate(Map<String, dynamic> command, void Function() commit) {
    final owner = userId, epoch = _epoch;
    if (owner == null || !signedIn) {
      return Future.error(const AuthException('Sign in required'));
    }
    return _serialize(owner, epoch, () async {
      final before = _snapshot();
      final previous = List<Map<String, dynamic>>.of(_pending);
      commit();
      _pending.add(command);
      final newBadges = badges.difference(
        (before['badges'] as List).cast<String>().toSet(),
      );
      if (newBadges.isNotEmpty) {
        _pending.add({
          'table': 'user_progress',
          'conflict': 'user_id,id',
          'rows': [
            for (final badge in newBadges)
              {'id': 'badge:$badge', 'value': true},
          ],
        });
      }
      try {
        await _persistCache();
      } catch (_) {
        if (epoch == _epoch) {
          _restore(before);
          _pending = previous;
        }
        rethrow;
      }
      _requireOwner(owner, epoch);
      _notify();
      try {
        if (!_offline && await _flushPending(owner, epoch)) {
          connectionError = null;
          _offline = false;
        }
      } catch (e) {
        if (epoch != _epoch) rethrow;
        connectionError = cloudError(e);
        // A rejected immediate write is rolled back; offline changes remain recoverable.
        if (previous.isEmpty && _pending.contains(command)) {
          _restore(before);
          _pending = previous;
          await _persistCache();
        }
        _notify();
        if (_pending.contains(command) ||
            previous.isEmpty && _pending.isEmpty) {
          rethrow;
        }
      }
      if (epoch == _epoch) {
        await _scheduleReminders();
        _notify();
      }
    });
  }

  Future<void> _scheduleReminders() async {
    if (userId == null) return;
    try {
      await NotificationBridge.reminders(
        userId!,
        remindersEnabled,
        payments,
        entries,
      );
    } catch (_) {
      /* Permissions can be changed independently. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _authSubscription?.cancel();
    super.dispose();
  }
}
