import 'dart:developer';
import 'dart:io';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get/get.dart';
import 'package:tawakkal/data/cache/quran_overlay_cache.dart';
import 'package:tawakkal/services/quran_overlay_service.dart';
import '../data/cache/quran_settings_cache.dart';
import '../data/models/quran_settings_model.dart';
import 'quran_reading_controller.dart';

class QuranSettingsController extends GetxController {
  late final QuranSettingsModel settingsModel;
  QuranReadingController? quranReadingController;
  late final QuranOverlayService _overlayService;

  // Existing methods remain the same
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

  // Updated _updateSettingsCache to include page number
  Future<void> _updateSettingsCache() async {
    // Update existing settings
    QuranSettingsCache.setMarkerColor(value: settingsModel.isMarkerColored);
    QuranSettingsCache.setQuranFontSize(fontSize: settingsModel.displayFontSize);
    QuranSettingsCache.setQuranAdaptiveView(isAdaptiveView: settingsModel.isAdaptiveView);
    QuranSettingsCache.setWordByWordListen(isWordByWord: settingsModel.wordByWordListen);

    // Update overlay settings
    await QuranOverlayCache.setOverlayEnabled(settingsModel.overlaySettings.isEnabled);
    await QuranOverlayCache.setPageMode(settingsModel.overlaySettings.isPageMode);
    await QuranOverlayCache.setVerseCount(settingsModel.overlaySettings.numberOfAyat);
    await QuranOverlayCache.setInterval(settingsModel.overlaySettings.intervalMinutes);
    await QuranOverlayCache.setLastVerseIndex(settingsModel.overlaySettings.lastDisplayedAyatIndex);
    await QuranOverlayCache.setLastPageNumber(settingsModel.overlaySettings.lastDisplayedPageNumber);

    try {
      quranReadingController = Get.find<QuranReadingController>();
      quranReadingController!.displaySettings = settingsModel;
      quranReadingController!.update();
    } catch (e) {
      log(e.toString());
    }
    update();
  }

  // Updated init method to include page number
  Future<void> init() async {
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
    );

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
  }

  @override
  void onInit() {
    super.onInit();
    init();
  }

  // Updated onOverlayEnabledChanged to handle service restart
  Future<void> onOverlayEnabledChanged(bool value) async {
    if (value) {
      bool hasPermission = await FlutterOverlayWindow.isPermissionGranted();

      if (!hasPermission) {
        await FlutterOverlayWindow.requestPermission();
        hasPermission = await FlutterOverlayWindow.isPermissionGranted();
      }

      if (hasPermission) {
        settingsModel.overlaySettings.isEnabled = true;
        // Reset indices when enabling
        settingsModel.overlaySettings.lastDisplayedAyatIndex = 0;
        settingsModel.overlaySettings.lastDisplayedPageNumber = 0;
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
  }

  // Updated onOverlayModeChanged to handle mode switching
  void onOverlayModeChanged(bool isPageMode) async {
    settingsModel.overlaySettings.isPageMode = isPageMode;
    // Reset indices when changing mode
    settingsModel.overlaySettings.lastDisplayedAyatIndex = 0;
    settingsModel.overlaySettings.lastDisplayedPageNumber = 0;

    // Restart service if it's running
    if (settingsModel.overlaySettings.isEnabled) {
      await _overlayService.stopService();
      await _overlayService.startService();
    }

    await _updateSettingsCache();
    update();
  }

  // Updated onNumberOfAyatChanged to restart service
  void onNumberOfAyatChanged(int value) async {
    settingsModel.overlaySettings.numberOfAyat = value;
    // Reset ayat index when changing count
    settingsModel.overlaySettings.lastDisplayedAyatIndex = 0;

    // Restart service if it's running and in ayat mode
    if (settingsModel.overlaySettings.isEnabled && !settingsModel.overlaySettings.isPageMode) {
      await _overlayService.stopService();
      await _overlayService.startService();
    }

    await _updateSettingsCache();
    update();
  }

  // Updated onIntervalMinutesChanged to restart service
  void onIntervalMinutesChanged(int value) async {
    settingsModel.overlaySettings.intervalMinutes = value;

    // Restart service if it's running
    if (settingsModel.overlaySettings.isEnabled) {
      await _overlayService.stopService();
      await _overlayService.startService();
    }

    await _updateSettingsCache();
    update();
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
      }

      await _overlayService.showOverlay();
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء عرض التذكير',
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<bool> checkOverlayPermission() async {
    if (Platform.isAndroid) {
      return await FlutterOverlayWindow.isPermissionGranted();
    }
    return true;
  }
}

class QuranOverlaySettings {
  int numberOfAyat;
  int intervalMinutes;
  bool isEnabled;
  bool isPageMode;
  int lastDisplayedAyatIndex;
  int lastDisplayedPageNumber;

  QuranOverlaySettings({
    this.numberOfAyat = 5,
    this.intervalMinutes = 10,
    this.isEnabled = false,
    this.isPageMode = false,
    this.lastDisplayedAyatIndex = 0,
    this.lastDisplayedPageNumber = 0,
  });
}
