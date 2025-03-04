import 'package:get/get.dart';
import 'package:tawakkal/controllers/quran_overlay_controller.dart';

class QuranBackgroundSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(QuranBackgroundSettingsController());
  }
}