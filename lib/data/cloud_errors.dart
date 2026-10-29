import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

String cloudError(Object error) {
  if (error is AuthException) {
    return switch (error.code) {
      'invalid_credentials' =>
        'Почта или пароль не подходят. Проверь их и попробуй снова.',
      'email_not_confirmed' =>
        'Подтверди почту по ссылке в письме, затем войди.',
      'user_already_exists' || 'email_exists' =>
        'Аккаунт с такой почтой уже существует. Попробуй войти.',
      'weak_password' =>
        'Выбери более надёжный пароль: минимум 8 символов, буквы и цифры.',
      'over_email_send_rate_limit' || 'over_request_rate_limit' =>
        'Слишком много попыток. Подожди немного и попробуй снова.',
      'signup_disabled' => 'Регистрация сейчас недоступна. Попробуй позже.',
      'same_password' => 'Новый пароль должен отличаться от прежнего.',
      'otp_expired' ||
      'flow_state_expired' => 'Ссылка устарела. Запроси новое письмо.',
      _ => 'Не удалось выполнить вход. Проверь подключение и попробуй ещё раз.',
    };
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '23505' => 'Такая запись уже сохранена. Обнови дневник.',
      '23514' || '22003' => 'Проверь сумму, название и дату записи.',
      '42501' || 'PGRST301' => 'Сессия закончилась. Войди в аккаунт снова.',
      '42P01' || 'PGRST205' || 'PGRST116' =>
        'Не удалось открыть дневник: проверь настройку базы Supabase.',
      _ => 'Не удалось сохранить изменения в аккаунте. Попробуй ещё раз.',
    };
  }
  if (error is TimeoutException || error is http.ClientException) {
    return 'Нет связи с дневником. Проверь интернет и повтори попытку.';
  }
  return 'Не удалось выполнить действие. Проверь подключение и попробуй ещё раз.';
}

/// Bounds network waits, including a stalled response body. Does not retry writes.
class KopiHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner
        .send(request)
        .timeout(const Duration(seconds: 20));
    return http.StreamedResponse(
      response.stream.timeout(const Duration(seconds: 20)),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
