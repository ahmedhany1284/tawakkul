import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final lightTheme = FlexThemeData.light(
  scheme: FlexScheme.sanJuanBlue,
  surfaceMode: FlexSurfaceMode.highSurfaceLowScaffold,
  blendLevel: 30,
  appBarStyle: FlexAppBarStyle.primary,
  tabBarStyle: FlexTabBarStyle.forAppBar,
  colorScheme: flexSchemeLight,
  subThemesData: const FlexSubThemesData(
    blendOnLevel: 10,
    useTextTheme: true,
    useM2StyleDividerInM3: true,
    alignedDropdown: true,
    useInputDecoratorThemeInDialogs: true,
    navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
    navigationBarUnselectedLabelSchemeColor: SchemeColor.onPrimaryContainer,
    navigationBarSelectedIconSchemeColor: SchemeColor.primary,
    navigationBarUnselectedIconSchemeColor: SchemeColor.onPrimaryContainer,
    navigationBarIndicatorSchemeColor: SchemeColor.primary,
  ),
  visualDensity: FlexColorScheme.defaultComfortablePlatformDensity(TargetPlatform.android),
  useMaterial3: true,
  swapLegacyOnMaterial3: true,
  fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
);
final darkTheme = FlexThemeData.dark(
  scheme: FlexScheme.sanJuanBlue,
  surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
  blendLevel: 13,
  appBarElevation: 5,
  colorScheme: flexSchemeDark,
  tabBarStyle: FlexTabBarStyle.forAppBar,
  subThemesData: const FlexSubThemesData(
    appBarScrolledUnderElevation: 10,
    blendOnLevel: 20,
    useTextTheme: true,
    useM2StyleDividerInM3: true,
    alignedDropdown: true,
    navigationBarElevation: 2,
    useInputDecoratorThemeInDialogs: true,
    navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
    navigationBarUnselectedLabelSchemeColor: SchemeColor.onPrimaryContainer,
    navigationBarSelectedIconSchemeColor: SchemeColor.primary,
    navigationBarUnselectedIconSchemeColor: SchemeColor.onPrimaryContainer,
    navigationBarIndicatorSchemeColor: SchemeColor.primary,
  ),
  visualDensity: FlexColorScheme.comfortablePlatformDensity,
  useMaterial3: true,
  swapLegacyOnMaterial3: true,
  fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
);
const ColorScheme flexSchemeLight = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xff375778),
  onPrimary: Color(0xffffffff),
  primaryContainer: Color(0xffa4c4ed),
  onPrimaryContainer: Color(0xff0e1014),
  secondary: Color(0xfff2c4c7),
  onSecondary: Color(0xff000000),
  secondaryContainer: Color(0xffffe3e5),
  onSecondaryContainer: Color(0xff141313),
  tertiary: Color(0xfff98d94),
  onTertiary: Color(0xff000000),
  tertiaryContainer: Color.fromARGB(255, 190, 103, 116),
  onTertiaryContainer: Color(0xff141011),
  error: Color(0xffb00020),
  onError: Color(0xffffffff),
  errorContainer: Color(0xfffcd8df),
  onErrorContainer: Color(0xff141213),
  background: Color(0xfff9fafb),
  onBackground: Color(0xff090909),
  surface: Color(0xfff9fafb),
  onSurface: Color(0xff090909),
  surfaceVariant: Color(0xffe3e5e7),
  onSurfaceVariant: Color(0xff111112),
  outline: Color(0xff7c7c7c),
  outlineVariant: Color(0xffc8c8c8),
  shadow: Color(0xff000000),
  scrim: Color(0xff000000),
  inverseSurface: Color(0xff121213),
  onInverseSurface: Color(0xfff5f5f5),
  inversePrimary: Color(0xffc3d7eb),
  surfaceTint: Color(0xff375778),
);
const ColorScheme flexSchemeDark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xff5e7691),
  onPrimary: Color(0xfff6f8fa),
  primaryContainer: Color(0xff375778),
  onPrimaryContainer: Color(0xffe8edf2),
  secondary: Color(0xfff4cfd1),
  onSecondary: Color(0xff141414),
  secondaryContainer: Color(0xff96434f),
  onSecondaryContainer: Color(0xfff7eaec),
  tertiary: Color(0xffeba1a6),
  onTertiary: Color(0xff141011),
  tertiaryContainer: Color(0xffae424f),
  onTertiaryContainer: Color(0xfffbeaec),
  error: Color(0xffcf6679),
  onError: Color(0xff140c0d),
  errorContainer: Color(0xffb1384e),
  onErrorContainer: Color(0xfffbe8ec),
  background: Color(0xff141617),
  onBackground: Color(0xffececec),
  surface: Color(0xff141617),
  onSurface: Color(0xffececec),
  surfaceVariant: Color(0xff36383b),
  onSurfaceVariant: Color(0xffdfdfe0),
  outline: Color(0xff797979),
  outlineVariant: Color(0xff2d2d2d),
  shadow: Color(0xff000000),
  scrim: Color(0xff000000),
  inverseSurface: Color(0xfff6f8f9),
  onInverseSurface: Color(0xff131313),
  inversePrimary: Color(0xff36414d),
  surfaceTint: Color(0xff5e7691),
);
