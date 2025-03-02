import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_islamic_icons/flutter_islamic_icons.dart';
import 'package:get/get.dart';
import 'package:tawakkal/pages/hadith40_page.dart';

import '../routes/app_pages.dart';
import 'enum.dart';

class Activites {
  static List<Map<String, dynamic>> shortcuts = [
    {
      'icon': FlutterIslamicIcons.tasbih2,
      'onTap': () {
        Get.toNamed(Routes.ELECTRONIC_TASBIH);
      },
      'text': 'المسبحة الإلكترونية',
    },
    {
      'icon': FlutterIslamicIcons.prayer,
      'onTap': () {
        Get.toNamed(Routes.AZKAR_CATEGORIES);
      },
      'text': 'أذكار المسلم',
    },
    {
      'icon': FlutterIslamicIcons.allahText,
      'onTap': () {
        Get.toNamed(Routes.ASMAULLAH_PAGE);
      },
      'text': 'اسماء الله الحسنى',
    },
    {
      'icon': FlutterIslamicIcons.prayingPerson,
      'onTap': () {
        Get.toNamed(
          Routes.AZKAR_DETAILS,
          arguments: {
            'pageTitle': 'استغفار',
            'type': AzkarPageType.istighfar,
          },
        );
      },
      'text': 'استغفار',
    },
    {
      'icon': FluentIcons.bookmark_search_20_regular,
      'onTap': () {
        Get.toNamed(Routes.QURAN_BOOKMARKS);
      },
      'text': 'العلامات المرجعية',
    },
    // {
    //   'icon': FlutterIslamicIcons.qibla2,
    //   'onTap': () {
    //     Get.toNamed(Routes.QIBLA_PAGE);
    //   },
    //   'text': 'القبلة',
    // },
  ];
  static List<Map<String, dynamic>> activities = [
    {
      'icon': FlutterIslamicIcons.allahText,
      'onTap': () {
        Get.toNamed(Routes.ASMAULLAH_PAGE);
      },
      'text': 'اسماء الله الحسنى',
    },
    {
      'icon': FlutterIslamicIcons.tasbih2,
      'onTap': () {
        Get.toNamed(Routes.ELECTRONIC_TASBIH);
      },
      'text': 'المسبحة الإلكترونية',
    },
    {
      'icon': FlutterIslamicIcons.prayer,
      'onTap': () {
        Get.toNamed(Routes.AZKAR_CATEGORIES);
      },
      'text': 'أذكار المسلم',
    },
    {
      'icon': FlutterIslamicIcons.tasbihHand,
      'onTap': () {
        Get.toNamed(
          Routes.AZKAR_DETAILS,
          arguments: {'pageTitle': 'تسابيح', 'type': AzkarPageType.tasabih},
        );
      },
      'text': 'تسابيح',
    },
    {
      'icon': FlutterIslamicIcons.sajadah,
      'onTap': () {
        Get.toNamed(
          Routes.AZKAR_DETAILS,
          arguments: {
            'pageTitle': 'الحمد',
            'type': AzkarPageType.hmd,
          },
        );
      },
      'text': 'الحمد',
    },
    {
      'icon': FlutterIslamicIcons.prayingPerson,
      'onTap': () {
        Get.toNamed(
          Routes.AZKAR_DETAILS,
          arguments: {'pageTitle': 'استغفار', 'type': AzkarPageType.istighfar},
        );
      },
      'text': 'استغفار',
    },
    // {
    //   'icon': FlutterIslamicIcons.qibla2,
    //   'onTap': () {
    //     Get.toNamed(Routes.QIBLA_PAGE);
    //   },
    //   'text': 'القبلة',
    // },
    {
      'icon': FlutterIslamicIcons.quran2,
      'onTap': () {
        Get.to(() => const Hadith40Page());
      },
      'text': 'الاربعون النووية',
    },
    // {
    //   'icon': FlutterIslamicIcons.hadji,
    //   'onTap': () {
    //     Get.toNamed(
    //       Routes.AZKAR_DETAILS,
    //       arguments: {
    //         'pageTitle': 'ادعية الانبياء',
    //         'type': AzkarPageType.prophetDua
    //       },
    //     );
    //   },
    //   'text': 'ادعية الأنبياء',
    // },
    // {
    //   'icon': FlutterIslamicIcons.prayingPerson,
    //   'onTap': () {
    //     Get.toNamed(
    //       Routes.AZKAR_DETAILS,
    //       arguments: {
    //         'pageTitle': 'ادعية نبوية',
    //         'type': AzkarPageType.pDua,
    //       },
    //     );
    //   },
    //   'text': 'ادعية نبوية',
    // },
    // {
    //   'icon': FlutterIslamicIcons.quran,
    //   'onTap': () {
    //     Get.toNamed(
    //       Routes.AZKAR_DETAILS,
    //       arguments: {
    //         'pageTitle': 'ادعية قرآنية',
    //         'type': AzkarPageType.quranDua
    //       },
    //     );
    //   },
    //   'text': 'ادعية قرآنية',
    // },
    {
      'icon': FluentIcons.bookmark_search_20_regular,
      'onTap': () {
        Get.toNamed(Routes.QURAN_BOOKMARKS);
      },
      'text': 'العلامات المرجعية',
    },
    {
      'icon': FluentIcons.book_search_20_regular,
      'onTap': () {
        Get.toNamed(Routes.QURAN_SEARCH_VIEW);
      },
      'text': 'بحث في القرآن',
    },
    // {
    //   'icon': FluentIcons.share_20_regular,
    //   'onTap': () {},
    //   'text': 'شارك التطبيق',
    // },
  ];
}
