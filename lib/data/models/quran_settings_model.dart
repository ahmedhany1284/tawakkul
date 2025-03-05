import 'package:tawakkal/controllers/quran_settings_controller.dart';

class QuranSettingsModel {
  bool isMarkerColored;
  double displayFontSize;
  bool isAdaptiveView;
  bool wordByWordListen;
  QuranOverlaySettings overlaySettings;

  QuranSettingsModel({
    this.isMarkerColored = true,
    this.displayFontSize = 25.0,
    this.isAdaptiveView = false,
    this.wordByWordListen = true,
    QuranOverlaySettings? overlaySettings,
  }) : overlaySettings = overlaySettings ?? QuranOverlaySettings();
}
