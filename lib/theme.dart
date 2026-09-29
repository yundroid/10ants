import 'package:flutter/material.dart';

/// Karınca yuvası paleti: toprak kahvesi, amber (bal/erzak), yaprak yeşili.
class AntColors {
  static const soil = Color(0xFF6B4431);
  static const soilDark = Color(0xFF3E271C);
  static const amber = Color(0xFFE8A33D);
  static const sand = Color(0xFFF6EBDD);
  static const cream = Color(0xFFFCF8F2);
  static const leaf = Color(0xFF3D8B4F);
  static const berry = Color(0xFFC0452C);
  static const night = Color(0xFF1C1512);

  static Color income(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF7BC58C) : leaf;
  static Color expense(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFFEF8A72) : berry;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AntColors.soil,
    brightness: brightness,
    primary: dark ? const Color(0xFFE2B894) : AntColors.soil,
    secondary: AntColors.amber,
    error: dark ? const Color(0xFFEF8A72) : AntColors.berry,
    surface: dark ? AntColors.night : AntColors.cream,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF2A201B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF2A201B) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AntColors.amber,
      foregroundColor: AntColors.soilDark,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: AntColors.amber.withValues(alpha: 0.35),
      backgroundColor: dark ? const Color(0xFF241B16) : AntColors.sand,
    ),
  );
}
