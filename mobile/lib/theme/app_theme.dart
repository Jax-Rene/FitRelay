import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF090B0E);
  static const backgroundRaised = Color(0xFF0F1217);
  static const panel = Color(0xFF15191F);
  static const panelSoft = Color(0xFF20252D);
  static const line = Color(0xFF303640);
  static const text = Color(0xFFF7F8F3);
  static const muted = Color(0xFFA3ABB6);
  static const lime = Color(0xFFD8FF3E);
  static const limeDeep = Color(0xFF9BE53D);
  static const limeSurface = Color(0xFF1D2815);
  static const coral = Color(0xFFFF7F72);
  static const sky = Color(0xFF6ED7FF);
  static const violet = Color(0xFFB79CFF);
  static const orange = Color(0xFFFFB45E);
}

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.lime,
      surface: AppColors.panel,
      onPrimary: Color(0xFF11130D),
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.panelSoft,
      outline: AppColors.line,
    ),
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: AppColors.text,
        fontSize: 36,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
      ),
      titleLarge: TextStyle(
        color: AppColors.text,
        fontSize: 24,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: AppColors.text,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: AppColors.text, fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.55),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel,
      hintStyle: const TextStyle(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.lime, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.panel,
      selectedColor: const Color(0xFF34421E),
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      iconTheme: const IconThemeData(size: 17, color: AppColors.muted),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.panel,
      modalBackgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.lime,
        minimumSize: const Size(48, 48),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.panelSoft,
      contentTextStyle: const TextStyle(color: AppColors.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.lime,
      linearTrackColor: AppColors.line,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    useMaterial3: true,
  );
}
