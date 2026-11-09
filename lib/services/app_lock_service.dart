import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  static const MethodChannel _channel = MethodChannel('com.jaypharma.app/kiosk');
  static const String _prefKeyKiosk = 'app_lock_kiosk_enabled';

  /// Check whether Dedicated App Lock (Kiosk Mode) is currently active
  static Future<bool> isAppLockEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localSetting = prefs.getBool(_prefKeyKiosk) ?? false;

      // On Android native, check actual lock status
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final bool? nativeStatus = await _channel.invokeMethod<bool>('isAppLockEnabled');
        if (nativeStatus != null) return nativeStatus;
      }
      return localSetting;
    } catch (_) {
      return false;
    }
  }

  /// Turn App Lock ON or OFF
  static Future<bool> setAppLockEnabled(bool enable) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyKiosk, enable);

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final methodName = enable ? 'enableAppLock' : 'disableAppLock';
        final bool? result = await _channel.invokeMethod<bool>(methodName);
        return result ?? true;
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('setAppLockEnabled error: $e');
      return false;
    }
  }

  /// Opens Android Home / Default Launcher Settings
  static Future<void> openHomeSettings() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('openHomeSettings');
      }
    } catch (e) {
      if (kDebugMode) print('openHomeSettings error: $e');
    }
  }
}

