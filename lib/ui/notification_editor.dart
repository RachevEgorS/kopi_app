import 'package:flutter/material.dart';
import '../data/cloud_diary.dart';
import '../data/diary.dart';
import '../data/notification_import.dart';
import 'finance_pages.dart';

Future<void> openNotificationEditor(
  BuildContext context,
  CloudDiaryStore store,
  Map<String, dynamic> row,
) async {
  final owner = store.userId;
  if (owner == null || row['owner'] != owner || row['confirmed'] == true) {
    return;
  }
  final parsed = parseBankNotification(row['text'] as String);
  final initial = Entry(
    id: row['id'] as String,
    title: parsed?.title ?? '',
    category: parsed?.category ?? 'Другое',
    amount: parsed?.amount ?? 0,
    date: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    isIncome: parsed?.income ?? false,
  );
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (pageContext) => Scaffold(
        appBar: AppBar(title: const Text('Проверить операцию')),
        body: SafeArea(
          child: OperationScreen(
            store: store,
            today: DateTime.now(),
            initial: initial,
            onSubmit: (entry) async {
              if (store.userId != owner) throw StateError('Аккаунт изменился');
              await NotificationBridge.confirmEdit(
                owner,
                row['id'] as String,
                entry,
              );
            },
            onComplete: () {
              Navigator.of(pageContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Подтверждено. Операция ожидает отправки в дневник.',
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
