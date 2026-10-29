import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kopi_finance_app/data/cloud_diary.dart';
import 'package:kopi_finance_app/data/diary.dart';
import 'package:kopi_finance_app/data/progress.dart';

const alice = '00000000-0000-4000-8000-000000000001';
const bob = '00000000-0000-4000-8000-000000000002';

/// Tests the real Supabase Dart client at its HTTP boundary, not a fake store.
class FakeCloud {
  final tables = <String, List<Map<String, dynamic>>>{
    'profiles': [
      for (final id in [alice, bob])
        {
          'user_id': id,
          'display_name': id == alice ? 'Аня' : 'Борис',
          'reminders_enabled': true,
          'support_enabled': true,
        },
    ],
    'monthly_budgets': [],
    'transactions': [],
    'planned_payments': [],
    'savings_goals': [],
  };
  bool failWrite = false, failRead = false, rejectLogin = false;
  bool requireConfirmation = false;
  Completer<void>? holdRead, holdWrite;
  final requests = <http.Request>[];
  late final client = SupabaseClient(
    'https://test.supabase.co',
    'test-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(handle),
  );

  Map<String, dynamic> user(String id) => {
    'id': id,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': id == alice ? 'alice@example.com' : 'bob@example.com',
    'created_at': '2026-10-29T00:00:00Z',
    'app_metadata': {},
    'user_metadata': {},
  };
  String token(String id) {
    String encode(Object data) =>
        base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
    return '${encode({'alg': 'HS256'})}.${encode({'sub': id, 'role': 'authenticated', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.test';
  }

