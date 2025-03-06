import 'dart:developer';
import 'dart:io';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get/get.dart';
import 'package:tawakkal/data/cache/quran_overlay_cache.dart';
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

  void updateTimeUnit(TimeUnit unit) {
    try {
      // Convert current value to minutes before changing unit
      final currentMinutes = selectedTimeUnit.toMinutes(_intervalValue);

      // Update unit
      selectedTimeUnit = unit;

      // Convert minutes back to new unit value
      switch (unit) {
        case TimeUnit.seconds:
          _intervalValue = currentMinutes * 60;
          break;
        case TimeUnit.minutes:
          _intervalValue = currentMinutes;
          break;
        case TimeUnit.hours:
          _intervalValue = (currentMinutes / 60).round();
          break;
        case TimeUnit.days:
          _intervalValue = (currentMinutes / (24 * 60)).round();
          break;
      }

      // Update the service and cache
      onIntervalMinutesChanged(currentMinutes);

      // Force UI update
      Get.forceAppUpdate();
      update(['timeUnit']); // Add an ID to the update
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
        _overlayService.updateServiceState(true);
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
          await _overlayService.startService();
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
        await _overlayService.stopService();
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
        await _overlayService.stopService();
        await Future.delayed(const Duration(milliseconds: 500));
        await _overlayService.startService();
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
        await _overlayService.stopService();
        await Future.delayed(const Duration(milliseconds: 500));
        await _overlayService.startService();
      }

      await _updateSettingsCache();
      update();
    } catch (e) {
      print('Error in onNumberOfAyatChanged: $e');
    }
  }

  void onIntervalMinutesChanged(int minutes) async {
    try {
      settingsModel.overlaySettings.intervalMinutes = minutes;

      // Update the interval value and time unit based on the new minutes
      if (minutes >= 24 * 60) {
        selectedTimeUnit = TimeUnit.days;
        _intervalValue = (minutes / (24 * 60)).round();
      } else if (minutes >= 60) {
        selectedTimeUnit = TimeUnit.hours;
        _intervalValue = (minutes / 60).round();
      } else if (minutes >= 1) {
        selectedTimeUnit = TimeUnit.minutes;
        _intervalValue = minutes;
      } else {
        selectedTimeUnit = TimeUnit.seconds;
        _intervalValue = minutes * 60;
      }

      // Restart service if it's running
      if (settingsModel.overlaySettings.isEnabled) {
        await _overlayService.stopService();
        await Future.delayed(const Duration(milliseconds: 500));
        await _overlayService.startService();
      }

      await _updateSettingsCache();
      update();
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
      await _overlayService.showOverlay();
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
        interval: settingsModel.overlaySettings.intervalMinutes,
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
      settingsModel.overlaySettings = QuranOverlaySettings(
        isEnabled: QuranOverlayCache.isOverlayEnabled(),
        isPageMode: QuranOverlayCache.isPageMode(),
        numberOfAyat: QuranOverlayCache.getVerseCount(),
        intervalMinutes: QuranOverlayCache.getInterval(),
        lastDisplayedAyatIndex: QuranOverlayCache.getLastVerseIndex(),
        lastDisplayedPageNumber: QuranOverlayCache.getLastPageNumber(),
        lastOverlayTime: QuranOverlayCache.getLastOverlayTime(),
      );

      // Set initial interval value and time unit
      final minutes = settingsModel.overlaySettings.intervalMinutes;
      if (minutes >= 24 * 60) {
        selectedTimeUnit = TimeUnit.days;
        _intervalValue = (minutes / (24 * 60)).round();
      } else if (minutes >= 60) {
        selectedTimeUnit = TimeUnit.hours;
        _intervalValue = (minutes / 60).round();
      } else if (minutes >= 1) {
        selectedTimeUnit = TimeUnit.minutes;
        _intervalValue = minutes;
      } else {
        selectedTimeUnit = TimeUnit.seconds;
        _intervalValue = minutes * 60;
      }

      _overlayService = Get.put(QuranOverlayService());

      // Start service if enabled and we have permission
      if (settingsModel.overlaySettings.isEnabled) {
        if (Platform.isAndroid) {
          bool hasPermission = await FlutterOverlayWindow.isPermissionGranted();
          if (hasPermission) {
            await _overlayService.startService();
          }
        } else {
          await _overlayService.startService();
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
        await _overlayService.stopService();
        await Future.delayed(const Duration(milliseconds: 500));
        await _overlayService.startService();
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
  int intervalMinutes;
  bool isEnabled;
  bool isPageMode;
  int lastDisplayedAyatIndex;
  int lastDisplayedPageNumber;
  DateTime? lastOverlayTime;

  QuranOverlaySettings({
    this.numberOfAyat = 5,
    this.numberOfPages = 1,
    this.intervalMinutes = 10,
    this.isEnabled = false,
    this.isPageMode = false,
    this.lastDisplayedAyatIndex = 0,
    this.lastDisplayedPageNumber = 0,
    this.lastOverlayTime,
  });
}