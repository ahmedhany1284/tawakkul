import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get/get.dart';
import 'package:tawakkal/controllers/quran_reading_controller.dart';
import 'package:tawakkal/controllers/quran_settings_controller.dart';
import 'package:tawakkal/data/cache/quran_overlay_cache.dart';
import 'package:tawakkal/data/models/quran_verse_model.dart';
import 'package:tawakkal/utils/quran_utils.dart';

Timer? timer;

class QuranOverlayService extends GetxService with WidgetsBindingObserver {
  // Constants
  static const String NOTIFICATION_CHANNEL_ID = 'quran_overlay_channel';
  static const int NOTIFICATION_ID = 888;
  static const platform = MethodChannel('com.quran.khatma/overlay');
  static const int _totalVerses = 6236;

  // Static instance
  // static QuranOverlayService get instance => Get.find<QuranOverlayService>();

  QuranOverlayService._privateConstructor();

  // Singleton instance
  static final QuranOverlayService _instance =
      QuranOverlayService._privateConstructor();

  // Getter for the instance
  static QuranOverlayService get instance => _instance;

  // Properties

  bool _isServiceEnabled = false;
  QuranReadingController? _quranController;
  final _overlayController = StreamController<List<String>>.broadcast();
  final FlutterBackgroundService _backgroundService =
      FlutterBackgroundService();
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
      listenForOverlayClosure();
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

  void startPeriodicTimer() async {
    print("Starting periodic timer for overlay.");
    final settings =
        Get.find<QuranSettingsController>().settingsModel.overlaySettings;
    final duration = settings.timeUnit.toDuration(settings.intervalValue);

    timer?.cancel(); // Cancel any existing timer before starting a new one
    print("Starting periodic timer for overlay## ${settings.intervalValue}");
    print("Starting periodic timer for overlay${duration}");

    timer = Timer.periodic(duration, (timer) async {
      if (await FlutterOverlayWindow.isActive()) {
        print("Overlay is active, resetting timer.");

        // Restart timer from zero after overlay closes
        timer?.cancel();
        startPeriodicTimer();
        await waitForOverlayToClose();
        // startPeriodicTimer(); // Restart after overlay closes
        // return;
      }

      try {
        print("Overlay closed. Restarting timer...");
        await showOverlay(); // Show overlay after waiting
        print("Overlay closed. Restarting ييييييييtimer...");
        // Restart the timer AFTER the overlay is shown and closed
        startPeriodicTimer();
      } catch (e) {
        print('Error showing overlay: $e');
      }
    });
  }

  void listenForOverlayClosure() {
    print("Overlay manually closed. Restarting periodic timdddder.");
    FlutterOverlayWindow.overlayListener.listen((event) {
      print("Overlay manually closed. Restarting periodic timggggger.");
      if (event != null && event['type'] == 'overlay_closed') {
        print("Overlay manually closed. Restarting periodic timer.");
        startPeriodicTimer();
      }
    });
  }

