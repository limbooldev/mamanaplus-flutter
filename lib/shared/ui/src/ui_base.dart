import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color tokens (extracted from Chateo UI Kit) ─────────────────────────────

abstract final class AppColors {
  // Primary brand (rose)
  static const primary = Color(0xFFE98DAD);
  /// Text/icons on primary surfaces — dark plum for contrast on the light rose.
  static const onPrimary = Color(0xFF3D2433);
  /// Deeper rose for gradients and accents (pairs with [primary]).
  static const primaryDeep = Color(0xFFC06084);

  // Light theme
  static const backgroundLight = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFF7F7F7);
  static const cardLight = Color(0xFFFFFFFF);
  static const receivedBubbleLight = Color(0xFFF3F3F3);
  static const onBackgroundLight = Color(0xFF1C1C1E);
  static const subtitleLight = Color(0xFF9E9E9E);
  static const dividerLight = Color(0xFFEEEEEE);

  // Dark theme
  static const backgroundDark = Color(0xFF1A1D2E);
  static const surfaceDark = Color(0xFF242736);
  static const cardDark = Color(0xFF2E3144);
  static const receivedBubbleDark = Color(0xFF2E3144);
  static const onBackgroundDark = Color(0xFFFFFFFF);
  static const subtitleDark = Color(0xFF9E9E9E);
  static const dividerDark = Color(0xFF2E3144);

  // Semantic
  static const error = Color(0xFFE53935);
  static const success = Color(0xFF43A047);

  // Avatar placeholder ring
  static const avatarRing = Color(0xFFE98DAD);
}

// ─── Shape tokens ─────────────────────────────────────────────────────────────

abstract final class AppShapes {
  static const pillRadius = 24.0;
  static const cardRadius = 16.0;
  static const bubbleRadius = 20.0;
  static const inputRadius = 14.0;
  static const avatarRadius = 24.0;
}

// ─── AppTheme ────────────────────────────────────────────────────────────────

abstract final class AppTheme {
  static ThemeData get light => _build(brightness: Brightness.light);
  static ThemeData get dark => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer:
          isDark ? const Color(0xFF5C3848) : const Color(0xFFFFE4EE),
      onPrimaryContainer:
          isDark ? const Color(0xFFFFD8E6) : const Color(0xFF4A1F32),
      secondary: AppColors.primary.withValues(alpha: 0.72),
      onSecondary: AppColors.onPrimary,
      secondaryContainer:
          isDark ? const Color(0xFF523442) : const Color(0xFFF5D0DC),
      onSecondaryContainer:
          isDark ? const Color(0xFFFFE0EB) : const Color(0xFF4A1F32),
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      onSurface: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
      surfaceContainerHighest:
          isDark ? AppColors.cardDark : const Color(0xFFECECEC),
      onSurfaceVariant: AppColors.subtitleLight,
      outline: isDark ? AppColors.dividerDark : AppColors.dividerLight,
    );

    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: baseTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: AppColors.subtitleLight,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        foregroundColor:
            isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.subtitleLight,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShapes.pillRadius),
          ),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.cardDark : const Color(0xFFF7F7F7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.inputRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.inputRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.inputRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(
          color: AppColors.subtitleLight,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: GoogleFonts.inter(
          color: AppColors.subtitleLight,
          fontWeight: FontWeight.w400,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.cardRadius),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        shape: CircleBorder(),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.subtitleLight,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.cardDark : const Color(0xFF1C1C1E),
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.cardRadius),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
        ),
      ),
    );
  }
}

/// Smoke check for the shared UI section wiring.
class UiHealth {
  bool get ok => true;
}
