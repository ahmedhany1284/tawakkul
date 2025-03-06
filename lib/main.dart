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
        } else if (event['type'] == 'pages') { // Changed from 'page' to 'pages'
          final pages = List<Map<String, dynamic>>.from(event['data']);
          runApp(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: QuranPageOverlayView(pages: pages), // Updated to use pages parameter
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
    final groupedVerses = groupVersesBySurah(verses);

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
                  child: PageView.builder(
                    itemCount: groupedVerses.length,
                    reverse: true,
                    controller: PageController(initialPage: 0),
                    itemBuilder: (context, pageIndex) {
                      final surahVerses = groupedVerses[pageIndex];
                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _buildSurahHeader(surahVerses.first),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                    (context, index) => _buildVerse(surahVerses[index]),
                                childCount: surahVerses.length,
                              ),
                            ),
                          ),
                          // Add bottom padding
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 16.0),
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
    );
  }

  List<List<Map<String, dynamic>>> groupVersesBySurah(List<Map<String, dynamic>> verses) {
    Map<int, List<Map<String, dynamic>>> surahGroups = {};

    for (var verse in verses) {
      final surahNumber = verse['surahNumber'] as int;
      surahGroups.putIfAbsent(surahNumber, () => []).add(verse);
    }

    return surahGroups.values.toList();
  }

  Widget _buildSurahHeader(Map<String, dynamic> firstVerse) {
    if (firstVerse['verseNumber'] == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            Text(
              '${firstVerse['surahNumber'].toString().padLeft(3, '0')}surah',
              style: const TextStyle(
                fontFamily: 'SURAHNAMES',
                fontSize: 40,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (firstVerse['surahNumber'] != 1 && firstVerse['surahNumber'] != 9)
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
    return const SizedBox.shrink();
  }

  Widget _buildVerse(Map<String, dynamic> verse) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                height: 1.8,
                fontFamily: 'QCF_P596',
                fontSize: 24,
                color: Colors.black,
              ),
              children: [
                TextSpan(text: verse['text']),
                if (verse['wordType'] == 'end')
                  TextSpan(
                    text: ' ${verse['verseNumber']} ',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 18,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            verse['info'],
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
          Row(
            children: [
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
              _buildHeader(pages[0]),
              const Divider(height: 1),
              Expanded(
                child: PageView.builder(
                  itemCount: pages.length,
                  reverse: true,
                  controller: PageController(initialPage: 0),
                  itemBuilder: (context, index) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          if (index > 0) _buildPageInfo(pages[index]),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: FittedBox(
                              fit: BoxFit.fitWidth,
                              child: Column(
                                children: _buildQuranLines(pages[index]['verses']),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> firstPage) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تذكير بالقرآن',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'صفحة ${firstPage['pageNumber']} - جزء ${firstPage['juzNumber']}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
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

  Widget _buildPageInfo(Map<String, dynamic> pageData) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        'صفحة ${pageData['pageNumber']} - جزء ${pageData['juzNumber']}',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  List<Widget> _buildQuranLines(List<dynamic> verses) {
    List<Word> allWords = _convertWords(verses);
    List<Widget> lines = [];

    Map<int, List<Word>> wordsByLine = {};
    for (var word in allWords) {
      wordsByLine.putIfAbsent(word.lineNumber, () => []).add(word);
    }

    for (int lineNumber = 1; lineNumber <= 15; lineNumber++) {
      List<Word> lineWords = wordsByLine[lineNumber] ?? [];
      if (lineWords.isNotEmpty) {
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
                      color: word.wordType == 'end' ? Colors.teal : Colors.black,
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
  }

  List<Word> _convertWords(List<dynamic> verses) {
    List<Word> words = [];
    for (var verse in verses) {
      words.addAll(
        (verse['words'] as List).map((w) => Word(
          id: w['id'],
          verseId: w['verseId'],
          wordType: w['wordType'],
          textV1: w['textV1'],
          position: w['position'] ?? 0,
          textUthmani: w['textUthmani'] ?? '',
          pageNumber: w['pageNumber'] ?? verse['pageNumber'],
          lineNumber: w['lineNumber'],
          surahNumber: w['surahNumber'],
        )),
      );
    }
    return words;
  }
}
