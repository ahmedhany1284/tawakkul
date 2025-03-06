import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get/get.dart';
import 'package:tawakkal/controllers/quran_reading_controller.dart';
import 'package:tawakkal/controllers/quran_settings_controller.dart';
import 'package:tawakkal/data/cache/quran_overlay_cache.dart';
import 'package:tawakkal/data/cache/quran_settings_cache.dart';
import 'package:tawakkal/data/models/quran_verse_model.dart';

import 'dart:io';

class QuranOverlayService extends GetxService with WidgetsBindingObserver {
  // Constants
  static const String NOTIFICATION_CHANNEL_ID = 'quran_overlay_channel';
  static const int NOTIFICATION_ID = 888;
  static const platform = MethodChannel('com.quran.khatma/overlay');
  static const int _totalVerses = 6236;

  // Static instance
  static QuranOverlayService get instance => Get.find<QuranOverlayService>();

  // Properties
  Timer? _timer;
  bool _isServiceEnabled = false;
  QuranReadingController? _quranController;
  final _overlayController = StreamController<List<String>>.broadcast();
  final FlutterBackgroundService _backgroundService = FlutterBackgroundService();
  DateTime? _lastOverlayCloseTime;

  // Getters
  Stream<List<String>> get overlayStream => _overlayController.stream;
  bool get isServiceEnabled => _isServiceEnabled;

  // MARK: - Lifecycle Methods
  @override
  void onInit() {
    super.onInit();
    initializeService();
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
  Future<void> initializeService() async {
    try {
      _quranController = Get.find<QuranReadingController>();
      await _initializeBackgroundService();
      await _loadInitialState();
      await _checkPermission();
    } catch (e) {
      print('Error initializing service: $e');
    }
  }

  Future<void> _loadInitialState() async {
    try {
      _isServiceEnabled = QuranOverlayCache.isOverlayEnabled();
      _lastOverlayCloseTime = QuranOverlayCache.getLastOverlayTime();
      if (_isServiceEnabled) {
        await startService();
      }
    } catch (e) {
      print('Error loading initial state: $e');
    }
  }

  Future<void> _initializeBackgroundService() async {
    try {
      await _backgroundService.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: backgroundServiceFunction,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: NOTIFICATION_CHANNEL_ID,
          initialNotificationTitle: 'تذكير القرآن',
          initialNotificationContent: 'جاري تشغيل خدمة التذكير',
          foregroundServiceNotificationId: NOTIFICATION_ID,
          autoStartOnBoot: true,

        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: backgroundServiceFunction,
          onBackground: onIosBackground,
        ),
      );
    } catch (e) {
      print('Error initializing background service: $e');
    }
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

    try {
      // Stop existing service first
      await stopService();
      await Future.delayed(const Duration(milliseconds: 500));

      // Update service state
      _isServiceEnabled = true;
      await QuranOverlayCache.setServiceActive(true);
      await QuranOverlayCache.updateOverlayTiming();

      // Start background service
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        service.startService();
      }

      // Cancel existing timer if any
      _timer?.cancel();

      // Set up new timer
      final settings = Get.find<QuranSettingsController>().settingsModel.overlaySettings;
      _timer = Timer.periodic(
        Duration(minutes: settings.intervalMinutes),
            (timer) async {
          try {
            await showOverlay();
          } catch (e) {
            print('Error showing overlay: $e');
          }
        },
      );

