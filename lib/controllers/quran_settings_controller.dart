import 'dart:developer';
import 'dart:io';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get/get.dart';
import 'package:tawakkal/data/cache/quran_overlay_cache.dart';
import 'package:tawakkal/main.dart';
import 'package:tawakkal/services/quran_overlay_service.dart';

import '../data/cache/quran_settings_cache.dart';
import '../data/models/quran_settings_model.dart';
import '../utils/time_units.dart';
import 'quran_reading_controller.dart';

class QuranSettingsController extends GetxController {
  late final QuranSettingsModel settingsModel;
  QuranReadingController? quranReadingController;
  late final QuranOverlayService _overlayService;

  TimeUnit selectedTimeUnit = TimeUnit.minutes;
  int _intervalValue = 10;

  int getIntervalValue() {
    try {
      return _intervalValue;
    } catch (e) {
      print('Error in getIntervalValue: $e');
      return 10; // Default value
    }
  }

  void updateIntervalValue(int value) {
    try {
      _intervalValue = value;
      final minutes = selectedTimeUnit.toMinutes(value);
      onIntervalMinutesChanged(minutes);
    } catch (e) {
      print('Error in updateIntervalValue: $e');
    }
  }

  void updateTimeUnit(TimeUnit unit, {int? newValue}) {
    try {
      print('Updating time unit to: $unit');
      print(
          'Before update: selectedTimeUnit = $selectedTimeUnit, _intervalValue = $_intervalValue');

      // If a new value is provided, use it; otherwise, use the current value
      int valueToUse = newValue ?? _intervalValue;

      // Update unit
      selectedTimeUnit = unit;
      print('After setting new unit: selectedTimeUnit = $selectedTimeUnit');

      // Set the new interval value
      _intervalValue = valueToUse;
      print(
          'After setting new interval value: _intervalValue = $_intervalValue');

      // Convert the new value to minutes and update the settings
      final minutes = selectedTimeUnit.toMinutes(valueToUse);
      onIntervalMinutesChanged(minutes);

      print(
          'Before calling update: selectedTimeUnit = $selectedTimeUnit, _intervalValue = $_intervalValue');
      update(['timeUnit', 'intervalValue']);
      print(
          'After calling update: selectedTimeUnit = $selectedTimeUnit, _intervalValue = $_intervalValue');

      Get.forceAppUpdate(); // Force a full UI update
    } catch (e) {
      print('Error in updateTimeUnit: $e');
    }
  }

  // MARK: - Basic Settings Methods
  void onMarkerColorSwitched(bool value) async {
    settingsModel.isMarkerColored = value;
    await _updateSettingsCache();
    update();
  }

  void onWordByWordSwitched(bool value) async {
    settingsModel.wordByWordListen = value;
    await _updateSettingsCache();
    update();
  }

  void onDisplayFontSizeChanged(double value) async {
    settingsModel.displayFontSize = value;
    await _updateSettingsCache();
    update();
  }

  void onDisplayOptionChanged(bool isAdaptive) async {
    settingsModel.isAdaptiveView = isAdaptive;
    await _updateSettingsCache();
    update();
  }

  // MARK: - Overlay Control Methods
  Future<void> onOverlayClosed() async {
    try {
      // Update last display time and schedule next
      await QuranOverlayCache.updateOverlayTiming();

      // If service is enabled, ensure it's running
      if (settingsModel.overlaySettings.isEnabled) {
        overlayService.updateServiceState(true);
      }
    } catch (e) {
      print('Error in onOverlayClosed: $e');
    }
  }

