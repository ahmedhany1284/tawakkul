import 'package:flutter/material.dart';
import 'package:tawakkal/data/models/quran_page.dart';
import 'package:tawakkal/data/models/quran_verse_model.dart';
import 'package:tawakkal/services/quran_background_service.dart';
import 'package:tawakkal/utils/quran_utils.dart';


import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// @pragma('vm:entry-point')
// void overlayMain() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(
//     const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: QuranOverlayWidget(),
//     ),
//   );
// }


class QuranOverlayWidget extends StatelessWidget {
  final String content;
  final String additionalInfo;

  const QuranOverlayWidget({
    Key? key,
    required this.content,
    required this.additionalInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          // Handle tap to close the overlay or perform other actions
          FlutterOverlayWindow.closeOverlay();
        },
        child: Container(
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 8),
              Text(
                additionalInfo,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
