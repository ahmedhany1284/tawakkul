import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawakkal/controllers/quran_settings_controller.dart';
import 'package:tawakkal/services/shared_preferences_service.dart';

class QuranOverlayCache {
  static SharedPreferences get _prefs => SharedPreferencesService.instance.prefs;

  // Keys for overlay settings
  static const String _lastVerseIndexKey = 'lastDisplayedVerseIndex';
  static const String _lastPageNumberKey = 'lastDisplayedPageNumber';
  static const String _overlayEnabledKey = 'overlayEnabled';
  static const String _overlayPageModeKey = 'overlayPageMode';
  static const String _overlayVerseCountKey = 'overlayVerseCount';
  static const String _overlayIntervalKey = 'overlayInterval';

  // Getters with default values
  static int getLastVerseIndex() => _prefs.getInt(_lastVerseIndexKey) ?? 0;

  static int getLastPageNumber() => _prefs.getInt(_lastPageNumberKey) ?? 1;

  static bool isOverlayEnabled() => _prefs.getBool(_overlayEnabledKey) ?? false;

  static bool isPageMode() => _prefs.getBool(_overlayPageModeKey) ?? false;

  static int getVerseCount() => _prefs.getInt(_overlayVerseCountKey) ?? 5;

  static int getInterval() => _prefs.getInt(_overlayIntervalKey) ?? 10;

  // Setters that return Futures
  static Future<bool> setLastVerseIndex(int index) =>
      _prefs.setInt(_lastVerseIndexKey, index);

  static Future<bool> setLastPageNumber(int pageNumber) =>
      _prefs.setInt(_lastPageNumberKey, pageNumber);

  static Future<bool> setOverlayEnabled(bool enabled) =>
      _prefs.setBool(_overlayEnabledKey, enabled);

  static Future<bool> setPageMode(bool pageMode) async {
    // When changing modes, reset the respective indices
    if (pageMode) {
      await setLastVerseIndex(0);
    } else {
      await setLastPageNumber(1);
    }
    return _prefs.setBool(_overlayPageModeKey, pageMode);
  }

  static Future<bool> setVerseCount(int count) =>
      _prefs.setInt(_overlayVerseCountKey, count);

  static Future<bool> setInterval(int minutes) =>
      _prefs.setInt(_overlayIntervalKey, minutes);

  // Method to clear all overlay settings
  static Future<void> clearOverlaySettings() async {
    await Future.wait([
      _prefs.remove(_lastVerseIndexKey),
      _prefs.remove(_lastPageNumberKey),
      _prefs.remove(_overlayEnabledKey),
      _prefs.remove(_overlayPageModeKey),
      _prefs.remove(_overlayVerseCountKey),
      _prefs.remove(_overlayIntervalKey),
    ]);
  }

  // Method to get all settings as a map
  static Map<String, dynamic> getAllSettings() {
    return {
      'lastVerseIndex': getLastVerseIndex(),
      'lastPageNumber': getLastPageNumber(),
      'enabled': isOverlayEnabled(),
      'pageMode': isPageMode(),
      'verseCount': getVerseCount(),
      'interval': getInterval(),
    };
  }

  // Helper method to reset progress
  static Future<void> resetProgress() async {
    await Future.wait([
      setLastVerseIndex(0),
      setLastPageNumber(1),
    ]);
  }

  // Method to save current state
  static Future<void> saveCurrentState({
    required bool isEnabled,
    required bool isPageMode,
    required int verseCount,
    required int interval,
    int? lastVerseIndex,
    int? lastPageNumber,
  }) async {
    await Future.wait([
      setOverlayEnabled(isEnabled),
      setPageMode(isPageMode),
      setVerseCount(verseCount),
      setInterval(interval),
      if (lastVerseIndex != null) setLastVerseIndex(lastVerseIndex),
      if (lastPageNumber != null) setLastPageNumber(lastPageNumber),
    ]);
  }

  // Method to get initial settings
  static QuranOverlaySettings getInitialSettings() {
    return QuranOverlaySettings(
      isEnabled: isOverlayEnabled(),
      isPageMode: isPageMode(),
      numberOfAyat: getVerseCount(),
      intervalMinutes: getInterval(),
      lastDisplayedAyatIndex: getLastVerseIndex(),
      lastDisplayedPageNumber: getLastPageNumber(),
    );
  }

  // Method to validate and fix settings if needed
  static Future<void> validateSettings() async {
    final verseCount = getVerseCount();
    final interval = getInterval();
    final pageMode = isPageMode();
    final lastPageNumber = getLastPageNumber();

    // Fix any invalid values
    if (verseCount <= 0 || verseCount > 20) {
      await setVerseCount(5);
    }
    if (interval <= 0 || interval > 60) {
      await setInterval(10);
    }
    if (lastPageNumber <= 0 || lastPageNumber > 604) {
      await setLastPageNumber(1);
    }
    if (pageMode) {
      final lastVerseIndex = getLastVerseIndex();
      if (lastVerseIndex < 0 || lastVerseIndex >= 6236) {
        await setLastVerseIndex(0);
      }
    }
  }
}