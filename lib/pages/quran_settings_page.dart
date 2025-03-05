import 'package:arabic_numbers/arabic_numbers.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:get/get.dart';
import 'package:tawakkal/constants/constants.dart';
import 'package:tawakkal/data/cache/quran_overlay_cache.dart';
import 'package:tawakkal/data/cache/quran_reader_cache.dart';
import 'package:tawakkal/routes/app_pages.dart';
import 'package:tawakkal/utils/sheets/sheet_methods.dart';
import 'package:tawakkal/widgets/custom_container.dart';
import '../controllers/quran_audio_player_controller.dart';
import '../controllers/quran_settings_controller.dart';

class QuranSettingsPage extends GetView<QuranSettingsController> {
  const QuranSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var titleTextStyle = theme.textTheme.titleSmall;
    var subtitleTextStyle = TextStyle(color: theme.hintColor);
    var defaultSubtitleTextStyle =
        theme.textTheme.labelMedium!.copyWith(color: theme.hintColor);
    return Scaffold(
      appBar: AppBar(
        titleTextStyle: theme.textTheme.titleMedium,
        title: const Text(
          'إعدادات القرآن',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(
                'العرض',
                style: titleTextStyle!.copyWith(color: theme.primaryColor),
              ),
              dense: true,
            ),
            GetBuilder<QuranSettingsController>(
              builder: (controller) {
                return SwitchListTile(
                  dense: true,
                  title: Text(
                    'تلوين العلامات',
                    style: titleTextStyle,
                  ),
                  subtitle: Text(
                    'تلوين علامات الآيات وحقل السورة',
                    style: subtitleTextStyle,
                  ),
                  value: controller.settingsModel.isMarkerColored,
                  onChanged: (value) => controller.onMarkerColorSwitched(value),
                );
              },
            ),
            GetBuilder<QuranSettingsController>(
              builder: (controller) {
                return SwitchListTile(
                  dense: true,
                  title: Text(
                    'عرض ديناميكي',
                    style: titleTextStyle,
                  ),
                  subtitle: Text(
                    explainAdaptiveModeText,
                    style: subtitleTextStyle,
                  ),
                  value: controller.settingsModel.isAdaptiveView,
                  onChanged: (value) =>
                      controller.onDisplayOptionChanged(value),
                );
              },
            ),
            GetBuilder<QuranSettingsController>(builder: (controller) {
              return IgnorePointer(
                  ignoring: !controller.settingsModel.isAdaptiveView,
                  child: Opacity(
                    opacity:
                        !controller.settingsModel.isAdaptiveView ? 0.5 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ListTile(
                          title: Text(
                            'حجم الخط',
                          ),
                          dense: true,
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor:
                                theme.colorScheme.primaryContainer,
                            inactiveTickMarkColor: theme.colorScheme.primary,
                            inactiveTrackColor:
                                theme.colorScheme.primaryContainer,
                          ),
                          child: GetBuilder<QuranSettingsController>(
                            builder: (controller) {
                              return Slider(
                                value: controller.settingsModel.displayFontSize,
                                min: 25,
                                max: 45,
                                label: ArabicNumbers().convert(
                                    '${controller.settingsModel.displayFontSize}'),
                                onChanged: (value) =>
                                    controller.onDisplayFontSizeChanged(value),
                                divisions: 4,
                              );
                            },
                          ),
                        ),
                        const ListTile(
                          title: Text(
                            'معاينة',
                          ),
                          dense: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0),
                          child: CustomContainer(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: GetBuilder<QuranSettingsController>(
                                builder: (controller) {
                                  return Text(
                                    previewVerse,
                                    style: TextStyle(
                                      fontFamily: 'QCF_P596',
                                      fontSize: controller
                                          .settingsModel.displayFontSize,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ));
            }),
            const Gap(15),
            const Divider(),
            ListTile(
              title: Text(
                'التشغيل',
                style: titleTextStyle.copyWith(color: theme.primaryColor),
              ),
              dense: true,
            ),
            ListTile(
              onTap: () => selectReaderSheet().then((value) {
                controller.update();
                Get.find<QuranAudioPlayerBottomBarController>()
                    .selectedReader
                    .value = QuranReaderCache.getSelectedReaderFromCache();
              }),
              title: Text(
                'القارئ',
                style: titleTextStyle,
              ),
              subtitle: GetBuilder<QuranSettingsController>(
                builder: (controller) {
                  return Text(
                      QuranReaderCache.getSelectedReaderFromCache().name,
                      style: subtitleTextStyle);
                },
              ),
              dense: true,
            ),
            GetBuilder<QuranSettingsController>(
              builder: (controller) {
                return SwitchListTile(
                  dense: true,
                  title: Text(
                    'تمييز كلمة بكلمة',
                    style: titleTextStyle,
                  ),
                  subtitle: Text(
                    'تعزز فهم القرآن كلمة بكلمة أثناء القراءة.\n سيتم التطبيق بشكل كامل عند تشغيل التلاوة من جديد',
                    style: subtitleTextStyle,
                  ),
                  value: controller.settingsModel.wordByWordListen,
                  onChanged: (value) => controller.onWordByWordSwitched(value),
                );
              },
            ),
            const Divider(),
            ListTile(
              title: Text(
                'التنزيلات',
                style: titleTextStyle.copyWith(color: theme.primaryColor),
              ),
              dense: true,
            ),

            const Divider(),
            ListTile(
              title: Text(
                'التذكير بالقرآن',
                style: titleTextStyle.copyWith(color: theme.primaryColor),
              ),
              dense: true,
            ),
            GetBuilder<QuranSettingsController>(
              builder: (controller) {
                final bool isEnabled = controller.settingsModel.overlaySettings.isEnabled;
                final bool isPageMode = controller.settingsModel.overlaySettings.isPageMode;

                return Column(
                  children: [
                    // Enable/Disable Switch
                    SwitchListTile(
                      dense: true,
                      title: Text(
                        'تفعيل التذكير',
                        style: titleTextStyle,
                      ),
                      subtitle: Text(
                        'عرض ${isPageMode ? "الصفحات" : "الآيات"} بشكل دوري',
                        style: subtitleTextStyle,
                      ),
                      value: isEnabled,
                      onChanged: (value) async {
                        await controller.onOverlayEnabledChanged(value);
                      },
                    ),

                    // Settings Section
                    IgnorePointer(
                      ignoring: !isEnabled,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isEnabled ? 1.0 : 0.5,
                        child: Column(
                          children: [
                            // Display Mode Selection
                            ListTile(
                              title: Text('نوع العرض', style: titleTextStyle),
                              subtitle: Text(
                                isPageMode ? 'عرض صفحة كاملة' : 'عرض عدد محدد من الآيات',
                                style: subtitleTextStyle,
                              ),
                              trailing: SegmentedButton<bool>(
                                selected: {isPageMode},
                                onSelectionChanged: (value) =>
                                    controller.onOverlayModeChanged(value.first),
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('آيات'),
                                    icon: Icon(Icons.format_list_numbered_rtl, size: 20),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('صفحات'),
                                    icon: Icon(Icons.book_outlined, size: 20),
                                  ),
                                ],
                              ),
                            ),

                            // Verse Count Selection (Only show if in Ayat mode)
                            if (!isPageMode)
                              ListTile(
                                title: Text('عدد الآيات', style: titleTextStyle),
                                subtitle: Text(
                                  'عدد الآيات التي سيتم عرضها في كل مرة',
                                  style: subtitleTextStyle,
                                ),
                                trailing: DropdownButton<int>(
                                  value: controller.settingsModel.overlaySettings.numberOfAyat,
                                  items: [5, 10, 15, 20].map((int value) {
                                    return DropdownMenuItem<int>(
                                      value: value,
                                      child: Text('$value'),
                                    );
                                  }).toList(),
                                  onChanged: (value) =>
                                      controller.onNumberOfAyatChanged(value!),
                                ),
                              ),

                            // Time Interval Selection
                            ListTile(
                              title: Text('الفاصل الزمني', style: titleTextStyle),
                              subtitle: Text(
                                'الوقت بين كل تذكير والآخر',
                                style: subtitleTextStyle,
                              ),
                              trailing: DropdownButton<int>(
                                value: controller.settingsModel.overlaySettings.intervalMinutes,
                                items: [5, 10, 15, 30, 60].map((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text('$value دقيقة'),
                                  );
                                }).toList(),
                                onChanged: (value) =>
                                    controller.onIntervalMinutesChanged(value!),
                              ),
                            ),

                            // Preview Button
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: ElevatedButton.icon(
                                onPressed: () => controller.testOverlay(),
                                icon: const Icon(Icons.preview),
                                label: Text(
                                  'معاينة ${isPageMode ? "الصفحة" : "الآيات"} القادمة',
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                            // Reset Progress Button
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: TextButton.icon(
                                onPressed: () async {
                                  await QuranOverlayCache.resetProgress();
                                  controller.update();
                                  Get.snackbar(
                                    'تم',
                                    'تم إعادة تعيين التقدم',
                                    duration: const Duration(seconds: 2),
                                  );
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('إعادة تعيين التقدم'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            ListTile(
              leading: Icon(
                FluentIcons.reading_mode_mobile_20_regular,
                color: theme.hintColor,
              ),
              onTap: () => Get.toNamed(Routes.RECITER_DOWNLOAD_MANAGER),
              title: Text(
                'الصوتيات',
                style: titleTextStyle,
              ),
              subtitle: Text(
                'ادارة الملفات الصوتية للقراء',
                style: defaultSubtitleTextStyle,
              ),
            ),
            ListTile(
              leading: Icon(
                FluentIcons.book_letter_20_regular,
                color: theme.hintColor,
              ),
              onTap: () => Get.toNamed(Routes.TAFSIR_DOWNLOAD_MANAGER),
              title: Text(
                'التفاسير',
                style: titleTextStyle,
              ),
              subtitle: Text(
                'ادارة التفاسير المتاحة',
                style: defaultSubtitleTextStyle,
              ),
            ),
            const Gap(25),
          ],
        ),
      ),
    );
  }
}
