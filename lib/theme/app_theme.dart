import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _brandSeed = Color(0xFFC9352C);

class AppColors {
  const AppColors({
    required this.background,
    required this.backgroundSecondary,
    required this.surface,
    required this.surfaceMuted,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.error,
    required this.warning,
    required this.info,
    required this.border,
    required this.borderSubtle,
  });

  final Color background;
  final Color backgroundSecondary;
  final Color surface;
  final Color surfaceMuted;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color error;
  final Color warning;
  final Color info;
  final Color border;
  final Color borderSubtle;

  factory AppColors.fromScheme(ColorScheme scheme) {
    final bool dark = scheme.brightness == Brightness.dark;
    final Color background = Color.lerp(
      scheme.surface,
      scheme.primary,
      dark ? 0.06 : 0.02,
    )!;
    final Color surface = Color.lerp(
      scheme.surface,
      scheme.primary,
      dark ? 0.12 : 0.04,
    )!;
    final Color surfaceMuted = Color.lerp(
      scheme.surface,
      scheme.primary,
      dark ? 0.18 : 0.08,
    )!;

    return AppColors(
      background: background,
      backgroundSecondary: scheme.surface,
      surface: surface,
      surfaceMuted: surfaceMuted,
      text: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      textTertiary:
          scheme.onSurfaceVariant.withValues(alpha: dark ? 0.72 : 0.64),
      primary: scheme.primary,
      primaryDark:
          Color.lerp(scheme.primary, Colors.black, dark ? 0.14 : 0.22)!,
      accent: scheme.secondary,
      error: scheme.error,
      warning: const Color(0xFFF59E0B),
      info: scheme.tertiary,
      border: scheme.outline.withValues(alpha: dark ? 0.55 : 0.40),
      borderSubtle: scheme.outline.withValues(alpha: dark ? 0.34 : 0.22),
    );
  }
}

ThemeData buildTheme(Brightness brightness, {ColorScheme? dynamicScheme}) {
  final ColorScheme scheme = dynamicScheme ??
      ColorScheme.fromSeed(
        seedColor: _brandSeed,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      );
  final AppColors c = AppColors.fromScheme(scheme);

  final ThemeData base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.background,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: c.background.withValues(alpha: 0.92),
      foregroundColor: c.text,
      toolbarHeight: 80,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 16,
      shape: Border(bottom: BorderSide(color: c.borderSubtle)),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: c.borderSubtle),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      modalBackgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: c.primary, width: 1.5),
      ),
      hintStyle: TextStyle(color: c.textTertiary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: c.primary,
        backgroundColor: c.surfaceMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceMuted,
      selectedColor: c.primary.withValues(alpha: 0.14),
      side: BorderSide(color: c.border),
      labelStyle: TextStyle(color: c.text, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    dividerTheme: DividerThemeData(color: c.borderSubtle, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.dmSans(
        color: c.text,
        fontWeight: FontWeight.w800,
      ),
      displayMedium: GoogleFonts.dmSans(
        color: c.text,
        fontWeight: FontWeight.w800,
      ),
      displaySmall: GoogleFonts.dmSans(
        color: c.text,
        fontWeight: FontWeight.w800,
      ),
      headlineLarge: GoogleFonts.dmSans(
        color: c.text,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: GoogleFonts.dmSans(
        color: c.text,
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: GoogleFonts.dmSans(
        color: c.text,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: c.text,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: c.text,
      ),
      titleSmall: GoogleFonts.dmSans(
        color: c.text,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.dmSans(color: c.text, fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.dmSans(
        color: c.text,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: GoogleFonts.dmSans(
        color: c.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
      labelMedium: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surface,
      contentTextStyle: TextStyle(color: c.text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface.withValues(alpha: 0.94),
      indicatorColor: c.primary.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll<TextStyle>(
        TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600),
      ),
      iconTheme: WidgetStatePropertyAll<IconThemeData>(
        IconThemeData(color: c.textSecondary),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: GoogleFonts.dmSans().fontFamily,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: GoogleFonts.dmSans(
        color: c.text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

AppColors appColors(BuildContext context) {
  return AppColors.fromScheme(Theme.of(context).colorScheme);
}
