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
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
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
                  child: FittedBox(
                    fit: BoxFit.fitHeight,
                    child: Column(
                      children: _buildQuranLines(verses),
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
      // Check if this is a new surah
      if (verse['surahNumber'] != currentSurah) {
        currentSurah = verse['surahNumber'];
        if (verse['verseNumber'] == 1) {
          lines.add(
            Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  '${verse['surahNumber'].toString().padLeft(3, '0')}surah',
                  style: const TextStyle(
                    fontFamily: 'SURAHNAMES',
                    fontSize: 40,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (verse['surahNumber'] != 1 && verse['surahNumber'] != 9)
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

      // Add verse text
      lines.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                height: 2.0,
                fontFamily: 'QCF_P596',
                fontSize: 28,
                color: Colors.black,
              ),
              children: [
                TextSpan(text: verse['text']),
                if (verse['wordType'] == 'end')
                  TextSpan(
                    text: ' ${verse['verseNumber']} ',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 22,
                    ),
                  ),
              ],
            ),
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
              await FlutterOverlayWindow.closeOverlay();
              final controller = Get.find<QuranSettingsController>();
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

class QuranPageOverlayView extends StatelessWidget {
  final List<Map<String, dynamic>> pages;

  const QuranPageOverlayView({
    super.key,
    required this.pages,
  });

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              children: [
                _buildHeader(),
                const Divider(height: 1),
                Expanded(
                  child: PageView.builder(
                    itemCount: pages.length,
                    reverse: true,
                    controller: PageController(initialPage: 0),
                    itemBuilder: (context, pageIndex) {
                      final pageData = pages[pageIndex];
                      final pageNumber = pageData['page_number'] as int? ?? 0;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Show strokes for odd pages
                          if (pageNumber > 0 && pageNumber % 2 != 0)
                            _buildPageStrokes(false),

                          // Page content
                          Expanded(
                            child: Column(
                              children: [
                                // Page header with surah names and juz info
                                _buildPageHeader(pageData),

                                // Quran text
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.fitHeight,
                                    child: Column(
                                      children: _buildQuranLines(
                                          pageData['verses'] ?? []),
                                    ),
                                  ),
                                ),

                                // Page number
                                _buildPageNumber(pageNumber),
                              ],
                            ),
                          ),

                          // Show strokes for even pages
                          if (pageNumber > 0 && pageNumber % 2 == 0)
                            _buildPageStrokes(true),
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
    );
  }

  Widget _buildPageStrokes(bool isEven) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          VerticalDivider(
            thickness: i == 3 ? 2 : 1.5,
            width: i == 3 ? 2 : 3,
          ),
      ].reversed.toList(),
    );
  }

  Widget _buildPageHeader(Map<String, dynamic> pageData) {
    final pageNumber = pageData['page_number'] as int? ?? 0;
    final juzNumber = pageData['juz_number'] as int? ?? 0;
    final surahNumber = pageData['surah_number'] as int? ?? 0;

    return SizedBox(
      height: 30,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Surah names
            Text(
              'سورة $surahNumber',
              style: const TextStyle(fontSize: 12),
            ),
            // Juz info
            Text(
              'الجزء $juzNumber',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageNumber(int pageNumber) {
    return Container(
      height: 40,
      alignment: Alignment.center,
      child: Text(
        '$pageNumber',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  List<Widget> _buildQuranLines(List<dynamic> verses) {
    try {
      List<Word> allWords = _convertWords(verses);
      List<Widget> lines = [];

      // Group words by line number
      Map<int, List<Word>> wordsByLine = {};
      for (var word in allWords) {
        wordsByLine.putIfAbsent(word.lineNumber, () => []).add(word);
      }

      // Build 15 lines per page
      for (int lineNumber = 1; lineNumber <= 15; lineNumber++) {
        List<Word> lineWords = wordsByLine[lineNumber] ?? [];

        // Handle empty lines for surah headers
        if (lineWords.isEmpty) {
          // Check if we need to show surah header
          var nextLineWords = wordsByLine[lineNumber + 1] ?? [];
          if (nextLineWords.isNotEmpty &&
              nextLineWords.first.verseId == 1 &&
              nextLineWords.first.surahNumber != null) {
            lines.add(_buildSurahHeader(nextLineWords.first.surahNumber ?? 1));
          } else {
            lines.add(const SizedBox(height: 50)); // Empty line spacing
          }
        } else {
          lines.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    height: 2.0,
                    fontFamily: 'QCF_P596',
                    fontSize: 28,
                    color: Colors.black,
                  ),
                  children: lineWords.map((word) {
                    return TextSpan(
                      text: '${word.textV1} ',
                      style: TextStyle(
                        color:
                            word.wordType == 'end' ? Colors.teal : Colors.black,
                        fontSize: word.wordType == 'end' ? 22 : 28,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        }
      }

      return lines;
    } catch (e) {
      print('Error building Quran lines: $e');
      return [];
    }
  }

  List<Word> _convertWords(List<dynamic> verses) {
    List<Word> words = [];
    try {
      for (var verse in verses) {
        final List<dynamic> verseWords = verse['words'] ?? [];
        words.addAll(
          verseWords.map((w) => Word(
                id: w['id'],
                verseId: w['verse_id'],
                wordType: w['word_type'],
                textV1: w['text_v1'],
                position: w['position'],
                textUthmani: w['text_uthmani'],
                pageNumber: w['page_number'],
                lineNumber: w['line_number'],
                surahNumber: w['surah_number'],
              )),
        );
      }
    } catch (e) {
      print('Error converting words: $e');
    }
    return words;
  }

  Widget _buildSurahHeader(int surahNumber) {
    return Column(
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
              final controller = Get.find<QuranSettingsController>();
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
