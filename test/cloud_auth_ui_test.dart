import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kopi_finance_app/data/diary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kopi_finance_app/ui/screens.dart';
import 'package:kopi_finance_app/ui/design.dart';

class FormStore extends DiaryStore {
  FormStore(super.preferences);
  @override
  bool get isCloud => true;
  @override
  Future<bool> authenticate({
    required String email,
    required String password,
    String? name,
  }) async {
    if (name == null) {
      throw const AuthException('Wrong password', code: 'invalid_credentials');
    }
    return false;
  }
}

void main() {
  for (final register in [true, false]) {
    testWidgets(
      register
          ? 'Cloud signup asks for email confirmation'
          : 'Cloud login displays wrong password without demo access',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final store = FormStore(await SharedPreferences.getInstance());
        var completed = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: kopiTheme(),
            home: Scaffold(
              body: AuthScreen(
                register: register,
                store: store,
                onBack: () {},
                onSwitch: () {},
                onComplete: () {
                  completed = true;
                },
              ),
            ),
          ),
        );
        final fields = find.byType(TextFormField);
        if (register) await tester.enterText(fields.at(0), 'Анна');
        await tester.enterText(
          fields.at(register ? 1 : 0),
          'alice@example.com',
        );
        await tester.enterText(fields.at(register ? 2 : 1), 'secret123');
        final button = find.text(
          register ? 'Создать дневник' : 'Войти в дневник',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(completed, isFalse);
        expect(store.signedIn, isFalse);
        expect(find.text('Продолжить в деморежиме'), findsNothing);
        expect(
          find.text(
            register
                ? 'Проверь почту'
                : 'Почта или пароль не подходят. Проверь их и попробуй снова.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }
}
