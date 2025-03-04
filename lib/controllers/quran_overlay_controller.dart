import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:get/get.dart';
import 'package:tawakkal/data/models/quran_verse_model.dart';
import 'package:tawakkal/data/repository/quran_repository.dart';
import 'package:tawakkal/services/quran_background_service.dart';

class QuranBackgroundSettingsController extends GetxController {
  final RxBool isEnabled = false.obs;
  final RxString displayType = QuranBackgroundService.DISPLAY_TYPE_VERSE.obs;
  final RxString timeUnit = 'minutes'.obs;
  final RxBool hasUnsavedChanges = false.obs;
  final TextEditingController intervalController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadCurrentSettings();
  }

  void loadCurrentSettings() {
    intervalController.text = QuranBackgroundService.getInterval().toString();
    displayType.value = QuranBackgroundService.getDisplayType();
    isEnabled.value = QuranBackgroundService.isServiceEnabled();
  }

  Future<void> saveSettings() async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      await QuranBackgroundService.setDisplayType(displayType.value);
      await updateTimeInterval();
      await QuranBackgroundService.setServiceEnabled(isEnabled.value);

      await QuranBackgroundService.restartService(); // Restart the service

      hasUnsavedChanges.value = false;
      Get.back();
      Get.snackbar(
        'تم',
        'تم حفظ الإعدادات بنجاح',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء حفظ الإعدادات: $e', // Include error details
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> showTestOverlay() async {
    try {
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

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      await QuranBackgroundService.showTestOverlay();
      Get.back();
    } catch (e) {
      if (Get.isDialogOpen!) Get.back();
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء عرض المعاينة',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }


  Future<void> updateTimeInterval() async {
    try {
      final int value = int.parse(intervalController.text);
      int minutes;

      switch (timeUnit.value) {
        case 'seconds':
          minutes = (value / 60).ceil();
          break;
        case 'hours':
          minutes = value * 60;
          break;
        case 'days':
          minutes = value * 24 * 60;
          break;
        default:
          minutes = value;
      }

      await QuranBackgroundService.updateInterval(minutes);
    } catch (e) {
      throw Exception('Invalid interval value');
    }
  }

  @override
  void onClose() {
    intervalController.dispose();
    super.onClose();
  }
}