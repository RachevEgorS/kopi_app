# База данных «Копи» в Supabase

Готовый SQL: `migrations/202610290001_kopi_initial.sql`.
Язык — PostgreSQL SQL; функции и блок настройки прав используют PL/pgSQL.

## Как создать таблицы

1. Открой новый проект Supabase → **SQL Editor → New query**.
2. Вставь **весь** файл `202610290001_kopi_initial.sql` и нажми **Run**.
3. В Table Editor появятся пять таблиц из схемы `public`.
4. В Authentication включи вход по Email и регистрацию новых пользователей.
   При включённом подтверждении почты пользователь сначала подтверждает адрес.
   Для перехода из письма обратно в приложение нужно отдельно настроить redirect URL и Android deep link.

Скрипт выполняется один раз и рассчитан на проект без одноимённых таблиц/схемы.
Повторный запуск завершится ошибкой существующего объекта. Таблицы не удаляются.
В существующей рабочей базе нужна отдельная миграция с учётом её структуры.
Файлы из `tests/` в Supabase запускать не нужно.

## Что хранится

| Таблица | Назначение |
| --- | --- |
| `auth.users` | Уже создана Supabase: аккаунты, связанные с Auth. Вручную не заполняем. |
| `profiles` | Имя и настройки пользователя; автоматически создаётся при регистрации. |
| `transactions` | Доходы и расходы: сумма, категория, название, заметка, дата, источник. |
| `monthly_budgets` | Доход/доступные средства, лимит, резерв платежей и накоплений на месяц. |
| `planned_payments` | Разовые и ежемесячные платежи, даты и настройка напоминания. |
| `savings_goals` | Цели, выбранные иконки, накопленная сумма и план взносов. |

Email читается из `supabase.auth.currentUser?.email`. Пароли, токены и сессии
обрабатываются Supabase Auth — отдельной таблицы паролей нет.

Все суммы целые, в копейках: `45000` = **450 ₽**, `6000000` = **60 000 ₽**.
Сумма операции всегда положительная; `kind` — `income` или `expense`.
Схема рассчитана на рубли, как текущий интерфейс приложения.

`occurred_on` — дата, выбранная на устройстве; `occurred_at` — необязательный точный момент.
Месяц бюджета хранится первым числом, например `2026-10-01`.
`income_kopecks` бюджета означает уже доступные средства; доходы в `transactions`
означают дополнительные поступления. Одна зарплата не должна учитываться в обоих местах.

RLS разрешает пользователю читать и изменять только свои строки. Без входа доступа нет.
`user_id` в финансовых таблицах заполняется из активной сессии автоматически.
Профиль можно редактировать, но создать или удалить его через клиент нельзя.
Удаление аккаунта через административный Auth API удаляет его данные каскадно.
Выход из аккаунта данные не удаляет.

Удаление плана платежа сохраняет уже записанные расходы.
Уникальная пара платеж/дата не позволяет отметить один платёж дважды.
`source_ref` позволяет отсечь повторный импорт в пределах пользователя и источника.
Само чтение уведомлений, планирование напоминаний и переводы денег этот SQL не выполняет.

## Примеры для Flutter

Это примеры будущего подключения. Текущее приложение ещё использует локальное хранилище.
В проект не добавлены зависимости и реальные ключи Supabase.
При подключении установи актуальный `supabase_flutter` командой `flutter pub add supabase_flutter`.

Инициализация перед `runApp`, после `WidgetsFlutterBinding.ensureInitialized()`:

```dart
await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
);
final supabase = Supabase.instance.client;
```

URL и ключ берутся из Connect / API Keys проекта и передаются через `--dart-define`.
В мобильном приложении нужен публичный `sb_publishable_...`.
Секретный `sb_secret_...` и старый `service_role` использовать в приложении нельзя:
они обходят RLS. Имена ролей PostgreSQL `anon`, `authenticated`, `service_role`
в SQL сохраняются и при использовании новых ключей.

Регистрация — значения `email`, `password`, `name` берутся из формы:

```dart
final response = await supabase.auth.signUp(
  email: email.trim(),
  password: password,
  data: {'display_name': name.trim()},
);
if (response.session == null) {
  // Показать просьбу подтвердить почту. До активной сессии данные недоступны.
}
```

Вход и выход:

```dart
await supabase.auth.signInWithPassword(
  email: email.trim(),
  password: password,
);
// В обработчике отдельной кнопки «Выйти»:
await supabase.auth.signOut();
```

Добавление расхода **после входа**, затем отдельного дохода:

```dart
final today = DateTime.now().toIso8601String().split('T').first;
await supabase.from('transactions').insert({
  'kind': 'expense',
  'amount_kopecks': 45000,
  'title': 'Покупка в Пятёрочке',
  'category': 'Продукты',
  'occurred_on': today,
});
await supabase.from('transactions').insert({
  'kind': 'income',
  'amount_kopecks': 6000000,
  'title': 'Заработная плата',
  'category': 'Зарплата',
  'occurred_on': today,
});
```

История за текущий месяц устройства:

```dart
final now = DateTime.now();
final first = DateTime(now.year, now.month, 1);
final next = DateTime(now.year, now.month + 1, 1);
final rows = await supabase.from('transactions')
    .select()
    .gte('occurred_on', first.toIso8601String().split('T').first)
    .lt('occurred_on', next.toIso8601String().split('T').first)
    .order('occurred_on', ascending: false)
    .order('created_at', ascending: false);
```

Запросы нужно обрабатывать с `try/catch`: ошибки сети, Auth и ограничений базы показываются пользователю.
SQL Editor работает от административной роли, а не от пользователя приложения;
для него `auth.uid()` обычно NULL. Проверять изоляцию нужно через пользовательские сессии.

## Переход с текущего локального хранения

Нужно заменить работу `DiaryStore` с SharedPreferences вызовами Supabase и связать формы с Auth.
Существующие локальные ID — строки, серверные — UUID. При импорте позволяем базе создать UUID,
а старый ID операции кладём в `source_ref` с `source = 'import'`.
Для планов и целей нужно сохранить соответствие старых ID новым;
связь `paymentOccurrence` переносится в `planned_payment_id` + `payment_on`.
Отдельные флаги обучения и отметки достижений этой финансовой схемой пока не переносятся.

## Проверка

Скрипт выполнен на отдельном локальном PostgreSQL 18.
34 проверки прошли: создание профилей при регистрации и для существующих аккаунтов,
проверка сумм, ограничения дат, изоляция пользователей, защита от смены владельца,
запрет чужих связей, дедупликация, сохранение истории при удалении плана и каскадное удаление аккаунта.
Supabase Auth и JWT-контекст в тестах имитируются; облачный Auth, письма и HTTP API не тестировались.

Для повторной проверки в пустом локальном PostgreSQL последовательно выполняются
`tests/local_bootstrap.sql`, SQL-миграция и `tests/local_checks.sql`
в одной сессии `psql` с `-v ON_ERROR_STOP=1`.

Документация: [профили и Auth](https://supabase.com/docs/guides/auth/managing-user-data),
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security),
[регистрация во Flutter](https://supabase.com/docs/reference/dart/auth-signup),
[вход](https://supabase.com/docs/reference/dart/auth-signinwithpassword),
[инициализация](https://supabase.com/docs/reference/dart/initializing),
[новые ключи](https://supabase.com/docs/guides/getting-started/api-keys).
