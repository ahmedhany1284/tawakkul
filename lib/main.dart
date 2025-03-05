import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:tawakkal/constants/constants.dart';
import 'package:tawakkal/controllers/quran_reading_controller.dart';
import 'package:tawakkal/data/cache/app_settings_cache.dart';

import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:tawakkal/data/models/quran_verse_model.dart';
import 'package:tawakkal/services/quran_overlay_service.dart';
import 'constants/themes.dart';
import 'routes/app_pages.dart';
import 'services/shared_preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize GetStorage
  await GetStorage.init('bookmarks');
  await GetStorage.init('daily_content');

  // Initialize SharedPreferences service
  await Get.putAsync(() async {
    var service = SharedPreferencesService();
    await service.init();
    return service;
  });

  // Initialize controllers in order
  final quranReadingController = QuranReadingController();
  Get.put(quranReadingController);

  // Initialize overlay service after QuranReadingController
  final overlayService = QuranOverlayService();
  Get.put(overlayService);

  runApp(
    ResponsiveSizer(
      builder: (context1, orientation, screenType) {
        return GetMaterialApp(
          onDispose: () async {
            await AudioService.stop();
          },
          supportedLocales: const [
            Locale('ar', 'SA'),
          ],
          locale: const Locale('ar', 'SA'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
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
    ),
  );
}

// Make sure this is in the same file
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
        } else if (event['type'] == 'page') {
          final pageData = event['data'] as Map<String, dynamic>;
          runApp(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: QuranPageOverlayView(pageData: pageData),
              ),
            ),
          );
        }
      } catch (e) {}
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
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
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
                      onPressed: () => FlutterOverlayWindow.closeOverlay(),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: verses.map((verseData) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            if (verseData['verseNumber'] == 1) ...[
                              Text(
                                '${verseData['surahNumber'].toString().padLeft(3, '0')}surah',
                                style: const TextStyle(
                                  fontFamily: 'SURAHNAMES',
                                  fontSize: 40,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              if (verseData['surahNumber'] != 1 && verseData['surahNumber'] != 9)
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
                                  TextSpan(text: verseData['text']),
                                  if (verseData['wordType'] == 'end')
                                    TextSpan(
                                      text: ' ${verseData['verseNumber']} ',
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
                              verseData['info'],
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (verses.last != verseData) const Divider(height: 24),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuranPageOverlayView extends StatelessWidget {
  final Map<String, dynamic> pageData;

  const QuranPageOverlayView({
    super.key,
    required this.pageData,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
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
                          'صفحة ${pageData['pageNumber']} - جزء ${pageData['juzNumber']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => FlutterOverlayWindow.closeOverlay(),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Page Content
              Expanded(
                child: FittedBox(
                  fit: BoxFit.fitHeight,
                  child: Column(
                    children: _buildQuranLines(pageData['verses']),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildQuranLines(List<dynamic> verses) {
    List<Word> allWords = _convertWords(verses);
    List<Widget> lines = [];

    // Group words by line number
    Map<int, List<Word>> wordsByLine = {};
    for (var word in allWords) {
      wordsByLine.putIfAbsent(word.lineNumber, () => []).add(word);
    }

    // Build lines
    for (int lineNumber = 1; lineNumber <= 15; lineNumber++) {
      List<Word> lineWords = wordsByLine[lineNumber] ?? [];
      lines.add(
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              height: 1.8,
              fontFamily: 'QCF_P596',
              fontSize: 24,
              color: Colors.black,
            ),
            children: lineWords.map((word) {
              return TextSpan(
                text: '${word.textV1} ',
                style: TextStyle(
                  color: word.wordType == 'end' ? Colors.teal : Colors.black,
                ),
              );
            }).toList(),
          ),
        ),
      );
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
              pageNumber: w['pageNumber'] ?? pageData['pageNumber'],
              lineNumber: w['lineNumber'],
              surahNumber: w['surahNumber'],
            )),
      );
    }
    return words;
  }
}
