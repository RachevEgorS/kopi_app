import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kopi_finance_app/data/cloud_diary.dart';
import 'package:kopi_finance_app/ui/design.dart';
import 'package:kopi_finance_app/ui/notification_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late CloudDiaryStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = SupabaseClient(
      'https://test.supabase.co',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    store = CloudDiaryStore(await SharedPreferences.getInstance(), client)
      ..userId = 'alice';
  });
  tearDown(() async {
    store.dispose();
    await client.dispose();
  });
  testWidgets(
    'editing a proposal queues corrected fields without ordinary transaction update',
    (tester) async {
      const channel = MethodChannel('kopi/notifications');
      MethodCall? confirmation;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'confirmEdit') confirmation = call;
            return null;
          });
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: kopiTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openNotificationEditor(context, store, {
                  'owner': 'alice',
                  'id': 'event-1',
                  'text': 'Покупка 850 ₽ Пятёрочка',
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                }),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();
      expect(find.text('Запись из уведомления'), findsOneWidget);
      expect(find.text('Удалить запись'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, '850'),
        '1234,56',
      );
      await tester.ensureVisible(find.text('Сохранить изменения'));
      await tester.tap(find.text('Сохранить изменения'));
      await tester.pumpAndSettle();
      expect(confirmation?.arguments['owner'], 'alice');
      expect(confirmation?.arguments['id'], 'event-1');
      expect(confirmation?.arguments['entry']['amount'], 123456);
      expect(confirmation?.arguments['entry']['category'], 'Продукты');
      expect(store.entries, isEmpty);
      expect(
        find.text('Подтверждено. Операция ожидает отправки в дневник.'),
        findsOneWidget,
      );
    },
  );
}
