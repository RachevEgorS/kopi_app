import 'package:shared_preferences/shared_preferences.dart';
import 'notification_import.dart';

/// This device-level consent is independent of accounts and cloud sync.
class NotificationOnboarding {
  static const preferenceKey = 'kopi.notifications.prompted.v1';
  bool _attempted = false;

  Future<void> requestOnce(SharedPreferences preferences) async {
    if (!NotificationBridge.supported ||
        _attempted ||
        preferences.getBool(preferenceKey) == true) {
      return;
    }
    _attempted = true;
    try {
      // Persist first: a denial or app interruption must not create a prompt loop.
      if (!await preferences.setBool(preferenceKey, true)) return;
      await NotificationBridge.requestPost();
    } catch (_) {
      // A native bridge failure is not a user denial. Retry on the next launch.
      await preferences.remove(preferenceKey);
    }
  }
}