      // Show initial overlay after a delay
      await Future.delayed(const Duration(seconds: 1));
      await showOverlay();
    } catch (e) {
      print('Error starting service: $e');
      _isServiceEnabled = false;
      await QuranOverlayCache.setServiceActive(false);
    }
  }
  Future<void> stopService() async {
    try {
      // Cancel local timer
      _timer?.cancel();
      _timer = null;

      // Close any active overlay
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }

      // Stop background service
      final service = FlutterBackgroundService();
      bool isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke('stopService');
      }

      // Update state
      _isServiceEnabled = false;
      await QuranOverlayCache.setServiceActive(false);
      await QuranOverlayCache.setOverlayEnabled(false);
    } catch (e) {
      print('Error stopping service: $e');
    }
  }
  Future<void> showOverlay() async {
    if (!await _ensurePermission()) return;

    try {
      final settings = Get.find<QuranSettingsController>().settingsModel.overlaySettings;

      if (settings.isPageMode) {
        // Get multiple pages if specified
        List<Map<String, dynamic>> pages = [];
        for (int i = 0; i < settings.numberOfPages; i++) {
          int nextPage = settings.lastDisplayedPageNumber + i + 1;
          if (nextPage > 604) nextPage = 1; // Reset to first page if exceeded

          await _quranController!.fetchQuranPageData(
            pageNumber: nextPage,
            scrollToPage: false,
          );

          var pageData = _quranController!.quranPages[nextPage - 1];
          if (pageData != null) {
            pages.add({
              'pageNumber': pageData.pageNumber,
              'surahNumber': pageData.surahNumber,
              'juzNumber': pageData.juzNumber,
              'verses': pageData.verses,
            });
          }
        }

        // Update last displayed page
        settings.lastDisplayedPageNumber =
            (settings.lastDisplayedPageNumber + settings.numberOfPages) % 604;
        await QuranOverlayCache.setLastPageNumber(settings.lastDisplayedPageNumber);

        // Show overlay with multiple pages
        await _showOverlayWindow();
        await FlutterOverlayWindow.shareData({
          'type': 'pages',
          'data': pages,
        });
      } else {
        // Get multiple verses if specified
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
    } catch (e) {
      print('Error showing overlay: $e');
    }
  }  Future<void> _showPageOverlay(QuranOverlaySettings settings) async {
    try {
      int nextPage = settings.lastDisplayedPageNumber + 1;
      if (nextPage > 604) nextPage = 1;

      if (_quranController == null) {
        _quranController = Get.find<QuranReadingController>();
      }

      await _quranController!.fetchQuranPageData(
        pageNumber: nextPage,
        scrollToPage: false,
      );

      var pageData = _quranController!.quranPages[nextPage - 1];
      if (pageData == null) return;

      settings.lastDisplayedPageNumber = nextPage;
      await QuranOverlayCache.setLastPageNumber(nextPage);

      await _showOverlayWindow();

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
      print('Error showing page overlay: $e');
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
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await FlutterOverlayWindow.showOverlay(
        enableDrag: false ,
        height: WindowSize.matchParent,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.bottomCenter,
        positionGravity: PositionGravity.none,
        visibility: NotificationVisibility.visibilityPublic,
        flag: OverlayFlag.defaultFlag,
      );

      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('Error showing overlay window: $e');
    }
  }

  // MARK: - Background Service
  @pragma('vm:entry-point')
  static void backgroundServiceFunction(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    try {
      if (service is AndroidServiceInstance) {
        // Set initial notification
        service.setForegroundNotificationInfo(
          title: 'تذكير القرآن',
          content: 'جاري تشغيل خدمة التذكير',
        );

        // Handle stop service request
        service.on('stopService').listen((event) {
          try {
            service.stopSelf();
          } catch (e) {
            print('Error stopping service: $e');
          }
        });
      }

      // Use a more reliable timer mechanism
      const duration = Duration(minutes: 1);
      Timer.periodic(duration, (timer) async {
        try {
          if (!QuranOverlayCache.isOverlayEnabled()) {
            timer.cancel();
            return;
          }

          if (QuranOverlayCache.isTimeForNextOverlay()) {
            final instance = Get.find<QuranOverlayService>();
            await instance.showOverlay();
          }
        } catch (e) {
          print('Error in background timer: $e');
        }
      });
    } catch (e) {
      print('Error in background service: $e');
    }
  }
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  // MARK: - Helper Methods
  static Future<void> showOverlayWithSettings(Map<String, dynamic> settings) async {
    final instance = Get.find<QuranOverlayService>();
    await instance.showOverlay();
  }

  String _getSurahName(int surahNumber) {
    return "سورة $surahNumber";
  }

  Future<List<QuranVerseModel>> _getNextVerses(
      int startIndex,
      int count,
      bool isPageMode,
      ) async {
    try {
      if (_quranController == null) return [];

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
      print('Error getting next verses: $e');
      return [];
    }
  }

  // MARK: - Lifecycle Handling
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isServiceEnabled) {
          _checkAndRestartServiceIfNeeded();
        }
        break;
      case AppLifecycleState.paused:
      // Ensure service keeps running in background if enabled
        if (_isServiceEnabled) {
          _backgroundService.invoke('keepAlive');
        }
        break;
      default:
        break;
    }
  }

  Future<void> _checkAndRestartServiceIfNeeded() async {
    final isRunning = await _backgroundService.isRunning();
    if (!isRunning && _isServiceEnabled) {
      await startService();
    }
  }

  void updateServiceState(bool isEnabled) {
    _isServiceEnabled = isEnabled;
  }

  Future<void> _checkPermission() async {
    if (Platform.isAndroid) {
      await checkAndRequestPermission();
    }
  }
}