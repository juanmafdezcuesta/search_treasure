import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// Paleta de colores – Consola del Tesoro
// ─────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Fondos (tema oscuro)
  static const Color backgroundDark  = Color(0xFF0D1117); // Azul Noche
  static const Color surfaceDark     = Color(0xFF161B22); // Gris Antracita
  static const Color cardDark        = Color(0xFF1C2128); // Tarjetas / Bottom Sheets

  // Acento positivo / avance (verde menta / cian neón)
  static const Color accentCyan      = Color(0xFF00E5CC); // Botones de avanzar / acertar
  static const Color accentCyanDim   = Color(0xFF00B8A3); // Hover / estado presionado

  // Acento tesoro / alerta (naranja coral / dorado)
  static const Color accentCoral     = Color(0xFFFF6B4A); // Zonas de búsqueda, tesoro
  static const Color accentGold      = Color(0xFFFFD700); // Premios, victoria

  // Feedback
  static const Color success         = Color(0xFF00E676); // Acierto → transición verde
  static const Color error           = Color(0xFFFF3D3D); // Fallo → vibración roja

  // Texto
  static const Color textPrimary     = Color(0xFFE6EDF3); // Texto principal (blanco suave)
  static const Color textSecondary   = Color(0xFF8B949E); // Texto secundario / hints

  // Mapa
  static const Color mapZoneOverlay  = Color(0x55FF6B4A); // Círculo translúcido de zona
}

// ─────────────────────────────────────────────
// Tema principal – Dark
// ─────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        colorScheme: const ColorScheme.dark(
          background:   AppColors.backgroundDark,
          surface:      AppColors.surfaceDark,
          primary:      AppColors.accentCyan,
          secondary:    AppColors.accentCoral,
          error:        AppColors.error,
          onBackground: AppColors.textPrimary,
          onSurface:    AppColors.textPrimary,
          onPrimary:    AppColors.backgroundDark,
          onSecondary:  AppColors.textPrimary,
        ),

        // ── Tipografía ──────────────────────────────
        textTheme: GoogleFonts.poppinsTextTheme(
          const TextTheme(
            displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            titleLarge:    TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
            bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
            labelLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.backgroundDark),
          ),
        ),

        // ── AppBar ──────────────────────────────────
        appBarTheme: const AppBarTheme(
          backgroundColor:  AppColors.surfaceDark,
          foregroundColor:  AppColors.textPrimary,
          elevation:        0,
          centerTitle:      true,
        ),

        // ── Botón principal (ElevatedButton) ────────
        // Área táctil mínima 48×48 px (análisis funcional §3)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor:   AppColors.accentCyan,
            foregroundColor:   AppColors.backgroundDark,
            minimumSize:       const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),

        // ── Botón de texto ──────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentCyan,
            minimumSize: const Size(48, 48),
          ),
        ),

        // ── FAB (botón flotante "Comprobar Ubicación") ──
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor:  AppColors.accentCyan,
          foregroundColor:  AppColors.backgroundDark,
          elevation:        6,
          shape: CircleBorder(),
        ),

        // ── Bottom Sheet (tarjetas de pista) ────────
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor:  AppColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),

        // ── NavigationBar inferior ──────────────────
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor:       AppColors.surfaceDark,
          indicatorColor:        AppColors.accentCyan.withOpacity(0.15),
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const IconThemeData(color: AppColors.accentCyan, size: 26);
            }
            return const IconThemeData(color: AppColors.textSecondary, size: 24);
          }),
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w600);
            }
            return const TextStyle(color: AppColors.textSecondary, fontSize: 12);
          }),
        ),

        // ── Inputs ──────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled:           true,
          fillColor:        AppColors.cardDark,
          hintStyle:        const TextStyle(color: AppColors.textSecondary),
          contentPadding:   const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: AppColors.accentCyan, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   const BorderSide(color: AppColors.error, width: 1.5),
          ),
        ),

        // ── Cards ───────────────────────────────────
        cardTheme: CardThemeData(
          color:        AppColors.cardDark,
          elevation:    0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin:       const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),

        // ── Divider ─────────────────────────────────
        dividerTheme: const DividerThemeData(
          color:     Color(0xFF30363D),
          thickness: 1,
          space:     1,
        ),
      );
}