  http.Response response(Object data, [int code = 200]) => http.Response(
    jsonEncode(data),
    code,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/logout')) return http.Response('', 204);
    if (path.endsWith('/recover')) return response({});
    if (path.endsWith('/token') || path.endsWith('/signup')) {
      if (rejectLogin)
        return response({
          'code': 'invalid_credentials',
          'message': 'Invalid login credentials',
        }, 400);
      final input = jsonDecode(request.body) as Map<String, dynamic>;
      final id = input['email'] == 'bob@example.com' ? bob : alice;
      if (path.endsWith('/signup') && requireConfirmation)
        return response(user(id));
      return response({
        'access_token': token(id),
        'refresh_token': 'refresh-$id',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': user(id),
      });
    }
    if (!path.contains('/rest/v1/'))
      throw StateError('Unexpected request: $path');
    final table = path.split('/').last;
    final rows = tables[table]!;
    final query = request.url.queryParameters;
    final owner = query['user_id']?.replaceFirst('eq.', '');
    final id = query['id']?.replaceFirst('eq.', '');
    bool matches(Map<String, dynamic> row) =>
        (owner == null || row['user_id'] == owner) &&
        (id == null || row['id'] == id);
    if (request.method == 'GET') {
      final gate = holdRead;
      holdRead = null;
      final result = rows.where(matches).map((e) => {...e}).toList();
      if (gate != null) await gate.future;
      if (failRead)
        return response({'code': 'PGRST205', 'message': 'missing table'}, 404);
      if (request.headers['accept']?.contains('object+json') ?? false) {
        return result.length == 1
            ? response(result.single)
            : response({'code': 'PGRST116', 'message': 'Not one row'}, 406);
      }
      final offset = int.tryParse(query['offset'] ?? '') ?? 0;
      final limit = int.tryParse(query['limit'] ?? '') ?? 1000;
      return response(result.skip(offset).take(limit).toList());
    }
    final gate = holdWrite;
    holdWrite = null;
    if (gate != null) await gate.future;
    if (failWrite) return response({'code': '42501', 'message': 'Denied'}, 403);
    if (request.method == 'DELETE') {
      rows.removeWhere(matches);
      return http.Response('', 204);
    }
    final values = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.method == 'POST') {
      final conflict = (query['on_conflict'] ?? 'id').split(',');
      final existing = rows
          .where(
            (row) => conflict.every(
              (key) => values[key] != null && row[key] == values[key],
            ),
          )
          .firstOrNull;
      if (existing == null)
        rows.add({...values});
      else if (!(request.headers['prefer'] ?? '').contains(
        'ignore-duplicates',
      )) {
        existing.addAll(values);
      }
      return http.Response('', 201);
    }
    final changed = rows.where(matches).toList();
    for (final row in changed) {
      row.addAll(values);
    }
    if (request.headers['accept']?.contains('object+json') ?? false) {
      return changed.length == 1
          ? response(changed.single)
          : response({'code': 'PGRST116', 'message': 'Not one row'}, 406);
    }
    return http.Response('', 204);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeCloud cloud;
  late CloudDiaryStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      DiaryStore.storageKey: 'untouched demo data',
    });
    cloud = FakeCloud();
    store = CloudDiaryStore(
      await SharedPreferences.getInstance(),
      cloud.client,
    );
    await store.start();
  });
  tearDown(() async {
    store.dispose();
    await cloud.client.dispose();
  });
  Future<void> login([String email = 'alice@example.com']) async {
    expect(
      await store.authenticate(email: email, password: 'a-password'),
      isTrue,
    );
  }

  Entry expense(String id) => Entry(
    id: id,
    title: 'Кофе',
    category: 'Кафе',
    amount: 45000,
    date: DateTime(2026, 10, 29),
  );

  test(
    'signup awaiting email does not open a diary; invalid login leaves signed out',
    () async {
      cloud.requireConfirmation = true;
      expect(
        await store.authenticate(
          email: 'alice@example.com',
          password: 'a-password',
          name: 'Аня',
        ),
        isFalse,
      );
      expect(store.signedIn, isFalse);
      expect(store.entries, isEmpty);
      cloud.rejectLogin = true;
      await expectLater(login(), throwsA(isA<AuthException>()));
      expect(store.userId, isNull);
    },
  );

  test(
    'financial CRUD survives a new store and never changes demo data',
    () async {
      await login();
      final entry = expense(store.newId());
      await store.addEntry(entry);
      await store.saveBudget(
        DateTime(2026, 10),
        const Budget(
          income: 6000000,
          limit: 5000000,
          reserve: 1100000,
          dreams: 500000,
        ),
      );
      await store.savePayment(
        PlannedPayment(
          id: store.newId(),
          title: 'Интернет',
          amount: 70000,
          start: DateTime(2026, 10, 29),
          monthly: true,
        ),
      );
      await store.saveGoal(
        SavingGoal(
          id: store.newId(),
          title: 'Ноутбук',
          target: 8000000,
          saved: 4000000,
          weekly: 200000,
          nextContribution: DateTime(2026, 10, 30),
          icon: 'laptop',
        ),
      );
      await store.savePreferences(support: false);
      store.dispose();
      store = CloudDiaryStore(
        await SharedPreferences.getInstance(),
        cloud.client,
      );
      await store.start();
      expect(store.entries.single.amount, 45000);
      expect(store.budgets['2026-10']!.income, 6000000);
      expect(store.payments.single.monthly, isTrue);
      expect(store.goals.single.saved, 4000000);
      expect(store.supportEnabled, isFalse);
      expect(
        store.preferences.getString(DiaryStore.storageKey),
        'untouched demo data',
      );
      await store.updateEntry(
        Entry(
          id: entry.id,
          title: 'Обед',
          category: 'Кафе',
          amount: 90000,
          date: entry.date,
        ),
      );
      await store.refreshCloud();
      expect(store.entries.single.amount, 90000);
      await store.deleteEntry(entry.id);
      await store.deletePayment(store.payments.single.id);
      await store.deleteGoal(store.goals.single.id);
      await store.refreshCloud();
      expect(store.entries, isEmpty);
      expect(store.payments, isEmpty);
      expect(store.goals, isEmpty);
    },
  );

  test(
    'failed writes keep saved state and a retry uses the same operation ID',
    () async {
      await login();
      final e = expense(store.newId());
      cloud.failWrite = true;
      await expectLater(store.addEntry(e), throwsA(isA<PostgrestException>()));
      expect(store.entries, isEmpty);
      cloud.failWrite = false;
      await store.addEntry(e);
      await store.addEntry(e);
      expect(store.entries, hasLength(1));
      expect(cloud.tables['transactions'], hasLength(1));
      cloud.failWrite = true;
      await expectLater(
        store.deleteEntry(e.id),
        throwsA(isA<PostgrestException>()),
      );
      expect(store.entries, hasLength(1));
    },
  );

  test(
    'account switch clears data and keeps local achievements scoped',
    () async {
      await login();
      await store.addEntry(expense(store.newId()));
      await store.checkToday(DateTime(2026, 10, 29));
      await store.logout();
      expect(store.entries, isEmpty);
      expect(store.checkedDays, isEmpty);
      await login('bob@example.com');
      expect(store.name, 'Борис');
      expect(store.entries, isEmpty);
      expect(store.checkedDays, isEmpty);
      await store.logout();
      await login();
      expect(store.entries, hasLength(1));
      expect(store.checkedDays, contains('2026-10-29'));
    },
  );

  test('late write cannot populate a different account after logout', () async {
    await login();
    final gate = cloud.holdWrite = Completer<void>();
    final write = store.addEntry(expense(store.newId()));
    final expectation = expectLater(write, throwsA(isA<AuthException>()));
    await Future<void>.delayed(Duration.zero);
    await store.logout();
    await login('bob@example.com');
    gate.complete();
    await expectation;
    expect(store.userId, bob);
    expect(store.entries, isEmpty);
    expect(cloud.tables['transactions']!.single['user_id'], alice);
  });

  test('late refresh cannot replace the next account data', () async {
    await login();
    await store.addEntry(expense(store.newId()));
    final gate = cloud.holdRead = Completer<void>();
    final refresh = store.refreshCloud();
    await Future<void>.delayed(Duration.zero);
    await store.logout();
    await login('bob@example.com');
    gate.complete();
    await refresh;
    expect(store.userId, bob);
    expect(store.name, 'Борис');
    expect(store.entries, isEmpty);
  });

  test(
    'loads more than default API page size without truncating history',
    () async {
      cloud.tables['transactions']!.addAll(
        List.generate(
          1201,
          (i) => {
            'id': 'entry-$i',
            'user_id': alice,
            'title': 'Кофе',
            'category': 'Кафе',
            'amount_kopecks': 100,
            'kind': 'expense',
            'occurred_on': '2026-10-29',
          },
        ),
      );
      await login();
      expect(store.entries, hasLength(1201));
      expect(store.spentFor(DateTime(2026, 10)), 120100);
    },
  );

  test('failed initial download can retry without logout', () async {
    cloud.failRead = true;
    await store.authenticate(
      email: 'alice@example.com',
      password: 'a-password',
    );
    expect(store.signedIn, isFalse);
    expect(store.connectionError, isNotNull);
    cloud.failRead = false;
    await store.refreshCloud();
    expect(store.signedIn, isTrue);
    expect(store.connectionError, isNull);
  });

  test(
    'marking a payment uses a stable UUID and records an expense once',
    () async {
      await login();
      final plan = PlannedPayment(
        id: store.newId(),
        title: 'Интернет',
        amount: 70000,
        start: DateTime(2026, 10, 29),
      );
      await store.savePayment(plan);
      final occurrence = plan.inMonth(DateTime(2026, 10))!;
      await store.pay(occurrence, DateTime(2026, 10, 29));
      await store.pay(occurrence, DateTime(2026, 10, 29));
      await store.refreshCloud();
      expect(store.isPaid(occurrence), isTrue);
      expect(store.entries, hasLength(1));
      expect(
        cloud.tables['transactions']!.single['planned_payment_id'],
        plan.id,
      );
    },
  );
}
