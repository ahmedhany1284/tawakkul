import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:tawakkal/controllers/quran_overlay_controller.dart';
import 'package:tawakkal/data/cache/quran_settings_cache.dart';
import 'package:tawakkal/data/repository/quran_repository.dart';
import 'package:tawakkal/services/quran_background_service.dart';

import 'package:get/get.dart';

class QuranBackgroundSettingsPage extends StatefulWidget {
  const QuranBackgroundSettingsPage({super.key});

  @override
  State<QuranBackgroundSettingsPage> createState() =>
      _QuranBackgroundSettingsPageState();
}

class _QuranBackgroundSettingsPageState extends State<QuranBackgroundSettingsPage> {
  late final QuranBackgroundSettingsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(QuranBackgroundSettingsController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنبيهات القرآن'),
        actions: [
          Obx(() => Visibility(
            visible: controller.hasUnsavedChanges.value,
            child: TextButton.icon(
              onPressed: controller.saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('حفظ'),
            ),
          )),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMainCard(),
          const SizedBox(height: 16),
          _buildTimeIntervalCard(),
          const SizedBox(height: 16),
          _buildActionButtons(),
          const SizedBox(height: 16),
          _buildInfoCard(),
        ],
      ),
    );
  }


  Widget _buildMainCard() {
    return Card(
      child: Column(
        children: [
          Obx(() => SwitchListTile(
            value: controller.isEnabled.value,
            onChanged: (value) {
              controller.isEnabled.value = value;
              controller.hasUnsavedChanges.value = true;
            },
            title: const Text('تفعيل العرض'),
            subtitle: const Text('عرض القرآن في الخلفية'),
          )),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نوع العرض'),
                const SizedBox(height: 8),
                Obx(() => Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('آيات'),
                        value: QuranBackgroundService.DISPLAY_TYPE_VERSE,
                        groupValue: controller.displayType.value,
                        onChanged: (value) {
                          controller.displayType.value = value!;
                          controller.hasUnsavedChanges.value = true;
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('صفحات'),
                        value: QuranBackgroundService.DISPLAY_TYPE_PAGE,
                        groupValue: controller.displayType.value,
                        onChanged: (value) {
                          controller.displayType.value = value!;
                          controller.hasUnsavedChanges.value = true;
                        },
                      ),
                    ),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTimeIntervalCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الفاصل الزمني'),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    SizedBox(
                      width: constraints.maxWidth * 0.6,
                      child: TextField(
                        controller: controller.intervalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'أدخل الفترة',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (_) {
                          controller.hasUnsavedChanges.value = true;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: Obx(() => DropdownButtonFormField<String>(
                          value: controller.timeUnit.value,
                          isDense: true,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'seconds',
                              child: Text('ثواني', style: TextStyle(fontSize: 14)),
                            ),
                            DropdownMenuItem(
                              value: 'minutes',
                              child: Text('دقائق', style: TextStyle(fontSize: 14)),
                            ),
                            DropdownMenuItem(
                              value: 'hours',
                              child: Text('ساعات', style: TextStyle(fontSize: 14)),
                            ),
                            DropdownMenuItem(
                              value: 'days',
                              child: Text('أيام', style: TextStyle(fontSize: 14)),
                            ),
                          ],
                          onChanged: (value) {
                            controller.timeUnit.value = value!;
                            controller.hasUnsavedChanges.value = true;
                          },
                        )),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            try {
              // Check permission first
              if (!await FlutterOverlayWindow.isPermissionGranted()) {
                final hasPermission = await FlutterOverlayWindow.requestPermission();
                if (!hasPermission!) {
                  Get.snackbar(
                    'تنبيه',
                    'يجب السماح بعرض النوافذ المنبثقة لتفعيل هذه الميزة',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }
              }

              // Show loading
              Get.dialog(
                const Center(child: CircularProgressIndicator()),
                barrierDismissible: false,
              );

              // Close any existing overlay
              await FlutterOverlayWindow.closeOverlay();
              await Future.delayed(const Duration(milliseconds: 500));

              // Simple test content
              String overlayContent = '''
              <!DOCTYPE html>
              <html>
                <head>
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <style>
                    body {
                      margin: 0;
                      padding: 16px;
                      background-color: #1A1F38;
                      height: 100vh;
                      display: flex;
                      align-items: center;
                      justify-content: center;
                    }
                    .content {
                      color: white;
                      font-size: 24px;
                      text-align: center;
                      direction: rtl;
                    }
                  </style>
                </head>
                <body>
                  <div class="content">
                    بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ
                  </div>
                </body>
              </html>
            ''';

              print('Attempting to show overlay...');

              // Show overlay
              await FlutterOverlayWindow.showOverlay(
                enableDrag: true,
                height: 150,
                width: WindowSize.matchParent,
                alignment: OverlayAlignment.topCenter,
                positionGravity: PositionGravity.auto,
                overlayContent: overlayContent,
              );

              // Hide loading
              if (Get.isDialogOpen!) Get.back();

              print('Overlay shown, checking status...');
              await Future.delayed(const Duration(seconds: 1));

              final isActive = await FlutterOverlayWindow.isActive();
              print('Overlay active: $isActive');

              // Auto close after 5 seconds
              await Future.delayed(const Duration(seconds: 5));
              await FlutterOverlayWindow.closeOverlay();

            } catch (e) {
              print('Error showing overlay: $e');
              if (Get.isDialogOpen!) Get.back();
              Get.snackbar(
                'خطأ',
                'حدث خطأ أثناء عرض المعاينة: $e',
                snackPosition: SnackPosition.BOTTOM,
              );
            }
          },
          icon: const Icon(Icons.preview),
          label: const Text('معاينة'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () async {
            try {
              final isPermissionGranted = await FlutterOverlayWindow.isPermissionGranted();
              final isActive = await FlutterOverlayWindow.isActive();

              print('Permission granted: $isPermissionGranted');
              print('Overlay active: $isActive');

              Get.snackbar(
                'حالة النافذة',
                'الإذن: ${isPermissionGranted ? 'ممنوح' : 'غير ممنوح'}\n'
                    'النافذة: ${isActive ? 'نشطة' : 'غير نشطة'}',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 5),
              );
            } catch (e) {
              print('Error checking status: $e');
              Get.snackbar(
                'خطأ',
                'حدث خطأ أثناء فحص الحالة: $e',
                snackPosition: SnackPosition.BOTTOM,
              );
            }
          },
          icon: const Icon(Icons.info_outline),
          label: const Text('فحص الحالة'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () async {
            try {
              await FlutterOverlayWindow.closeOverlay();
              Get.snackbar(
                'تم',
                'تم إغلاق المعاينة',
                snackPosition: SnackPosition.BOTTOM,
              );
            } catch (e) {
              print('Error closing overlay: $e');
              Get.snackbar(
                'خطأ',
                'حدث خطأ أثناء إغلاق المعاينة: $e',
                snackPosition: SnackPosition.BOTTOM,
              );
            }
          },
          icon: const Icon(Icons.close),
          label: const Text('إغلاق المعاينة'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }
  Widget _buildInfoCard() {
    return Obx(() => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات عن الخدمة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'هذه الخدمة تقوم بعرض ${controller.displayType.value == QuranBackgroundService.DISPLAY_TYPE_VERSE ? 'آيات' : 'صفحات'} '
                  'من القرآن الكريم كل ${controller.intervalController.text} ${controller.timeUnit.value} على شاشة جهازك.',
            ),
            const SizedBox(height: 8),
            const Text(
              '• يجب السماح بإذن عرض النوافذ المنبثقة على التطبيقات الأخرى.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              '• يمكن سحب النافذة لتغيير موضعها على الشاشة.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              '• الخدمة تعمل في الخلفية حتى عند إغلاق التطبيق.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    ));
  }
}
