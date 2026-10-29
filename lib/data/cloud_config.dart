import 'package:flutter/foundation.dart';

/// Public client settings. These are not server credentials; access uses Auth + RLS.
abstract final class CloudConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://plwrufctpprnfbugwrek.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ADwHyAumpVFi1JFuGiDyTg_uXUnD4pJ',
  );
  static String get redirectUrl => kIsWeb
      ? Uri.base.replace(query: '', fragment: '').toString()
      : 'ru.kopi.finance://auth-callback';
}
