import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawakkal/controllers/quran_settings_controller.dart';
import 'package:tawakkal/services/shared_preferences_service.dart';

class QuranOverlayCache {
  static SharedPreferences get _prefs => SharedPreferencesService.instance.prefs;

  // Existing keys
  static const String _lastVerseIndexKey = 'lastDisplayedVerseIndex';
  static const String _lastPageNumberKey = 'lastDisplayedPageNumber';
  static const String _overlayEnabledKey = 'overlayEnabled';
  static const String _overlayPageModeKey = 'overlayPageMode';
  static const String _overlayVerseCountKey = 'overlayVerseCount';
  static const String _overlayIntervalKey = 'overlayInterval';

  // New keys for background service
  static const String _lastOverlayTimeKey = 'lastOverlayTime';
  static const String _serviceActiveKey = 'serviceActive';
  static const String _nextScheduledTimeKey = 'nextScheduledTime';

  // Existing getters
  static int getLastVerseIndex() => _prefs.getInt(_lastVerseIndexKey) ?? 0;
  static int getLastPageNumber() => _prefs.getInt(_lastPageNumberKey) ?? 1;
  static bool isOverlayEnabled() => _prefs.getBool(_overlayEnabledKey) ?? false;
  static bool isPageMode() => _prefs.getBool(_overlayPageModeKey) ?? false;
  static int getVerseCount() => _prefs.getInt(_overlayVerseCountKey) ?? 5;
  static int getInterval() => _prefs.getInt(_overlayIntervalKey) ?? 10;

  // New getters for background service
  static DateTime? getLastOverlayTime() {
    final timeStr = _prefs.getString(_lastOverlayTimeKey);
    return timeStr != null ? DateTime.parse(timeStr) : null;
  }

  static bool isServiceActive() => _prefs.getBool(_serviceActiveKey) ?? false;

  static DateTime? getNextScheduledTime() {
    final timeStr = _prefs.getString(_nextScheduledTimeKey);
    return timeStr != null ? DateTime.parse(timeStr) : null;
  }

  // Existing setters
  static Future<bool> setLastVerseIndex(int index) =>
      _prefs.setInt(_lastVerseIndexKey, index);

  static Future<bool> setLastPageNumber(int pageNumber) =>
      _prefs.setInt(_lastPageNumberKey, pageNumber);

  static Future<bool> setOverlayEnabled(bool enabled) =>
      _prefs.setBool(_overlayEnabledKey, enabled);

  static Future<bool> setPageMode(bool pageMode) async {
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

  // New setters for background service
  static Future<bool> setLastOverlayTime(DateTime time) =>
      _prefs.setString(_lastOverlayTimeKey, time.toIso8601String());

  static Future<bool> setServiceActive(bool active) =>
      _prefs.setBool(_serviceActiveKey, active);

  static Future<bool> setNextScheduledTime(DateTime time) =>
      _prefs.setString(_nextScheduledTimeKey, time.toIso8601String());

  // Updated clear method
  static Future<void> clearOverlaySettings() async {
    await Future.wait([
      _prefs.remove(_lastVerseIndexKey),
      _prefs.remove(_lastPageNumberKey),
      _prefs.remove(_overlayEnabledKey),
      _prefs.remove(_overlayPageModeKey),
      _prefs.remove(_overlayVerseCountKey),
      _prefs.remove(_overlayIntervalKey),
      _prefs.remove(_lastOverlayTimeKey),
      _prefs.remove(_serviceActiveKey),
      _prefs.remove(_nextScheduledTimeKey),
    ]);
  }

  // Updated getAllSettings method
  static Map<String, dynamic> getAllSettings() {
    return {
      'lastVerseIndex': getLastVerseIndex(),
      'lastPageNumber': getLastPageNumber(),
      'enabled': isOverlayEnabled(),
      'pageMode': isPageMode(),
      'verseCount': getVerseCount(),
      'interval': getInterval(),
      'lastOverlayTime': getLastOverlayTime()?.toIso8601String(),
      'serviceActive': isServiceActive(),
      'nextScheduledTime': getNextScheduledTime()?.toIso8601String(),
    };
  }

  // Helper method to reset progress
  static Future<void> resetProgress() async {
    await Future.wait([
      setLastVerseIndex(0),
      setLastPageNumber(1),
      setLastOverlayTime(DateTime.now()),
      _updateNextScheduledTime(),
    ]);
  }

  // New method to update next scheduled time
  static Future<void> _updateNextScheduledTime() async {
    final lastTime = getLastOverlayTime() ?? DateTime.now();
    final interval = getInterval();
    final nextTime = lastTime.add(Duration(minutes: interval));
    await setNextScheduledTime(nextTime);
  }

  // Updated saveCurrentState method
  static Future<void> saveCurrentState({
    required bool isEnabled,
    required bool isPageMode,
    required int verseCount,
    required int interval,
    int? lastVerseIndex,
    int? lastPageNumber,
    DateTime? lastOverlayTime,
  }) async {
    await Future.wait([
      setOverlayEnabled(isEnabled),
      setPageMode(isPageMode),
      setVerseCount(verseCount),
      setInterval(interval),
      if (lastVerseIndex != null) setLastVerseIndex(lastVerseIndex),
      if (lastPageNumber != null) setLastPageNumber(lastPageNumber),
      if (lastOverlayTime != null) setLastOverlayTime(lastOverlayTime),
      setServiceActive(isEnabled),
      if (isEnabled) _updateNextScheduledTime(),
    ]);
  }

  // Updated getInitialSettings method
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

  // New method for background service
  static Future<void> updateOverlayTiming() async {
    await setLastOverlayTime(DateTime.now());
    await _updateNextScheduledTime();
  }

  // New method to check if it's time for next overlay
  static bool isTimeForNextOverlay() {
    final nextScheduled = getNextScheduledTime();
    if (nextScheduled == null) return true;

    return DateTime.now().isAfter(nextScheduled);
  }

  // Updated validateSettings method
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

    // Validate timing-related settings
    if (isServiceActive()) {
      final lastTime = getLastOverlayTime();
      if (lastTime == null) {
        await setLastOverlayTime(DateTime.now());
        await _updateNextScheduledTime();
      }
    }
  }
}