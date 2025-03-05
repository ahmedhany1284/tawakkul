import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get/get.dart';
import 'package:live_activities/live_activities.dart';
import 'package:tawakkal/controllers/quran_reading_controller.dart';
import 'package:tawakkal/controllers/quran_settings_controller.dart';
import 'package:tawakkal/data/cache/quran_overlay_cache.dart';
import 'package:tawakkal/data/cache/quran_settings_cache.dart';
import 'package:tawakkal/data/models/quran_verse_model.dart';
import 'package:tawakkal/widgets/quran_overlay_widget.dart';

import 'dart:async';
import 'dart:io';

import 'package:workmanager/workmanager.dart';

class QuranOverlayService extends GetxService with WidgetsBindingObserver {
  // MARK: - Properties
  static QuranOverlayService get instance => Get.find<QuranOverlayService>();
  static const platform = MethodChannel('com.quran.khatma/overlay');
  Timer? _timer;
  bool _hasOverlayPermission = false;
  bool _isServiceEnabled = false;
  QuranReadingController? _quranController;
  final _overlayController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get overlayStream => _overlayController.stream;
  final _totalVerses = 6236;
  final FlutterBackgroundService _backgroundService = FlutterBackgroundService();

  // MARK: - Lifecycle Methods
  @override
  void onInit() {
    super.onInit();
    _initializeService();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    stopService();
    _overlayController.close();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  // MARK: - Initialization Methods
  Future<void> _initializeService() async {
    try {
      _quranController = Get.find<QuranReadingController>();
    } catch (e) {
      print('QuranReadingController not available yet');
    }
    await _initializeBackgroundService();
    await _loadInitialState();
    await _checkPermission();
  }

  Future<void> _loadInitialState() async {
    try {
      _isServiceEnabled = QuranSettingsCache.isOverlayEnabled();
    } catch (e) {
      print('Error loading initial state: $e');
    }
  }

  Future<void> _initializeBackgroundService() async {
    await _backgroundService.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'quran_overlay',
        initialNotificationTitle: 'تذكير القرآن',
        initialNotificationContent: 'جاري تشغيل خدمة التذكير',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: backgroundServiceStart,
        onBackground: onIosBackground,
      ),
    );
  }

  // MARK: - Permission Handling
  Future<bool> checkAndRequestPermission() async {
    if (!Platform.isAndroid) return true;
    bool hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasPermission) {
      await FlutterOverlayWindow.requestPermission();
      hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    }
    return hasPermission;
  }

  Future<bool> _ensurePermission() async {
    if (!Platform.isAndroid) return true;

    bool hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasPermission) {
      await FlutterOverlayWindow.requestPermission();
      hasPermission = await FlutterOverlayWindow.isPermissionGranted();

      if (!hasPermission) {
        print("Overlay permission not granted");
        Get.snackbar(
          'تنبيه',
          'يجب السماح بعرض النوافذ المنبثقة للتطبيق',
          duration: const Duration(seconds: 3),
        );
        return false;
      }
    }
    return true;
  }

  // MARK: - Service Control
  Future<void> startService() async {
    if (!await _ensurePermission()) return;

    await stopService();

    final settings = Get.find<QuranSettingsController>()
        .settingsModel
        .overlaySettings;

    _timer = Timer.periodic(
      Duration(minutes: settings.intervalMinutes),
          (timer) => showOverlay(),
    );

    await showOverlay();
  }
  Future<void> stopService() async {
    try {
      // Cancel timer
      _timer?.cancel();
      _timer = null;

      // Stop background service
      _backgroundService.invoke('stopService');  // Remove await since it returns void

      // Close overlay
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }

      // Update service state
      _isServiceEnabled = false;
      await QuranOverlayCache.setOverlayEnabled(false);
    } catch (e) {
      print('Error stopping service: $e');
    }
  }

  // MARK: - Overlay Display
  Future<void> showOverlay() async {
    print("ShowOverlay Method Called");
    if (!await _ensurePermission()) return;

    try {
      final settings = Get.find<QuranSettingsController>()
          .settingsModel
          .overlaySettings;

      if (settings.isPageMode) {
        await _showPageOverlay(settings);
      } else {
        await _showAyatOverlay(settings);
      }
    } catch (e) {
      print("Error in showOverlay: $e");
    }
  }

  Future<void> _showPageOverlay(QuranOverlaySettings settings) async {
    try {
      // Get next page number
      int nextPage = settings.lastDisplayedPageNumber + 1;
      if (nextPage > 604) nextPage = 1;

      // Ensure controller exists and fetch page data
      if (_quranController == null) {
        _quranController = Get.find<QuranReadingController>();
      }

      await _quranController!.fetchQuranPageData(
        pageNumber: nextPage,
        scrollToPage: false,
      );

      var pageData = _quranController!.quranPages[nextPage - 1];
      if (pageData == null) return;

      // Update page number
      settings.lastDisplayedPageNumber = nextPage;
      await QuranOverlayCache.setLastPageNumber(nextPage);

      // Show overlay
      await _showOverlayWindow();

      // Share page data
      await FlutterOverlayWindow.shareData({
        'type': 'page',
        'data': {
          'pageNumber': pageData.pageNumber,
          'surahNumber': pageData.surahNumber,
          'juzNumber': pageData.juzNumber,
          'verses': pageData.verses.map((verse) => {
            'id': verse.id,
            'surahNumber': verse.surahNumber,
            'verseNumber': verse.verseNumber,
            'words': verse.words.map((word) => {
              'id': word.id,
              'textV1': word.textV1,
              'lineNumber': word.lineNumber,
              'wordType': word.wordType,
              'verseId': word.verseId,
            }).toList(),
          }).toList(),
        }
      });
    } catch (e) {
      print("Error in _showPageOverlay: $e");
    }
  }

  Future<void> _showAyatOverlay(QuranOverlaySettings settings) async {
    List<QuranVerseModel> versesToShow = await _getNextVerses(
      settings.lastDisplayedAyatIndex,
      settings.numberOfAyat,
      false,
    );

    if (versesToShow.isEmpty) {
      settings.lastDisplayedAyatIndex = 0;
      versesToShow = await _getNextVerses(0, settings.numberOfAyat, false);
    }

    if (versesToShow.isEmpty) return;

    settings.lastDisplayedAyatIndex += versesToShow.length;
    if (settings.lastDisplayedAyatIndex >= _totalVerses) {
      settings.lastDisplayedAyatIndex = 0;
    }

    await QuranOverlayCache.setLastVerseIndex(settings.lastDisplayedAyatIndex);
    await _showOverlayWindow();

    await FlutterOverlayWindow.shareData({
      'type': 'verses',
      'data': versesToShow.map((verse) => {
        'text': verse.textUthmaniSimple,
        'info': 'سورة ${_getSurahName(verse.surahNumber)} - آية ${verse.verseNumber}',
        'surahNumber': verse.surahNumber,
        'verseNumber': verse.verseNumber,
        'pageNumber': verse.pageNumber,
        'wordType': verse.words.lastOrNull?.wordType ?? 'normal',
      }).toList(),
    });
  }

  Future<void> _showOverlayWindow() async {
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.center,
      positionGravity: PositionGravity.none,
      visibility: NotificationVisibility.visibilityPublic,
      flag: OverlayFlag.defaultFlag,
    );

    await Future.delayed(const Duration(milliseconds: 100));
  }

  // MARK: - Background Service
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void backgroundServiceStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((event) {
        service.stopSelf();
      });
    }

    service.on('showOverlay').listen((event) async {
      if (event != null && event['ayat'] != null) {
        final List<String> ayat = List<String>.from(event['ayat']);
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: "تذكير",
          overlayContent: ayat.join('\n'),
          flag: OverlayFlag.defaultFlag,
          alignment: OverlayAlignment.topCenter,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.auto,
          height: 200,
          width: WindowSize.matchParent,
        );
      }
    });
  }

  // MARK: - Helper Methods
  String _getSurahName(int surahNumber) {
    return "سورة $surahNumber";
  }

  Future<List<QuranVerseModel>> _getNextVerses(
      int startIndex,
      int count,
      bool isPageMode,
      ) async {
    try {
      if (_quranController == null) {
        print('QuranReadingController not available');
        return [];
      }

      int currentPage = (startIndex ~/ 15) + 1;
      List<QuranVerseModel> verses = [];
      int remainingCount = count;

      while (remainingCount > 0 && currentPage <= 604) {
        var pageData = _quranController!.quranPages[currentPage - 1];

        if (pageData == null) {
          await _quranController!.fetchQuranPageData(
            pageNumber: currentPage,
            scrollToPage: false,
          );
          pageData = _quranController!.quranPages[currentPage - 1];
        }

        if (pageData != null) {
          int startVerse = startIndex % 15;
          var pageVerses = pageData.verses;

          for (int i = startVerse; i < pageVerses.length && remainingCount > 0; i++) {
            verses.add(pageVerses[i]);
            remainingCount--;
          }
        }

        currentPage++;
      }

      return verses;
    } catch (e) {
      print('Error getting verses: $e');
      return [];
    }
  }

  // MARK: - Lifecycle Handling
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        try {
          if (_isServiceEnabled) {
            startService();
          }
        } catch (e) {
          print('Error in lifecycle state change: $e');
        }
        break;
      case AppLifecycleState.paused:
        break;
      default:
        break;
    }
  }

  void updateServiceState(bool isEnabled) {
    _isServiceEnabled = isEnabled;
  }

  Future<void> _checkPermission() async {
    if (Platform.isAndroid) {
      _hasOverlayPermission = await FlutterOverlayWindow.isPermissionGranted();
    }
  }
}