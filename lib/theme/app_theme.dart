import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// HomeVault design system — v2 (modernized)
///
/// Requires the `google_fonts` package:
///   flutter pub add google_fonts
class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Color primaryText, Color secondaryText) {
    // Inter for body/UI text (clean, highly legible on small screens),
    // Lexend for headlines (a bit more character, still very readable).
    final base = GoogleFonts.interTextTheme();
    return base
        .copyWith(
          headlineMedium: GoogleFonts.lexend(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: primaryText,
            letterSpacing: -0.5,
          ),
          headlineSmall: GoogleFonts.lexend(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: primaryText,
            letterSpacing: -0.3,
          ),
          titleLarge: GoogleFonts.lexend(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: primaryText,
            height: 1.4,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: secondaryText,
            height: 1.4,
          ),
          labelLarge: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: primaryText, displayColor: primaryText);
  }

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: AppColors.cardLight,
      error: AppColors.danger,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      background: AppColors.backgroundLight,
      card: AppColors.cardLight,
      surfaceAlt: AppColors.surfaceAltLight,
      textPrimary: AppColors.textPrimaryLight,
      textSecondary: AppColors.textSecondaryLight,
      brightness: Brightness.light,
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryLight,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryLight,
      secondary: AppColors.accent,
      tertiary: AppColors.accent,
      surface: AppColors.cardDark,
      error: const Color(0xFFE57373),
    );

    return _buildTheme(
      colorScheme: colorScheme,
      background: AppColors.backgroundDark,
      card: AppColors.cardDark,
      surfaceAlt: AppColors.surfaceAltDark,
      textPrimary: AppColors.textPrimaryDark,
      textSecondary: AppColors.textSecondaryDark,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color background,
    required Color card,
    required Color surfaceAlt,
    required Color textPrimary,
    required Color textSecondary,
    required Brightness brightness,
  }) {
    final textTheme = _textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.lexend(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // Softer, "lifted paper" card feel instead of flat elevation=1 boxes.
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        labelStyle: TextStyle(color: textSecondary),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: colorScheme.primary,
          foregroundColor: brightness == Brightness.light
              ? Colors.white
              : Colors.black,
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colorScheme.primary : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : textSecondary,
          );
        }),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),
    );
  }
}