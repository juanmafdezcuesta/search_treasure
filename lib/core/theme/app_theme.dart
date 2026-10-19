import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // ── Fondos Dark-Bio 2026 ──────────────────────────────────────────────────
  static const Color backgroundDark  = Color(0xFF050914);
  static const Color surfaceDark     = Color(0xFF0D1320);
  static const Color cardDark        = Color(0xFF111827);

  // ── Fondos Light ──────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight    = Color(0xFFFFFFFF);
  static const Color cardLight       = Color(0xFFF1F3F5);

  // ── Acentos (mismo en ambos temas) ───────────────────────────────────────
  static const Color accentCyan      = Color(0xFF00E5CC);
  static const Color accentCyanDim   = Color(0xFF00B8A3);
  static const Color accentFuchsia   = Color(0xFFFF3366); // Dark-Bio 2026
  static const Color accentCoral     = Color(0xFFFF6B4A);
  static const Color accentGold      = Color(0xFFFFD700);

  // ── Feedback ──────────────────────────────────────────────────────────────
  static const Color success         = Color(0xFF00E676);
  static const Color error           = Color(0xFFFF3D3D);

  // ── Texto Dark ────────────────────────────────────────────────────────────
  static const Color textPrimary     = Color(0xFFFFFFFF);
  static const Color textSecondary   = Color(0xFF8B949E);

  // ── Texto Light ───────────────────────────────────────────────────────────
  static const Color textPrimaryLight   = Color(0xFF111111);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // ── Mapa ──────────────────────────────────────────────────────────────────
  static const Color mapZoneOverlay  = Color(0x55FF6B4A);
}

class AppTheme {
  AppTheme._();

  // ── Tema Oscuro (Dark-Bio) ────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        colorScheme: const ColorScheme.dark(
          background:   AppColors.backgroundDark,
          surface:      AppColors.surfaceDark,
          primary:      AppColors.accentCyan,
          secondary:    AppColors.accentFuchsia,
          error:        AppColors.error,
          onBackground: AppColors.textPrimary,
          onSurface:    AppColors.textPrimary,
          onPrimary:    AppColors.backgroundDark,
          onSecondary:  AppColors.textPrimary,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          titleLarge:   TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          bodyLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
          bodyMedium:   TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
          labelLarge:   TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.backgroundDark),
        )),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceDark,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentCyan,
            foregroundColor: AppColors.backgroundDark,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentCyan,
            minimumSize: const Size(48, 48),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.accentCyan,
          foregroundColor: AppColors.backgroundDark,
          elevation: 6,
          shape: CircleBorder(),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          indicatorColor: AppColors.accentCyan.withOpacity(0.15),
          iconTheme: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected)
              ? const IconThemeData(color: AppColors.accentCyan, size: 26)
              : const IconThemeData(color: AppColors.textSecondary, size: 24)),
          labelTextStyle: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected)
              ? const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600)
              : const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardDark,
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardDark,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF21262D), thickness: 1, space: 1),
      );

  // ── Tema Claro ────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        colorScheme: const ColorScheme.light(
          background:   AppColors.backgroundLight,
          surface:      AppColors.surfaceLight,
          primary:      AppColors.accentCyan,
          secondary:    AppColors.accentFuchsia,
          error:        AppColors.error,
          onBackground: AppColors.textPrimaryLight,
          onSurface:    AppColors.textPrimaryLight,
          onPrimary:    Colors.white,
          onSecondary:  Colors.white,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
          titleLarge:   TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight),
          bodyLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimaryLight),
          bodyMedium:   TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondaryLight),
          labelLarge:   TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        )),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceLight,
          foregroundColor: AppColors.textPrimaryLight,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentCyan,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentCyan,
            minimumSize: const Size(48, 48),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.accentCyan,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: CircleBorder(),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surfaceLight,
          indicatorColor: AppColors.accentCyan.withOpacity(0.15),
          iconTheme: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected)
              ? const IconThemeData(color: AppColors.accentCyan, size: 26)
              : IconThemeData(color: AppColors.textSecondaryLight, size: 24)),
          labelTextStyle: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected)
              ? const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600)
              : TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardLight,
          hintStyle: const TextStyle(color: AppColors.textSecondaryLight),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceLight,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EB), thickness: 1, space: 1),
      );
}
