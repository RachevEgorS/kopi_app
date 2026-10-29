import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../data/cloud_diary.dart';
import '../data/cloud_errors.dart';
import 'design.dart';

Widget cloudShell(Widget body) => MaterialApp(
  title: 'Копи',
  debugShowCheckedModeBanner: false,
  theme: kopiTheme(),
  locale: const Locale('ru'),
  supportedLocales: const [Locale('ru')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: body,
        ),
      ),
    ),
  ),
);

class CloudStatusScreen extends StatelessWidget {
  final String? error;
  final Future<void> Function()? onRetry, onLogout;
  const CloudStatusScreen({super.key, this.error, this.onRetry, this.onLogout});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Brand(),
        const SizedBox(height: 32),
        const Flower(size: 50),
        const SizedBox(height: 24),
        Heading(
          error == null
              ? 'Открываем твой дневник'
              : 'Не получилось открыть дневник',
          align: TextAlign.center,
          size: 25,
        ),
        const SizedBox(height: 20),
        if (error == null)
          const CircularProgressIndicator()
        else ...[
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          KopiButton('Попробовать снова', onPressed: onRetry),
          if (onLogout != null)
            TextButton(
              onPressed: () async {
                try {
                  await onLogout!();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(cloudError(e))));
                  }
                }
              },
              child: const Text('Войти в другой аккаунт'),
            ),
        ],
      ],
    ),
  );
}

class RecoveryScreen extends StatefulWidget {
  final CloudDiaryStore store;
  const RecoveryScreen({super.key, required this.store});
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.changeRecoveredPassword(password.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = cloudError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Brand(),
          const SizedBox(height: 32),
          const Heading('Новый пароль'),
          const SizedBox(height: 12),
          const Text('Придумай пароль для своего дневника.'),
          const SizedBox(height: 28),
          KopiField(
            label: 'Пароль',
            controller: password,
            password: true,
            validator: (v) =>
                (v ?? '').length < 8 ? 'Нужно не менее 8 символов' : null,
          ),
          KopiField(
            label: 'Повтори пароль',
            controller: confirmation,
            password: true,
            validator: (v) => v != password.text ? 'Пароли не совпадают' : null,
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: KopiColors.error)),
          KopiButton('Сохранить пароль', onPressed: save, busy: busy),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    try {
                      await widget.store.logout();
                    } catch (e) {
                      if (mounted) setState(() => error = cloudError(e));
                    }
                  },
            child: const Text('Вернуться ко входу'),
          ),
        ],
      ),
    ),
  );
}
