import 'dart:developer';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:tawakkal/constants/constants.dart';
import 'package:tawakkal/controllers/quran_reading_controller.dart';
import 'package:tawakkal/controllers/quran_settings_controller.dart';
import 'package:tawakkal/data/cache/app_settings_cache.dart';

import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:tawakkal/data/cache/quran_overlay_cache.dart';
import 'package:tawakkal/data/models/quran_verse_model.dart';
import 'package:tawakkal/services/quran_overlay_service.dart';
import 'package:tawakkal/widgets/app_custom_image_view.dart';
import 'constants/themes.dart';
import 'routes/app_pages.dart';
import 'services/shared_preferences_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// Background service initialization
@pragma('vm:entry-point')
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: QuranOverlayService.backgroundServiceFunction,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: CHANNEL,
      initialNotificationTitle: 'تذكير القرآن',
      initialNotificationContent: 'جاري تشغيل خدمة التذكير',
      foregroundServiceNotificationId: 888,
      autoStartOnBoot: true,
      foregroundServiceTypes: [
        AndroidForegroundType.specialUse,
      ],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: QuranOverlayService.backgroundServiceFunction,
      onBackground: QuranOverlayService.onIosBackground,
    ),
  );
}

const String CHANNEL = "com.quran.khatma/overlay";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await QuranOverlayCache.init();

  // Initialize background service
  await initializeBackgroundService();



  // Initialize storages
  await Future.wait([
    GetStorage.init('bookmarks'),
    GetStorage.init('daily_content'),
    GetStorage.init('quran_overlay'),
  ]);

  // Initialize SharedPreferences service
  await Get.putAsync(() async {
    var service = SharedPreferencesService();
    await service.init();
    return service;
  });

  // Initialize controllers
  final quranReadingController = QuranReadingController();
  Get.put(quranReadingController);

  // Initialize and configure overlay service
  final overlayService = QuranOverlayService();
  await overlayService.initializeService();
  Get.put(overlayService, permanent: true);

  // Restore overlay service state if needed
  final settings = await QuranOverlayCache.getInitialSettings();
  if (settings.isEnabled) {
    if (Platform.isAndroid) {
      bool hasPermission = await FlutterOverlayWindow.isPermissionGranted();
      if (hasPermission) {
        await overlayService.startService();
      }
    } else {
      await overlayService.startService();
    }
  }

  // Initialize lifecycle observer
  final lifecycleObserver = AppLifecycleObserver(overlayService);
  WidgetsBinding.instance.addObserver(lifecycleObserver);

  runApp(const QuranApp());
}

class QuranApp extends StatelessWidget {
  const QuranApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ResponsiveSizer(
      builder: (context, orientation, screenType) {
        return GetMaterialApp(
          onDispose: () async {
            await AudioService.stop();
          },
          supportedLocales: const [Locale('ar', 'SA')],
          locale: const Locale('ar', 'SA'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          title: appName,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: AppSettingsCache.getThemeMode(),
          initialRoute: AppPages.INITIAL,
          getPages: AppPages.routes,
        );
      },
    );
  }
}

class AppLifecycleObserver with WidgetsBindingObserver {
  final QuranOverlayService overlayService;

  AppLifecycleObserver(this.overlayService);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final settings = await QuranOverlayCache.getInitialSettings();

    switch (state) {
      case AppLifecycleState.resumed:
        if (settings.isEnabled) {
          // Check if service is running, if not, restart it
          final isRunning = await FlutterBackgroundService().isRunning();
          if (!isRunning) {
            await overlayService.startService();
          }
        }
        break;
      case AppLifecycleState.paused:
      // App going to background, ensure service keeps running if enabled
        if (settings.isEnabled) {
          final isRunning = await FlutterBackgroundService().isRunning();
          if (!isRunning) {
            await overlayService.startService();
          }
        }
        break;
      default:
        break;
    }
  }
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(QuranSettingsController());

  FlutterOverlayWindow.overlayListener.listen((event) async {
    if (event != null) {
      try {
        if (event['type'] == 'verses') {
          final verses = List<Map<String, dynamic>>.from(event['data']);
          runApp(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: QuranOverlayView(verses: verses),
              ),
            ),
          );
        } else if (event['type'] == 'pages') {
          // Changed from 'page' to 'pages'
          final pages = List<Map<String, dynamic>>.from(event['data']);
          runApp(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: QuranPageOverlayView(
                    pages: pages), // Updated to use pages parameter
              ),
            ),
          );
        }
      } catch (e) {
        print('Error in overlay: $e');
      }
    }
  });
}
class QuranOverlayView extends StatelessWidget {
  final List<Map<String, dynamic>> verses;

