import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart' as overlay;
import 'package:tawakkal/data/models/quran_page.dart';
import 'package:tawakkal/data/models/quran_verse_model.dart';
import 'package:tawakkal/data/repository/quran_repository.dart';
import 'package:tawakkal/utils/quran_utils.dart';

import '../data/cache/quran_settings_cache.dart';



class QuranBackgroundService {
  // Essential Constants
  static const String OVERLAY_INTERVAL_KEY = 'quran_overlay_interval';
  static const String OVERLAY_ENABLED_KEY = 'quran_overlay_enabled';
  static const String OVERLAY_FONT_SIZE_KEY = 'quran_overlay_font_size';
  static const String DISPLAY_TYPE_KEY = 'quran_display_type';
  static const String ITEMS_COUNT_KEY = 'quran_items_count';

  static const String DISPLAY_TYPE_PAGE = 'page';
  static const String DISPLAY_TYPE_VERSE = 'verse';

  static const String NOTIFICATION_CHANNEL_ID = 'quran_verses';
  static const String NOTIFICATION_CHANNEL_NAME = 'Quran Verses';
  static const int NOTIFICATION_ID = 888;

  /// Initialize service
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    await _initializeDefaultSettings();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: isServiceEnabled(),
        isForegroundMode: true,
        notificationChannelId: NOTIFICATION_CHANNEL_ID,
        initialNotificationTitle: 'آيات القرآن',
        initialNotificationContent: 'جاري عرض الآيات',
        foregroundServiceNotificationId: NOTIFICATION_ID,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: isServiceEnabled(),
        onForeground: onStart,
        onBackground: (ServiceInstance service) async => true,
      ),
    );
  }

  /// Initialize default settings
  static Future<void> _initializeDefaultSettings() async {
    final prefs = QuranSettingsCache.prefs;

    if (!prefs.containsKey(OVERLAY_INTERVAL_KEY)) {
      await prefs.setInt(OVERLAY_INTERVAL_KEY, 30);
    }
    if (!prefs.containsKey(OVERLAY_ENABLED_KEY)) {
      await prefs.setBool(OVERLAY_ENABLED_KEY, false);
    }
    if (!prefs.containsKey(OVERLAY_FONT_SIZE_KEY)) {
      await prefs.setDouble(
          OVERLAY_FONT_SIZE_KEY, QuranSettingsCache.getQuranFontSize());
    }
    if (!prefs.containsKey(DISPLAY_TYPE_KEY)) {
      await prefs.setString(DISPLAY_TYPE_KEY, DISPLAY_TYPE_VERSE);
    }
    if (!prefs.containsKey(ITEMS_COUNT_KEY)) {
      await prefs.setInt(ITEMS_COUNT_KEY, 1);
    }
  }

  /// Settings Getters & Setters
  static bool isServiceEnabled() =>
      QuranSettingsCache.prefs.getBool(OVERLAY_ENABLED_KEY) ?? false;

  static int getInterval() =>
      QuranSettingsCache.prefs.getInt(OVERLAY_INTERVAL_KEY) ?? 30;

  static double getOverlayFontSize() =>
      QuranSettingsCache.prefs.getDouble(OVERLAY_FONT_SIZE_KEY) ??
          QuranSettingsCache.getQuranFontSize();

  static String getDisplayType() =>
      QuranSettingsCache.prefs.getString(DISPLAY_TYPE_KEY) ?? DISPLAY_TYPE_VERSE;

  static int getItemsCount() =>
      QuranSettingsCache.prefs.getInt(ITEMS_COUNT_KEY) ?? 1;

  static Future<void> setServiceEnabled(bool enabled) async {
    await QuranSettingsCache.prefs.setBool(OVERLAY_ENABLED_KEY, enabled);
    if (enabled) {
      await startService();
    } else {
      stopService();
    }
  }
  static Future<void> setDisplayType(String type) async {
    await QuranSettingsCache.prefs.setString(DISPLAY_TYPE_KEY, type);
    if (isServiceEnabled()) {
      await restartService();
    }
  }

  static Future<void> updateInterval(int minutes) async {
    await QuranSettingsCache.prefs.setInt(OVERLAY_INTERVAL_KEY, minutes);
    if (isServiceEnabled()) {
      await restartService();
    }
  }

  /// Service Management

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized

    final quranRepo = QuranRepository(); // Initialize your repository

    // Show initial overlay:
    if (isServiceEnabled()) {
      try {
        final random = Random();
        final pageNumber = random.nextInt(604) + 1; // Adjust range if needed
        final pageData = await quranRepo.getQuranPageData(pageNumber: pageNumber);

        if (getDisplayType() == DISPLAY_TYPE_PAGE) {
          await showOverlay(pageData: pageData);
        } else {
          final verse = pageData.verses[random.nextInt(pageData.verses.length)];
          await showOverlay(verse: verse);
        }
            } catch (e) {
      }
    }

    // Periodically update overlay:
    Timer.periodic(Duration(minutes: getInterval()), (timer) async {
      try {
        if (isServiceEnabled()) {
          final random = Random();
          final pageNumber = random.nextInt(604) + 1;
          final pageData = await quranRepo.getQuranPageData(pageNumber: pageNumber);

          if (getDisplayType() == DISPLAY_TYPE_PAGE) {
            await showOverlay(pageData: pageData);
          } else {
            final verse = pageData.verses[random.nextInt(pageData.verses.length)];
            await showOverlay(verse: verse);
          }
                }
      } catch (e) {
      }
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }
  /// Overlay Display

  static Future<void> showOverlay({
    QuranPageModel? pageData,
    QuranVerseModel? verse,
  }) async {
    try {
      if (!await FlutterOverlayWindow.isPermissionGranted()) return;

      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final fontFamily = QuranUtils.getFontNameOfQuranPage(
        pageNumber: verse?.pageNumber ?? pageData?.pageNumber ?? 1,
      );

      String overlayContent = '''
        <div style="
          padding: 16px;
          background-color: #1A1F38;
          border: 2px solid #2E3856;
          border-radius: 16px;
          direction: rtl;
        ">
          <div style="
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
          ">
            <div style="
              font-size: 24px;
              color: white;
              text-align: center;
            ">
              سورة ${verse?.surahNumber ?? pageData?.surahNumber}
            </div>
            <div style="
              color: rgba(255,255,255,0.7);
              font-size: 14px;
            ">
              الجزء ${verse?.juzNumber ?? pageData?.juzNumber} | 
              الصفحة ${verse?.pageNumber ?? pageData?.pageNumber}
            </div>
          </div>

          <div style="
            padding: 16px;
            text-align: center;
            color: white;
            font-family: '${fontFamily}';
            font-size: ${getOverlayFontSize()}px;
            line-height: 1.8;
            background-color: rgba(255,255,255,0.05);
            border-radius: 8px;
            margin: 16px 0;
          ">
            ${verse?.textUthmaniSimple ?? ''}
          </div>

          <div style="
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 8px 0;
            border-top: 1px solid rgba(255,255,255,0.1);
          ">
            <div style="color: rgba(255,255,255,0.7);">
              آية ${verse?.verseNumber ?? ''}
            </div>
            <div style="display: flex; gap: 16px;">
              <span style="color: #4CAF50;">✓</span>
              <span style="color: #2196F3;">▶</span>
              <span style="color: #FFC107;">★</span>
            </div>
          </div>
        </div>
      ''';

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        height: 300,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        positionGravity: PositionGravity.auto,
        flag: OverlayFlag.defaultFlag,
        visibility: overlay.NotificationVisibility.visibilityPublic,
        overlayContent: overlayContent,
      );
    } catch (e) {
    }
  }

  /// Test Functions
  static Future<void> showTestOverlay() async {
    try {

      if (!await FlutterOverlayWindow.isPermissionGranted()) {
        final hasPermission = await FlutterOverlayWindow.requestPermission();
        if (!hasPermission!) {
          return;
        }
      }

      // Force close any existing overlay
      try {
        await FlutterOverlayWindow.closeOverlay();
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
      }


      String overlayContent = '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            * {
              margin: 0;
              padding: 0;
              box-sizing: border-box;
            }
            body {
              width: 100%;
              height: 100%;
              background-color: rgba(26, 31, 56, 0.95);
              padding: 16px;
              border-radius: 12px;
              border: 2px solid rgba(255, 255, 255, 0.1);
            }
            .container {
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              min-height: 100px;
            }
            .text {
              color: white;
              font-size: 24px;
              text-align: center;
              line-height: 1.5;
              direction: rtl;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="text">
              بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ
            </div>
          </div>
        </body>
      </html>
    ''';


      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        height: 200,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        positionGravity: PositionGravity.auto,
        overlayContent: overlayContent,
        flag: OverlayFlag.defaultFlag ,
      );

      await Future.delayed(const Duration(seconds: 1));

      final isActive = await FlutterOverlayWindow.isActive();

      // Auto close after 5 seconds
      await Future.delayed(const Duration(seconds: 5));
      await FlutterOverlayWindow.closeOverlay();

    } catch (e) {
    }
  }
  static Future<void> checkOverlayStatus() async {
    try {
      final isPermissionGranted = await FlutterOverlayWindow.isPermissionGranted();

      final isActive = await FlutterOverlayWindow.isActive();
    } catch (e) {
    }
  }

  static Future<void> showSimpleOverlay() async {
    try {
      if (!await FlutterOverlayWindow.isPermissionGranted()) {
        await FlutterOverlayWindow.requestPermission();
        return;
      }

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        height: 100,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        positionGravity: PositionGravity.auto,
        overlayContent: '''
        <div style="
          background-color: black;
          color: white;
          padding: 20px;
          text-align: center;
          height: 100%;
          display: flex;
          align-items: center;
          justify-content: center;
        ">
          Test Overlay
        </div>
      ''',
      );
    } catch (e) {
    }
  }

  /// Service Control
  static Future<void> restartService() async {
    stopService();
    await Future.delayed(const Duration(milliseconds: 500));
    await startService();
  }

  static Future<bool> startService() async {
    try {
      return await FlutterBackgroundService().startService();
    } catch (e) {
      return false;
    }
  }

  static void stopService() {
    try {
      FlutterBackgroundService().invoke('stopService');
    } catch (e) {
    }
  }
}



