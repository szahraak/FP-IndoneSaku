import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class CrashlyticsService {
  static final _crashlytics = FirebaseCrashlytics.instance;

  /// Panggil setelah user berhasil login
  static Future<void> setUser(String userId, String email) async {
    await _crashlytics.setUserIdentifier(userId);
    await _crashlytics.setCustomKey('email', email);
  }

  /// Panggil saat user logout
  static Future<void> clearUser() async {
    await _crashlytics.setUserIdentifier('');
    await _crashlytics.setCustomKey('email', '');
  }

  /// Log error non-fatal (misal: gagal fetch data, timeout, dsb.)
  static Future<void> logError(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    await _crashlytics.recordError(
      error,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }

  /// Log pesan informatif (muncul di Crashlytics log trail)
  static Future<void> log(String message) async {
    await _crashlytics.log(message);
  }

  /// Tambah konteks tambahan ke setiap laporan crash
  static Future<void> setCustomKey(String key, Object value) async {
    await _crashlytics.setCustomKey(key, value);
  }
}