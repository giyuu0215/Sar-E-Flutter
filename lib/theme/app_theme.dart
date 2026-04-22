import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
}

const AppColors darkColors = AppColors(
  background: Color(0xFF0F1115),
  backgroundSecondary: Color(0xFF161A20),
  surface: Color(0xFF1B2028),
  surfaceMuted: Color(0xFF222834),
  text: Color(0xFFFFFFFF),
  textSecondary: Color(0xFFA0A0A0),
  textTertiary: Color(0xFF666666),
  primary: Color(0xFFE84A3F),
  primaryDark: Color(0xFFC9352C),
  accent: Color(0xFFF6C453),
  error: Color(0xFFEF4444),
  warning: Color(0xFFF59E0B),
  info: Color(0xFF3B82F6),
  border: Color(0x33FFFFFF),
  borderSubtle: Color(0x14FFFFFF),
);

const AppColors lightColors = AppColors(
  background: Color(0xFFF7F8FA),
  backgroundSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  surfaceMuted: Color(0xFFF2F4F8),
  text: Color(0xFF1A1A1A),
  textSecondary: Color(0xFF666666),
  textTertiary: Color(0xFF999999),
  primary: Color(0xFFC9352C),
  primaryDark: Color(0xFFA02A24),
  accent: Color(0xFFF6C453),
  error: Color(0xFFDC2626),
  warning: Color(0xFFD97706),
  info: Color(0xFF2563EB),
  border: Color(0x1A000000),
  borderSubtle: Color(0x0F000000),
);

ThemeData buildTheme(Brightness brightness) {
  final AppColors c = brightness == Brightness.dark ? darkColors : lightColors;
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: c.primary,
    brightness: brightness,
    primary: c.primary,
    secondary: c.accent,
    tertiary: c.info,
    surface: c.surface,
    error: c.error,
  );

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
  return Theme.of(context).brightness == Brightness.dark
      ? darkColors
      : lightColors;
}
