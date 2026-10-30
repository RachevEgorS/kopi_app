import 'dart:async';
import 'dart:convert';
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
      return Future.value();
    }
    final epoch = ++_epoch;
    _clear();
    userId = user?.id;
    email = user?.email ?? '';
    loading = user != null;
    connectionError = null;
    if (user == null) recoveringPassword = false;
    _loadLocal();
    _notify();
    final task = () async {
      try {
        await NotificationBridge.account(user?.id);
        if (user == null) return;
        await _download(user.id, epoch);
        if (epoch != _epoch) return;
        signedIn = true;
        introduced = true;
        await preferences.setBool(_introKey, true);
      } catch (error) {
        if (epoch == _epoch) connectionError = cloudError(error);
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
    name = profile['display_name'] as String;
    remindersEnabled = profile['reminders_enabled'] as bool;
    supportEnabled = profile['support_enabled'] as bool;
    budgets = nextBudgets;
    entries = nextEntries;
    payments = nextPayments;
    goals = nextGoals;
    setupDone = setupDone || budgets.isNotEmpty;
    if (entries.isNotEmpty) badges.add('first');
    if (goals.any((g) => g.complete)) badges.add('goal');
    if (longestStreak(checkedDays) >= 7) badges.add('week');
  }

  static Entry entryFromRow(Map<String, dynamic> row) => Entry(
    id: row['id'] as String,
    title: row['title'] as String,
    category: row['category'] as String,
    amount: row['amount_kopecks'] as int,
    date: DateTime.parse(row['occurred_on'] as String),
    isIncome: row['kind'] == 'income',
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
        await _download(owner, epoch);
        if (epoch == _epoch) connectionError = null;
      });
    } catch (error) {
      if (epoch == _epoch) connectionError = cloudError(error);
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
    await client.auth.signOut(scope: SignOutScope.local);
    await _activate(null);
  }

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
        if (parseBankNotification(row['text'] as String) != null) {
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
      _notify();
      return;
    }
    await _write(
      (owner) async {
        await client.from('monthly_budgets').upsert({
          'user_id': owner,
          'month': '${monthKey(month)}-01',
          'income_kopecks': budget.income,
          'limit_kopecks': budget.limit,
          'reserve_kopecks': budget.reserve,
          'dreams_kopecks': budget.dreams,
        }, onConflict: 'user_id,month');
      },
      () {
        budgets[monthKey(month)] = budget;
        setupDone = true;
      },
    );
  }

  Map<String, dynamic> _entryRow(Entry e, String owner) {
    final parts = e.paymentOccurrence?.split('@');
    final paymentId = parts?.first;
    return {
      'id': e.id,
      'user_id': owner,
      'kind': e.isIncome ? 'income' : 'expense',
      'amount_kopecks': e.amount,
      'title': e.title,
      'category': e.category,
      'occurred_on': dayKey(e.date),
      if (parts != null) ...{
        'planned_payment_id': paymentId!.startsWith('deleted:')
            ? null
            : paymentId,
        'payment_on': parts.last,
        'source': 'planned_payment',
      },
    };
  }

  @override
  Future<void> addEntry(Entry entry) async {
    if (entries.any((e) => e.id == entry.id)) return;
    late Entry saved;
    await _write(
      (owner) async {
        await client
            .from('transactions')
            .upsert(
              _entryRow(entry, owner),
              onConflict: 'id',
              ignoreDuplicates: true,
            );
        saved = entryFromRow(
          await client
              .from('transactions')
              .select()
              .eq('user_id', owner)
              .eq('id', entry.id)
              .single(),
        );
      },
      () {
        entries.add(saved);
        badges.add('first');
      },
    );
  }

  @override
  Future<void> updateEntry(Entry entry) => _write(
    (owner) async {
      await client
          .from('transactions')
          .update(_entryRow(entry, owner))
          .eq('user_id', owner)
          .eq('id', entry.id)
          .select('id')
          .single();
    },
    () {
      entries = [
        for (final e in entries)
          if (e.id == entry.id) entry else e,
      ];
    },
  );

  @override
  Future<void> deleteEntry(String id) => _write(
    (owner) async {
      await client
          .from('transactions')
          .delete()
          .eq('user_id', owner)
          .eq('id', id);
    },
    () {
      entries.removeWhere((e) => e.id == id);
    },
  );

  @override
  Future<void> savePayment(PlannedPayment payment) => _write(
    (owner) async {
      await client.from('planned_payments').upsert({
        'id': payment.id,
        'user_id': owner,
        'title': payment.title,
        'amount_kopecks': payment.amount,
        'start_on': dayKey(payment.start),
        'monthly': payment.monthly,
        'reminder_days': payment.reminderDays,
      });
    },
    () {
      payments = [...payments.where((p) => p.id != payment.id), payment];
    },
  );

  @override
  Future<void> deletePayment(String id) => _write(
    (owner) async {
      await client
          .from('planned_payments')
          .delete()
          .eq('user_id', owner)
          .eq('id', id);
    },
    () {
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
              paymentOccurrence:
                  'deleted:${e.id}@${e.paymentOccurrence!.split('@').last}',
            )
          else
            e,
      ];
    },
  );

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
  Future<void> saveGoal(SavingGoal goal) => _write(
    (owner) async {
      await client.from('savings_goals').upsert({
        'id': goal.id,
        'user_id': owner,
        'title': goal.title,
        'icon': goal.icon,
        'target_kopecks': goal.target,
        'saved_kopecks': goal.saved,
        'weekly_kopecks': goal.weekly,
        'next_contribution_on': dayKey(goal.nextContribution),
      });
    },
    () {
      goals = [...goals.where((g) => g.id != goal.id), goal];
      if (goal.complete) badges.add('goal');
    },
  );

  @override
  Future<void> deleteGoal(String id) => _write(
    (owner) async {
      await client
          .from('savings_goals')
          .delete()
          .eq('user_id', owner)
          .eq('id', id);
    },
    () {
      goals.removeWhere((g) => g.id == id);
    },
  );

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
  Future<void> savePreferences({bool? reminders, bool? support}) => _write(
    (owner) async {
      await client
          .from('profiles')
          .update({
            'reminders_enabled': ?reminders,
            'support_enabled': ?support,
          })
          .eq('user_id', owner)
          .select('user_id')
          .single();
    },
    () {
      remindersEnabled = reminders ?? remindersEnabled;
      supportEnabled = support ?? supportEnabled;
    },
  );

  @override
  Future<void> finishEducation(String topic, {bool skipAll = false}) async {
    final before = {...seenEducation}, skipped = educationSkipped;
    seenEducation.add(topic);
    educationSkipped = educationSkipped || skipAll;
    try {
      await _saveLocal();
    } catch (_) {
      seenEducation = before;
      educationSkipped = skipped;
      rethrow;
    }
    _notify();
  }

  @override
  Future<void> resetEducation() async {
    final before = {...seenEducation}, skipped = educationSkipped;
    seenEducation = {};
    educationSkipped = false;
    try {
      await _saveLocal();
    } catch (_) {
      seenEducation = before;
      educationSkipped = skipped;
      rethrow;
    }
    _notify();
  }

  @override
  Future<void> checkToday(DateTime today) async {
    final before = {...checkedDays}, oldBadges = {...badges};
    checkedDays.add(dayKey(today));
    if (currentStreak(checkedDays, today) >= 7) badges.add('week');
    try {
      await _saveLocal();
    } catch (_) {
      checkedDays = before;
      badges = oldBadges;
      rethrow;
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _authSubscription?.cancel();
    super.dispose();
  }
}
