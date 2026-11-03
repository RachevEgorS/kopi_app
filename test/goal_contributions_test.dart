import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kopi_finance_app/data/diary.dart';
import 'package:kopi_finance_app/data/progress.dart';
import 'package:kopi_finance_app/ui/goal_contributions.dart';
import 'package:kopi_finance_app/ui/design.dart';

void main() {
  testWidgets('goal screen records a contribution and shows history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = DiaryStore(await SharedPreferences.getInstance());
    store.goals = [
      SavingGoal(
        id: 'goal',
        title: 'Ноутбук',
        target: 1000000,
        saved: 0,
        weekly: 0,
        nextContribution: DateTime.now(),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: kopiTheme(),
        home: GoalContributionsScreen(store: store, goalId: 'goal'),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '500');
    await tester.ensureVisible(find.text('Пополнить мечту'));
    await tester.tap(find.text('Пополнить мечту'));
    await tester.pumpAndSettle();
    expect(store.contributions.single.amount, 50000);
    expect(store.goals.single.saved, 50000);
    expect(store.entries, isEmpty);
    expect(find.text('500 ₽'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