  const QuranOverlayView({
    super.key,
    required this.verses,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.5),
      child: SafeArea(
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95, // Slightly smaller width
            height: MediaQuery.of(context).size.height * 0.9, // Slightly smaller height
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: _buildQuranLines(verses),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQuranLines(List<Map<String, dynamic>> verses) {
    List<Widget> lines = [];
    int currentSurah = -1;

    for (var verse in verses) {
      final surahNumber = verse['surah_number'] as int? ?? -1;
      final verseNumber = verse['verse_number'] as int? ?? 0;

      if (surahNumber != currentSurah) {
        currentSurah = surahNumber;
        if (verseNumber == 1) {
          lines.add(
            Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  '${surahNumber.toString().padLeft(3, '0')}surah',
                  style: const TextStyle(
                    fontFamily: 'SURAHNAMES',
                    fontSize: 40,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (surahNumber != 1 && surahNumber != 9)
                  const Text(
                    'ﰡ',
                    style: TextStyle(
                      fontFamily: 'QCFBSML',
                      fontSize: 30,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }
      }

      // Build verse using text_v1 from words
      final words = (verse['words'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      lines.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 2,
            runSpacing: 2,
            children: words.map((word) {
              return Text(
                word['text_v1'] as String? ?? '',
                style: TextStyle(
                  fontFamily: verse['fontFamily'] as String? ?? 'QCF_P003',
                  fontSize: 32,
                  color: Colors.black,
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    return lines;
  }
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_outlined, size: 20),
              const SizedBox(width: 8),
              const Text(
                'تذكير بالقرآن',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () async {
              try {
                await FlutterOverlayWindow.closeOverlay();
                // Send a message to the main app to update the overlay timing
                await FlutterOverlayWindow.shareData({
                  'type': 'overlay_closed',
                  'timestamp': DateTime.now().toIso8601String(),
                });
              } catch (e) {
                print('Error closing overlay: $e');
              }
            },
            icon: const Icon(Icons.close),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class QuranPageOverlayView extends StatelessWidget {
  final List<Map<String, dynamic>> pages;

  const QuranPageOverlayView({
    super.key,
    required this.pages,
  });

  @override
  Widget build(BuildContext context) {
    print('-->lkdb  ${pages}');
    return Material(
      color: Colors.black.withOpacity(0.5),
      child: SafeArea(
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  _buildHeader(),
                  const Divider(height: 1),
                  Expanded(
                    child: PageView.builder(
                      itemCount: pages.length,
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      controller: PageController(
                        initialPage: pages.length - 1,
                      ),
                      itemBuilder: (context, pageIndex) {
                        final pageData = pages[pages.length - 1 - pageIndex];
                        final pageNumber = pageData['page_number'] as int? ?? 0;

                        return Column(
                          children: [
                            Expanded(
                              child: _buildPageImage(pageNumber),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageImage(int pageNumber) {
    return AppCustomImageView(
      imagePath: 'assets/images/warsh/$pageNumber.png',
      fit: BoxFit.contain,
      width: 620,
      height: 1005,
    );
  }


  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'تذكير بالقرآن',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: () async {
              await FlutterOverlayWindow.closeOverlay();
              final controller = Get.put(QuranSettingsController());
              await controller.onOverlayClosed();
            },
            icon: const Icon(Icons.close),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
