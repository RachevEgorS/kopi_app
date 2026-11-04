import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kopi_finance_app/data/diary.dart';
import 'package:kopi_finance_app/data/progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DiaryStore store;
  final october = DateTime(2026, 10);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = DiaryStore(await SharedPreferences.getInstance());
  });
  tearDown(() => store.dispose());
  test(
    'simple monthly plan counts salary once and subtracts daily purchases in full',
    () async {
      final month = DateTime(2026, 11);
      await store.saveBudget(
        month,
        const Budget(
          income: 6000000,
          limit: 99999999999,
          reserve: 0,
          dreams: 1000000,
          simplePlan: true,
        ),
      );
      await store.savePayment(
        PlannedPayment(
          id: 'credit',
          title: 'Кредит',
          amount: 1000000,
          start: DateTime(2026, 11, 10),
        ),
      );
      int todayAmount() => DailyAllowance.calculate(
        limit: 99999999999,
        spent: store.spentFor(month),
        available: store.availableFor(month),
        reserve: store.reserveFor(month),
        dreams: store.dreamsReserveFor(month, month),
        days: 30,
        spentToday: store.everydaySpentOn(month),
      ).amount;
      expect(todayAmount(), 133333);
      await store.addEntry(
        Entry(
          id: 'salary',
          title: 'Зарплата',
          category: 'Зарплата',
          amount: 6000000,
          date: month,
          isIncome: true,
        ),
      );
      expect(todayAmount(), 133333);
      await store.addEntry(
        Entry(
          id: 'coffee',
          title: 'Кофе',
          category: 'Кафе',
          amount: 50000,
          date: month,
        ),
      );
      expect(todayAmount(), 83333);
      await store.savePayment(
        PlannedPayment(
          id: 'subscription',
          title: 'Музыка',
          amount: 30000,
          start: DateTime(2026, 11, 12),
        ),
      );
      expect(todayAmount(), 82333);
      await store.addEntry(
        Entry(
          id: 'paid',
          title: 'Кредит',
          category: 'Дом',
          amount: 1000000,
          date: month,
          paymentOccurrence: store.paymentsFor(month).first.key,
        ),
      );
      expect(todayAmount(), 82333);
    },
  );
  test(
    'expected salary is not spendable and received salary is counted once',
    () async {
      await store.saveBudget(
        october,
        const Budget(
          income: 0,
          plannedIncome: 3000000,
          limit: 3000000,
          reserve: 600000,
          dreams: 0,
        ),
      );
      expect(store.availableFor(october), 0);
      await store.addEntry(
        Entry(
          id: 'salary',
          title: 'Зарплата',
          category: 'Зарплата',
          amount: 3000000,
          date: october,
          isIncome: true,
        ),
      );
      expect(store.availableFor(october), 3000000);
      expect(
        DailyAllowance.calculate(
          limit: 3000000,
          spent: 0,
          available: store.availableFor(october),
          reserve: 600000,
          dreams: 0,
          days: 30,
        ).amount,
        80000,
      );
    },
  );
  test(
    'salary already included in opening balance remains in history without doubling balance',
    () async {
      await store.saveBudget(
        october,
        const Budget(income: 3000000, limit: 3000000, reserve: 0, dreams: 0),
      );
      await store.addEntry(
        Entry(
          id: 'salary',
          title: 'Зарплата',
          category: 'Зарплата',
          amount: 3000000,
          date: october,
          isIncome: true,
          incomeInOpening: true,
        ),
      );
      expect(store.availableFor(october), 3000000);
      expect(store.entries.single.incomeInOpening, true);
    },
  );
  test(
    'carry forward deducts actual expenses and saved goal contributions only once',
    () async {
      await store.saveBudget(
        october,
        const Budget(
          income: 3000000,
          limit: 3000000,
          reserve: 600000,
          dreams: 300000,
        ),
      );
      await store.addEntry(
        Entry(
          id: 'expense',
          title: 'Продукты',
          category: 'Продукты',
          amount: 1000000,
          date: october,
        ),
      );
      await store.saveGoal(
        SavingGoal(
          id: 'goal',
          title: 'Мечта',
          target: 1000000,
          saved: 0,
          weekly: 0,
          nextContribution: october,
        ),
      );
      final contribution = GoalContribution(
        id: 'contribution',
        goalId: 'goal',
        amount: 300000,
        date: october,
      );
      await store.addContribution(contribution);
      await store.addContribution(contribution);
      expect(store.spentFor(october), 1300000);
      final summary = ExpenseAnalytics.from(
        store.entries,
        october,
        october,
        contributions: store.contributions,
      );
      expect(summary.total, store.spentFor(october));
      expect(
        summary.categories
            .singleWhere((c) => c.name == 'Взносы в мечты')
            .amount,
        300000,
      );
      expect(store.availableFor(october), 1700000);
      expect(store.dreamsReserveFor(october, october), 0);
      final november = DateTime(2026, 11);
      await store.saveBudget(
        november,
        const Budget(
          income: 0,
          carryForward: true,
          limit: 3000000,
          reserve: 0,
          dreams: 0,
        ),
      );
      expect(store.availableFor(november), 1700000);
      expect(store.spentFor(november), 0);
      await store.deleteContribution(contribution.id);
      expect(store.availableFor(november), 2000000);
      expect(store.spentFor(october), 1000000);
      expect(store.goals.single.saved, 0);
    },
  );
}