  Future<void> onOverlayEnabledChanged(bool value) async {
    try {
      if (value) {
        bool hasPermission = await FlutterOverlayWindow.isPermissionGranted();

        if (!hasPermission) {
          await FlutterOverlayWindow.requestPermission();
          hasPermission = await FlutterOverlayWindow.isPermissionGranted();
        }

        if (hasPermission) {
          settingsModel.overlaySettings.isEnabled = true;
          // Reset indices and timing when enabling
          settingsModel.overlaySettings.lastDisplayedAyatIndex = 0;
          settingsModel.overlaySettings.lastDisplayedPageNumber = 0;
          await QuranOverlayCache.updateOverlayTiming();
          await overlayService.startService();
        } else {
          Get.snackbar(
            'تنبيه',
            'يجب السماح بعرض النوافذ المنبثقة للتطبيق لتفعيل هذه الخاصية',
            duration: const Duration(seconds: 3),
          );
          return;
        }
      } else {
        settingsModel.overlaySettings.isEnabled = false;
        await overlayService.stopService();
      }

      await _updateSettingsCache();
      update();
    } catch (e) {
      print('Error in onOverlayEnabledChanged: $e');
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء تغيير حالة التذكير',
        duration: const Duration(seconds: 3),
      );
    }
  }

  void onOverlayModeChanged(bool isPageMode) async {
    try {
      settingsModel.overlaySettings.isPageMode = isPageMode;
      // Reset indices when changing mode
      settingsModel.overlaySettings.lastDisplayedAyatIndex = 0;
      settingsModel.overlaySettings.lastDisplayedPageNumber = 0;

      // Restart service if it's running
      if (settingsModel.overlaySettings.isEnabled) {
        await overlayService.stopService();
        await Future.delayed(const Duration(milliseconds: 500));
        await overlayService.startService();
      }

      await _updateSettingsCache();
      update();
    } catch (e) {
      print('Error in onOverlayModeChanged: $e');
    }
  }

  void onNumberOfAyatChanged(int value) async {
    try {
      settingsModel.overlaySettings.numberOfAyat = value;
      // Reset ayat index when changing count
      settingsModel.overlaySettings.lastDisplayedAyatIndex = 0;

      // Restart service if it's running and in ayat mode
      if (settingsModel.overlaySettings.isEnabled &&
          !settingsModel.overlaySettings.isPageMode) {
        await overlayService.stopService();
        await Future.delayed(const Duration(milliseconds: 500));
        await overlayService.startService();
      }

      await _updateSettingsCache();
      update();
    } catch (e) {
      print('Error in onNumberOfAyatChanged: $e');
    }
  }

  void onIntervalMinutesChanged(int minutes) async {
    try {
      // Update the interval value and time unit based on the new minutes
      if (minutes >= 24 * 60) {
        selectedTimeUnit = TimeUnit.days;
        _intervalValue = (minutes / (24 * 60)).round();
      } else if (minutes >= 60) {
        selectedTimeUnit = TimeUnit.hours;
        _intervalValue = (minutes / 60).round();
      } else {
        selectedTimeUnit = TimeUnit.minutes;
        _intervalValue = minutes;
      }

      // Update settings model
      settingsModel.overlaySettings.intervalValue = _intervalValue;
      settingsModel.overlaySettings.timeUnit = selectedTimeUnit;

      // Restart service if it's running
      if (settingsModel.overlaySettings.isEnabled) {
        await overlayService.stopService();
        await Future.delayed(const Duration(milliseconds: 500));
        await overlayService.startService();
      }

      await _updateSettingsCache();
      update([
        'timeUnit',
        'intervalValue'
      ]); // Update both timeUnit and intervalValue
    } catch (e) {
      print('Error in onIntervalMinutesChanged: $e');
    }
  }

  Future<void> testOverlay() async {
    try {
      bool hasPermission = await FlutterOverlayWindow.isPermissionGranted();

      if (!hasPermission) {
        await FlutterOverlayWindow.requestPermission();
        hasPermission = await FlutterOverlayWindow.isPermissionGranted();
      }

      if (!hasPermission) {
        Get.snackbar(
          'تنبيه',
          'يجب السماح بعرض النوافذ المنبثقة للتطبيق',
          duration: const Duration(seconds: 3),
        );
        return;
      }

      bool isActive = await FlutterOverlayWindow.isActive();

      if (isActive) {
        await FlutterOverlayWindow.closeOverlay();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Don't update timing for test overlay
      await overlayService.showOverlay();
    } catch (e) {
      print('Error in testOverlay: $e');
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء عرض التذكير',
        duration: const Duration(seconds: 3),
      );
    }
  }

  // MARK: - Cache Management
  Future<void> _updateSettingsCache() async {
    try {
      // Update existing settings
      QuranSettingsCache.setMarkerColor(value: settingsModel.isMarkerColored);
      QuranSettingsCache.setQuranFontSize(
          fontSize: settingsModel.displayFontSize);
      QuranSettingsCache.setQuranAdaptiveView(
          isAdaptiveView: settingsModel.isAdaptiveView);
      QuranSettingsCache.setWordByWordListen(
          isWordByWord: settingsModel.wordByWordListen);

      // Update overlay settings with timing information
      await QuranOverlayCache.saveCurrentState(
        isEnabled: settingsModel.overlaySettings.isEnabled,
        isPageMode: settingsModel.overlaySettings.isPageMode,
        verseCount: settingsModel.overlaySettings.numberOfAyat,
        intervalValue: settingsModel.overlaySettings.intervalValue,
        timeUnit: settingsModel.overlaySettings.timeUnit,
        lastVerseIndex: settingsModel.overlaySettings.lastDisplayedAyatIndex,
        lastPageNumber: settingsModel.overlaySettings.lastDisplayedPageNumber,
        lastOverlayTime: settingsModel.overlaySettings.lastOverlayTime,
      );

      try {
        quranReadingController = Get.find<QuranReadingController>();
        quranReadingController!.displaySettings = settingsModel;
        quranReadingController!.update();
      } catch (e) {
        log('Error updating reading controller: $e');
      }

      update();
    } catch (e) {
      print('Error in _updateSettingsCache: $e');
    }
  }

  // MARK: - Lifecycle Methods
  @override
  void onInit() {
    super.onInit();
    init();
  }

  Future<void> init() async {
    try {
      settingsModel = QuranSettingsModel();
      settingsModel.isMarkerColored = QuranSettingsCache.isQuranColored();
      settingsModel.isAdaptiveView = QuranSettingsCache.isQuranAdaptiveView();
      settingsModel.displayFontSize = QuranSettingsCache.getQuranFontSize();
      settingsModel.wordByWordListen = QuranSettingsCache.isWordByWordListen();

      // Initialize overlay settings from cache
      settingsModel.overlaySettings = QuranOverlayCache.getInitialSettings();

      // Set initial interval value and time unit
      selectedTimeUnit = settingsModel.overlaySettings.timeUnit;
      _intervalValue = settingsModel.overlaySettings.intervalValue;

      // _overlayService = Get.put(QuranOverlayService());

      // Start service if enabled and we have permission
      if (settingsModel.overlaySettings.isEnabled) {
        if (Platform.isAndroid) {
          bool hasPermission = await FlutterOverlayWindow.isPermissionGranted();
          if (hasPermission) {
            await overlayService.startService();
          }
        } else {
          await overlayService.startService();
        }
      }

      update();
    } catch (e) {
      print('Error in init: $e');
    }
  }

  @override
  void onClose() {
    // Service will continue running in background if enabled
    super.onClose();
  }

  // MARK: - Helper Methods
  Future<bool> checkOverlayPermission() async {
    if (Platform.isAndroid) {
      return await FlutterOverlayWindow.isPermissionGranted();
    }
    return true;
  }

  void onNumberOfPagesChanged(int value) async {
    try {
      settingsModel.overlaySettings.numberOfPages = value;

      // Restart service if it's running and in page mode
      if (settingsModel.overlaySettings.isEnabled &&
          settingsModel.overlaySettings.isPageMode) {
        await overlayService.stopService();
        await Future.delayed(const Duration(milliseconds: 500));
        await overlayService.startService();
      }

      await _updateSettingsCache();
      update();
    } catch (e) {
      print('Error in onNumberOfPagesChanged: $e');
    }
  }
}

class QuranOverlaySettings {
  int numberOfAyat;
  int numberOfPages;
  int intervalValue;
  TimeUnit timeUnit;
  bool isEnabled;
  bool isPageMode;
  int lastDisplayedAyatIndex;
  int lastDisplayedPageNumber;
  DateTime? lastOverlayTime;

  QuranOverlaySettings({
    this.numberOfAyat = 5,
    this.numberOfPages = 1,
    this.intervalValue = 10,
    this.timeUnit = TimeUnit.minutes,
    this.isEnabled = false,
    this.isPageMode = false,
    this.lastDisplayedAyatIndex = 0,
    this.lastDisplayedPageNumber = 0,
    this.lastOverlayTime,
  });
}
