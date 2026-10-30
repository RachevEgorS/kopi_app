import 'dart:async';
import 'package:flutter/material.dart';
import '../data/cloud_diary.dart';
import '../data/cloud_errors.dart';
import '../data/diary.dart';
import '../data/notification_import.dart';
import 'design.dart';
import 'notification_editor.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final CloudDiaryStore store;
  const NotificationSettingsScreen({super.key, required this.store});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool enabled = false, automatic = false, permission = false, busy = true;
  bool prompts = true, canPost = false;
  Timer? refreshTimer;
  Set<String> packages = {};
  List<Map<String, dynamic>> apps = [], pending = [];
  String? error;
  String search = '';
  late final String owner = widget.store.userId!;
  bool get current => mounted && widget.store.userId == owner;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (current &&
          !busy &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
        load();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    if (!NotificationBridge.supported) {
      setState(() => busy = false);
      return;
    }
    try {
      final status = await NotificationBridge.status(owner);
      final installed = await NotificationBridge.apps();
      final rows = await NotificationBridge.pending(owner);
      if (!current) return;
      setState(() {
        enabled = status['enabled'] == true;
        automatic = status['automatic'] == true;
        permission = status['permission'] == true;
        prompts = status['prompts'] != false;
        canPost = status['canPost'] == true;
        packages = (status['packages'] as List).cast<String>().toSet();
        apps = installed;
        pending = rows;
        busy = false;
        error = null;
      });
    } catch (_) {
      if (current) {
        setState(() {
          busy = false;
          error =
              'Не удалось открыть модуль. Полностью перезапусти приложение.';
        });
      }
    }
  }

  Future<void> configure({
    bool? active,
    bool? auto,
    Set<String>? selected,
    bool? ask,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await NotificationBridge.configure(
        owner,
        active ?? enabled,
        auto ?? automatic,
        selected ?? packages,
        prompts: ask ?? prompts,
      );
      await load();
    } catch (_) {
      if (current) {
        setState(() {
          busy = false;
          error = 'Настройка не сохранилась. Попробуй снова.';
        });
      }
    }
  }

  Future<void> act(Map<String, dynamic> row, bool save) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (save) {
        if (!await NotificationBridge.confirm(owner, row['id'] as String)) {
          throw StateError('Открой запись через «Изменить».');
        }
      } else {
        await NotificationBridge.ack(owner, row['id'] as String);
      }
      await load();
    } catch (e) {
      if (current) {
        setState(() {
          busy = false;
          error = cloudError(e);
        });
      }
    }
  }

  Future<void> edit(Map<String, dynamic> row) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final ok = await NotificationBridge.edit(owner, row['id'] as String);
      if (ok && mounted && current) {
        await openNotificationEditor(context, widget.store, row);
      }
      await load();
    } catch (_) {
      if (current) {
        setState(() {
          busy = false;
          error = 'Не удалось открыть запись. Обнови список.';
        });
      }
    }
  }

  Future<void> requestPost() async {
    setState(() => busy = true);
    try {
      await NotificationBridge.requestPost();
      await load();
    } catch (_) {
      if (current) {
        setState(() {
          busy = false;
          error = 'Разреши уведомления Копи в настройках Android.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Уведомления банков')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: !NotificationBridge.supported
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('Чтение уведомлений доступно только на Android.'),
                )
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Heading('Записи из уведомлений'),
                    const SizedBox(height: 12),
                    const Text(
                      'Копи предложит записать покупку или зачисление кнопкой в уведомлении. Подтверждённые записи ждут отправки даже без интернета. В аккаунт сохраняется только операция. Коды подтверждения пропускаются.',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      permission
                          ? 'Системный доступ включён'
                          : 'Нужен доступ к уведомлениям в Android',
                      style: const TextStyle(color: KopiColors.berry),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              try {
                                await NotificationBridge.settings();
                              } catch (_) {
                                if (current) {
                                  setState(
                                    () => error =
                                        'Открой доступ к уведомлениям в настройках Android.',
                                  );
                                }
                              }
                            },
                      child: const Text('Открыть настройки Android'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Предлагать запись в уведомлении'),
                      subtitle: const Text(
                        'Добавить, изменить или пропустить. Смахивание ничего не записывает.',
                      ),
                      value: prompts,
                      onChanged: busy || automatic
                          ? null
                          : (v) => configure(ask: v),
                    ),
                    if (prompts && !automatic) ...[
                      Text(
                        canPost
                            ? 'Показ уведомлений разрешён'
                            : 'Разреши Копи показывать предложения',
                      ),
                      if (!canPost)
                        TextButton(
                          onPressed: busy ? null : requestPost,
                          child: const Text('Разрешить уведомления Копи'),
                        ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                try {
                                  await NotificationBridge.postSettings();
                                } catch (_) {
                                  if (current) {
                                    setState(
                                      () => error =
                                          'Открой уведомления Копи в настройках Android.',
                                    );
                                  }
                                }
                              },
                        child: const Text('Настройки показа уведомлений'),
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Читать выбранные приложения'),
                      subtitle: const Text(
                        'При выключении удаляются и подтверждённые записи, которые ещё не отправлены.',
                      ),
                      value: enabled,
                      onChanged: busy ? null : (v) => configure(active: v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Добавлять автоматически'),
                      subtitle: const Text(
                        'Только распознанные рублёвые покупки и зачисления. При открытии Копи и наличии интернета. Проверь записи: форматы банков могут различаться.',
                      ),
                      value: automatic,
                      onChanged: busy || !enabled
                          ? null
                          : (v) => configure(auto: v),
                    ),
                    const SizedBox(height: 16),
                    const Heading('Приложения', size: 22),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Найти банк или приложение',
                      ),
                      onChanged: (v) =>
                          setState(() => search = v.toLowerCase()),
                    ),
                    SizedBox(
                      height: 210,
                      child: ListView(
                        children: [
                          for (final app in apps.where(
                            (a) => '${a['name']} ${a['package']}'
                                .toLowerCase()
                                .contains(search),
                          ))
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(app['name'] as String),
                              subtitle: Text(
                                app['package'] as String,
                                style: const TextStyle(fontSize: 10),
                              ),
                              value: packages.contains(app['package']),
                              onChanged: busy
                                  ? null
                                  : (v) {
                                      final next = {...packages};
                                      if (v == true) {
                                        next.add(app['package'] as String);
                                      } else {
                                        next.remove(app['package']);
                                      }
                                      configure(selected: next);
                                    },
                            ),
                        ],
                      ),
                    ),
                    if (packages.isEmpty)
                      const Text(
                        'Выбери банковские приложения. Пока ни одно не читается.',
                      ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        const Expanded(
                          child: Heading('Найденные сообщения', size: 22),
                        ),
                        IconButton(
                          onPressed: busy ? null : load,
                          tooltip: 'Обновить',
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    if (busy) const LinearProgressIndicator(),
                    if (error != null)
                      Text(
                        error!,
                        style: const TextStyle(color: KopiColors.error),
                      ),
                    if (pending.isEmpty && !busy)
                      const Text(
                        'Пока нет новых сообщений. Старые уведомления не импортируются.',
                      ),
                    for (final row in pending) _candidate(row),
                    const SizedBox(height: 24),
                    const Text(
                      'Android или банк могут скрывать текст уведомления. Переводы между своими счетами и сообщения без однозначной суммы добавляй вручную. При выходе из аккаунта чтение выключается и очередь очищается.',
                      style: TextStyle(fontSize: 12, color: KopiColors.muted),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
  Widget _candidate(Map<String, dynamic> row) {
    final parsed = parseBankNotification(row['text'] as String);
    final saved = row['payload'] as Map?;
    return Card(
      color: KopiColors.background,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              saved != null
                  ? '${saved['kind'] == 'income' ? '+' : '−'}${money(saved['amount_kopecks'] as int)} · ${saved['title']}'
                  : parsed == null
                  ? 'Нужна ручная запись'
                  : '${parsed.income ? '+' : '−'}${money(parsed.amount)} · ${parsed.title}',
            ),
            Text(
              row['package'] as String,
              style: const TextStyle(fontSize: 10, color: KopiColors.muted),
            ),
            const SizedBox(height: 8),
            Text(row['text'] as String, style: const TextStyle(fontSize: 12)),
            if (row['confirmed'] == true)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Подтверждено · ожидает отправки. Нужны интернет и действующий вход в аккаунт.',
                ),
              ),
            if (row['confirmed'] != true)
              Wrap(
                spacing: 8,
                children: [
                  if (parsed != null && row['editing'] != true)
                    TextButton(
                      onPressed: busy ? null : () => act(row, true),
                      child: const Text('Добавить в дневник'),
                    ),
                  TextButton(
                    onPressed: busy ? null : () => edit(row),
                    child: const Text('Изменить'),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => act(row, false),
                    child: const Text('Пропустить'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