  Future<void> waitForOverlayToClose() async {
    while (await FlutterOverlayWindow.isActive()) {
      await Future.delayed(const Duration(seconds: 1));
    }
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
      timer?.cancel();

      // // Set up new timer
      // final settings =
      //     Get.find<QuranSettingsController>().settingsModel.overlaySettings;
      // final duration = settings.timeUnit.toDuration(settings.intervalValue);

      // _timer = Timer.periodic(
      //   duration,
      //   (timer) async {
      //     if (await FlutterOverlayWindow.isActive()) {
      //       // Overlay is active, so pause the timer by doing nothing
      //       timer.cancel();
      //       return;
      //     }
      //     try {
      //       await showOverlay();
      //     } catch (e) {
      //       print('Error showing overlay: $e');
      //     }
      //   },
      // );
      startPeriodicTimer();
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
      timer?.cancel();
      timer = null;

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
      final settings =
          Get.find<QuranSettingsController>().settingsModel.overlaySettings;

      if (settings.isPageMode) {
        // Get multiple pages if specified
        List<Map<String, dynamic>> pages = [];

        // Start from the last displayed page + 1
        int startPage = settings.lastDisplayedPageNumber + 1;
        if (startPage > 604) startPage = 1;

        // Fetch the requested number of pages
        for (int i = 0; i < settings.numberOfPages; i++) {
          int currentPage = startPage + i;
          if (currentPage > 604)
            currentPage = currentPage - 604; // Wrap around to beginning

          // Clear existing page data if any
          _quranController!.quranPages[currentPage - 1] = null;

          // Fetch new page data
          await _quranController!.fetchQuranPageData(
            pageNumber: currentPage,
            scrollToPage: false,
          );

          var pageData = _quranController!.quranPages[currentPage - 1];
          if (pageData != null) {
            pages.add({
              'page_number': pageData.pageNumber,
              'surah_number': pageData.surahNumber,
              'juz_number': pageData.juzNumber,
              'hizb_number': pageData.hizbNumber,
              'rub_el_hizb_number': pageData.rubElHizbNumber,
              'verses': pageData.verses
                  .map((verse) => {
                        'id': verse.id,
                        'verse_number': verse.verseNumber,
                        'verse_key': verse.verseKey,
                        'hizb_number': verse.hizbNumber,
                        'surah_number': verse.surahNumber,
                        'rub_el_hizb_number': verse.rubElhizbNumber,
                        'page_number': verse.pageNumber,
                        'juz_number': verse.juzNumber,
                        'text_uthmani_simple': verse.textUthmaniSimple,
                        'words': verse.words
                            .map((word) => {
                                  'id': word.id,
                                  'verse_id': word.verseId,
                                  'word_type': word.wordType,
                                  'text_v1': word.textV1,
                                  'position': word.position,
                                  'text_uthmani': word.textUthmani,
                                  'page_number': word.pageNumber,
                                  'line_number': word.lineNumber,
                                  'surah_number': word.surahNumber,
                                })
                            .toList(),
                      })
                  .toList(),
            });
          }
        }

        // Update last displayed page
        settings.lastDisplayedPageNumber =
            (startPage + settings.numberOfPages - 1) % 604;
        await QuranOverlayCache.setLastPageNumber(
            settings.lastDisplayedPageNumber);

        if (pages.isNotEmpty) {
          await _showOverlayWindow();
          await FlutterOverlayWindow.shareData({
            'type': 'pages',
            'data': pages,
          });
        }
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

        await QuranOverlayCache.setLastVerseIndex(
            settings.lastDisplayedAyatIndex);
        await _showOverlayWindow();

        // Group verses by surah for better display
        Map<int, List<QuranVerseModel>> versesBySurah = {};
        for (var verse in versesToShow) {
          versesBySurah.putIfAbsent(verse.surahNumber, () => []).add(verse);
        }

        await FlutterOverlayWindow.shareData({
          'type': 'verses',
          'data': versesToShow
              .map((verse) => {
                    'id': verse.id,
                    'verse_number': verse.verseNumber,
                    'verse_key': verse.verseKey,
                    'hizb_number': verse.hizbNumber,
                    'surah_number': verse.surahNumber,
                    'rub_el_hizb_number': verse.rubElhizbNumber,
                    'page_number': verse.pageNumber,
                    'juz_number': verse.juzNumber,
                    'text_uthmani_simple': verse.textUthmaniSimple,
                    'info':
                        'سورة ${_getSurahName(verse.surahNumber)} - آية ${verse.verseNumber}',
                    'wordType': verse.words.lastOrNull?.wordType ?? 'normal',
                    'isNewSurah': verse.verseNumber == 1,
                    'showBismillah': verse.verseNumber == 1 &&
                        verse.surahNumber != 1 &&
                        verse.surahNumber != 9,
                    'words': verse.words
                        .map((word) => {
                              'id': word.id,
                              'verse_id': word.verseId,
                              'word_type': word.wordType,
                              'text_v1': word.textV1,
                              'position': word.position,
                              'text_uthmani': word.textUthmani,
                              'page_number': word.pageNumber,
                              'line_number': word.lineNumber,
                              'surah_number': word.surahNumber,
                            })
                        .toList(),
                    'fontFamily': QuranUtils.getFontNameOfQuranPage(
                      pageNumber: verse.pageNumber,
                    ),
                    'surahName': _getSurahName(verse.surahNumber),
                  })
              .toList(),
        });
      }
    } catch (e) {
      print('Error showing overlay: $e');
    }
  }

  String _getSurahName(int surahNumber) {
    // You might want to use a proper surah names list
    return "سورة $surahNumber";
  }

  Future<void> _showOverlayWindow() async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        height: 2000,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.center,
        positionGravity: PositionGravity.none,
        visibility: NotificationVisibility.visibilityPublic,
        flag: OverlayFlag.focusPointer,
        startPosition: OverlayPosition(0, -20),
      );

      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      if (kDebugMode) {
        print('Error showing overlay window: $e');
      }
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
  static Future<void> showOverlayWithSettings(
      Map<String, dynamic> settings) async {
    final instance = Get.find<QuranOverlayService>();
    await instance.showOverlay();
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

          for (int i = startVerse;
              i < pageVerses.length && remainingCount > 0;
              i++) {
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
