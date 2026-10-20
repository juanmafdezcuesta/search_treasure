import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ══════════════════════════════════════════════════════════════════════════════
// AppColors — Paleta semántica 2026 (Dark-Bio + Digital Serenity)
// ══════════════════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // ── Fondos Dark-Bio 2026 ──────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0B0F19); // Negro abisal / Tech Black
  static const Color surfaceDark    = Color(0xFF1A202C); // Gris azulado profundo
  static const Color cardDark       = Color(0xFF111827); // Cards y bottom sheets

  // ── Fondos Digital Serenity 2026 ─────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight    = Color(0xFFFFFFFF);
  static const Color cardLight       = Color(0xFFF1F3F5);

  // ── Primario ──────────────────────────────────────────────────────────────
  static const Color accentCyan    = Color(0xFF00E5CC); // primary dark  · Menta Neón
  static const Color accentCyanDim = Color(0xFF00C2AD); // primary light · contraste WCAG mejorado

  // ── Secundario ────────────────────────────────────────────────────────────
  static const Color accentViolet    = Color(0xFFA855F7); // secondary dark  · Violeta vibrante
  static const Color accentVioletMid = Color(0xFF8B5CF6); // secondary light · Violeta maduro

  // ── Acentos decorativos (usados directamente en UI) ───────────────────────
  static const Color accentFuchsia = Color(0xFFFF3366); // legado Dark-Bio
  static const Color accentCoral   = Color(0xFFFF6B4A); // gamificación / errores suaves
  static const Color accentGold    = Color(0xFFFFD700); // XP, monedas, ranking

  // ── Feedback ──────────────────────────────────────────────────────────────
  static const Color success    = Color(0xFF00E676);
  static const Color error      = Color(0xFFEF4444); // dark mode
  static const Color errorLight = Color(0xFFDC2626); // light mode

  // ── Texto Dark ────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF8FAFC); // onBackground dark
  static const Color textSecondary = Color(0xFF8B949E); // muted / captions

  // ── Texto Light ───────────────────────────────────────────────────────────
  static const Color textPrimaryLight   = Color(0xFF111827); // onBackground light
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // ── Mapa ──────────────────────────────────────────────────────────────────
  static const Color mapZoneOverlay = Color(0x55FF6B4A);

  // ══════════════════════════════════════════════════════════════════════════
  // ColorSchemes semánticos — fuente de verdad para ThemeData
  // Nota: `background` está deprecated en Flutter ≥3.22; migrar a
  // surfaceContainerLowest cuando se actualice el SDK.
  // ══════════════════════════════════════════════════════════════════════════

  // ignore: deprecated_member_use
  static const ColorScheme darkScheme = ColorScheme.dark(
    primary:      accentCyan,        // #00E5CC — acciones principales, botones, FAB
    onPrimary:    Color(0xFF000000), // texto/icono sobre primary
    secondary:    accentViolet,      // #A855F7 — acentos alternativos, chips, badges
    onSecondary:  Color(0xFFFFFFFF),
    // ignore: deprecated_member_use
    background:   backgroundDark,    // #0B0F19 — 60% del espacio visual
    // ignore: deprecated_member_use
    onBackground: textPrimary,       // #F8FAFC
    surface:      surfaceDark,       // #1A202C — tarjetas, paneles, modals
    onSurface:    Color(0xFFF1F5F9),
    error:        error,             // #EF4444
    onError:      Color(0xFFFFFFFF),
  );

  // ignore: deprecated_member_use
  static const ColorScheme lightScheme = ColorScheme.light(
    primary:      accentCyanDim,     // #00C2AD — contraste mejorado en fondos claros
    onPrimary:    Color(0xFFFFFFFF),
    secondary:    accentVioletMid,   // #8B5CF6
    onSecondary:  Color(0xFFFFFFFF),
    // ignore: deprecated_member_use
    background:   backgroundLight,   // #F8F9FA
    // ignore: deprecated_member_use
    onBackground: textPrimaryLight,  // #111827
    surface:      surfaceLight,      // #FFFFFF
    onSurface:    Color(0xFF1F2937),
    error:        errorLight,        // #DC2626
    onError:      Color(0xFFFFFFFF),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// AppTheme — ThemeData completamente semántico (sin colores hardcodeados)
// ══════════════════════════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  // ── Tema Oscuro (Dark-Bio 2026) ───────────────────────────────────────────
  static ThemeData get dark {
    final cs = AppColors.darkScheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      // ignore: deprecated_member_use
      scaffoldBackgroundColor: cs.background,
      textTheme: GoogleFonts.poppinsTextTheme(TextTheme(
        // ignore: deprecated_member_use
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: cs.onBackground),
        // ignore: deprecated_member_use
        titleLarge:   TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onBackground),
        // ignore: deprecated_member_use
        bodyLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: cs.onBackground),
        bodyMedium:   const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        labelLarge:   TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onPrimary),
      )),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary.withOpacity(0.6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(48, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          minimumSize: const Size(48, 48),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 6,
        shape: const CircleBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        indicatorColor: cs.primary.withOpacity(0.15),
        iconTheme: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected)
            ? IconThemeData(color: cs.primary, size: 26)
            : const IconThemeData(color: AppColors.textSecondary, size: 24)),
        labelTextStyle: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected)
            ? TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600)
            : const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.error, width: 2)),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedColor: cs.primary.withOpacity(0.18),
        labelStyle: TextStyle(color: cs.onSurface, fontSize: 13),
        side: BorderSide(color: cs.primary.withOpacity(0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF21262D), thickness: 1, space: 1),
    );
  }

  // ── Tema Claro (Digital Serenity 2026) ────────────────────────────────────
  static ThemeData get light {
    final cs = AppColors.lightScheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cs,
      // ignore: deprecated_member_use
      scaffoldBackgroundColor: cs.background,
      textTheme: GoogleFonts.poppinsTextTheme(TextTheme(
        // ignore: deprecated_member_use
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: cs.onBackground),
        // ignore: deprecated_member_use
        titleLarge:   TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onBackground),
        // ignore: deprecated_member_use
        bodyLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: cs.onBackground),
        bodyMedium:   const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondaryLight),
        labelLarge:   TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onPrimary),
      )),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary.withOpacity(0.7)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(48, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          minimumSize: const Size(48, 48),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 6,
        shape: const CircleBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        indicatorColor: cs.primary.withOpacity(0.15),
        iconTheme: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected)
            ? IconThemeData(color: cs.primary, size: 26)
            : const IconThemeData(color: AppColors.textSecondaryLight, size: 24)),
        labelTextStyle: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected)
            ? TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600)
            : const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardLight,
        hintStyle: const TextStyle(color: AppColors.textSecondaryLight),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.error, width: 2)),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardLight,
        selectedColor: cs.primary.withOpacity(0.15),
        labelStyle: TextStyle(color: cs.onSurface, fontSize: 13),
        side: BorderSide(color: cs.primary.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EB), thickness: 1, space: 1),
    );
  }
}
