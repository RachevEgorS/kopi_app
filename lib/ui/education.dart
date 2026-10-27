import 'dart:async';
import 'package:flutter/material.dart';
import '../data/diary.dart';
import 'design.dart';

const educationTopics = <String, (String, String)>{
  'welcome': (
    'Привет, это Копи',
    'Здесь можно вести расходы, планировать платежи и понемногу копить на свои мечты. Начни с регистрации или войди в свой дневник.',
  ),
  'login': (
    'С возвращением',
    'Введи почту и пароль. Если забыл пароль, нажми «Не помню пароль». Пока это демоверсия: используй вымышленные данные, настоящий вход и восстановление ещё не подключены.',
  ),
  'register': (
    'Всего три поля',
    'Имя нужно для обращения к тебе. Почта и пароль — для будущего аккаунта. Сейчас можно познакомиться с дневником на вымышленных данных: пароль не сохраняется и никуда не отправляется.',
  ),
  'budget': (
    'Сначала — твой план',
    'Укажи доступные деньги на месяц, лимит расходов, резерв на платежи и накопления. Не включай зарплату, которую ещё не получил. Эти суммы помогут рассчитать дневной ориентир. План можно изменить в профиле.',
  ),
  'diary': (
    'Сколько можно сегодня',
    'Копи учитывает лимит, уже записанные расходы, резервы на платежи и накопления. Свободная сумма делится на оставшиеся дни месяца. Покупки добавляй через «+», а все записи найдёшь в истории.',
  ),
  'history': (
    'Всё записано',
    'Смотри доходы и расходы, переключай фильтры и ищи нужную операцию по названию или категории.',
  ),
  'operation': (
    'Одна запись — один шаг',
    'Выбери доход или расход, введи сумму и категорию. После сохранения запись появится в истории.',
  ),
  'calendar': (
    'Дни без неожиданностей',
    'Точки отмечают запланированные платежи. Выбери дату, чтобы увидеть подробности или добавить напоминание.',
  ),
  'payment': (
    'Платёж под контролем',
    'Укажи сумму, дату и когда напомнить. Копи сохранит запись в календаре, но пока не отправит настоящее уведомление.',
  ),
  'subscriptions': (
    'Что списывается регулярно',
    'Здесь собраны повторяющиеся платежи. Напоминание не отменяет подписку: это нужно сделать в самом сервисе.',
  ),
  'analytics': (
    'Замечай закономерности',
    'Категории помогают понять структуру трат.',
  ),
  'goals': (
    'Для того, что важно',
    'Каждая цель — отдельная мечта с суммой и прогрессом.',
  ),
  'forecast': (
    'А если чуть больше?',
    'Ползунок показывает, как дополнительный еженедельный взнос сокращает срок. Он не переводит деньги и не создаёт взнос.',
  ),
  'achievements': (
    'Забота, а не гонка',
    'День засчитывается за проверку полноты учёта. Не нужно ничего покупать ради серии. Пропуск не отнимает уже полученные значки.',
  ),
  'profile': (
    'Всё под тебя',
    'Здесь можно изменить имя, настроить подсказки и напоминания.',
  ),
};

/// Owns the first-visit prompt without resetting the state of the screen below it.
class EducationHost extends StatefulWidget {
  final DiaryStore store;
  final String topic;
  final Widget child;
  const EducationHost({
    super.key,
    required this.store,
    required this.topic,
    required this.child,
  });
  static VoidCallback? helpOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EducationAccess>()?.onHelp;
  @override
  State<EducationHost> createState() => _EducationHostState();
}

class _EducationHostState extends State<EducationHost> {
  Timer? timer;
  bool showing = false;
  @override
  void initState() {
    super.initState();
    schedule();
  }

  @override
  void didUpdateWidget(covariant EducationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topic != widget.topic) schedule();
  }

  void schedule() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (!widget.store.educationSkipped &&
          !widget.store.seenEducation.contains(widget.topic)) {
        show();
      }
    });
  }

  Future<void> show() async {
    if (showing || !mounted) return;
    showing = true;
    final topic = widget.topic;
    FocusManager.instance.primaryFocus?.unfocus();
    final skip = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KopiColors.background,
      barrierColor: Colors.black.withValues(alpha: .22),
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => EducationCard(topic: topic),
    );
    try {
      await widget.store.finishEducation(topic, skipAll: skip == true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Не получилось сохранить настройку обучения. Подсказка может появиться снова.',
            ),
          ),
        );
      }
    } finally {
      showing = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _EducationAccess(onHelp: show, child: widget.child);
}

class _EducationAccess extends InheritedWidget {
  final VoidCallback onHelp;
  const _EducationAccess({required this.onHelp, required super.child});
  @override
  bool updateShouldNotify(_EducationAccess oldWidget) =>
      oldWidget.onHelp != onHelp;
}

class EducationCard extends StatelessWidget {
  final String topic;
  const EducationCard({super.key, required this.topic});
  @override
  Widget build(BuildContext context) {
    final content = educationTopics[topic] ?? educationTopics['welcome']!;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (MediaQuery.sizeOf(context).height * .45).clamp(
              340,
              470,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Heading(content.$1, size: 21)),
                    IconButton(
                      key: const ValueKey('education-close'),
                      tooltip: 'Закрыть подсказку',
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Flower(size: 32),
                const SizedBox(height: 30),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 70),
                  child: Center(
                    child: Text(
                      content.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.65,
                        color: KopiColors.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                KopiButton(
                  'Теперь понятно',
                  onPressed: () => Navigator.pop(context, false),
                ),
                const SizedBox(height: 6),
                Tooltip(
                  message: 'Пропустить всё обучение',
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Пропустить',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
