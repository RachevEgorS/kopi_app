import 'package:flutter/material.dart';
import '../data/diary.dart';
import '../data/progress.dart';
import 'design.dart';
import 'finance_widgets.dart';

class GoalContributionsScreen extends StatefulWidget {
  final DiaryStore store;
  final String goalId;
  const GoalContributionsScreen({
    super.key,
    required this.store,
    required this.goalId,
  });
  @override
  State<GoalContributionsScreen> createState() => _GoalContributionsState();
}

class _GoalContributionsState extends State<GoalContributionsScreen> {
  final amount = TextEditingController();
  final form = GlobalKey<FormState>();
  late String operationId = widget.store.newId();
  DateTime date = dateOnly(DateTime.now());
  bool busy = false;
  String? error;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.store.addContribution(
        GoalContribution(
          id: operationId,
          goalId: widget.goalId,
          amount: parseMoney(amount.text)!,
          date: date,
        ),
      );
      if (mounted) {
        setState(() {
          operationId = widget.store.newId();
          amount.clear();
          busy = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не удалось сохранить взнос. Попробуй ещё раз.';
        });
      }
    }
  }

  Future<void> remove(GoalContribution item) async {
    if (busy ||
        !await confirmRemoval(
          context,
          'Удалить взнос?',
          'Сумма вернётся в доступный остаток, а накопления уменьшатся.',
        ) ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.store.deleteContribution(item.id);
      if (mounted) setState(() => busy = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Не удалось удалить взнос.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Взносы в мечту')),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final goal = widget.store.goals
              .where((g) => g.id == widget.goalId)
              .firstOrNull;
          if (goal == null) return const Center(child: Text('Цель удалена'));
          final items =
              widget.store.contributions
                  .where((c) => c.goalId == goal.id)
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Heading(goal.title),
              const SizedBox(height: 12),
              Text('Накоплено ${money(goal.saved)} из ${money(goal.target)}'),
              const SizedBox(height: 12),
              const Text(
                'Запиши сумму, которую действительно отложил. Она уменьшит доступные деньги, но не попадёт в расходы. Приложение не переводит деньги.',
              ),
              const SizedBox(height: 20),
              Form(
                key: form,
                child: KopiField(
                  label: 'Сумма взноса, ₽',
                  controller: amount,
                  moneyInput: true,
                  validator: (v) => (parseMoney(v ?? '') ?? 0) > 0
                      ? null
                      : 'Введи сумму больше нуля',
                ),
              ),
              DateField(
                label: 'Дата',
                date: date,
                first: DateTime(2020),
                last: DateTime.now(),
                onChanged: (v) => setState(() => date = v),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: KopiColors.error)),
              KopiButton('Пополнить мечту', onPressed: save, busy: busy),
              const SizedBox(height: 24),
              const Heading('История взносов', size: 22),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Здесь появятся твои взносы.'),
                ),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(money(item.amount)),
                  subtitle: Text(dateLabel(item.date)),
                  trailing: IconButton(
                    tooltip: 'Удалить взнос',
                    onPressed: busy ? null : () => remove(item),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
