import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:consola_tesoro/core/theme/app_theme.dart';

enum ClueActionState {
  idle,
  checkingGps,
  tooFar,
  gpsValidated,
  autoValidating,
  uploading,
  submitted,
}

class ClueBottomPanel extends StatelessWidget {
  final String riddleText;
  final ClueActionState actionState;
  final VoidCallback onCheckIn;
  final VoidCallback? onTakePhoto;
  final int stepOrder;
  final int totalSteps;
  final int? distanceMeters;
  final int hintCost;
  final String? hintText;
  final bool hintLoading;
  final VoidCallback? onUnlockHint;
  final bool isFinalClue;

  const ClueBottomPanel({
    super.key,
    required this.riddleText,
    required this.actionState,
    required this.onCheckIn,
    this.onTakePhoto,
    this.stepOrder     = 1,
    this.totalSteps    = 1,
    this.distanceMeters,
    this.hintCost    = 0,
    this.hintText,
    this.hintLoading = false,
    this.onUnlockHint,
    this.isFinalClue = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentCyan.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Línea de acento degradada
          Container(
            height: 3,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              gradient: LinearGradient(
                colors: [AppColors.accentCyan, AppColors.accentCoral, AppColors.accentGold],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Badges de estado
                Row(
                  children: [
                    _Badge(
                      label: 'PISTA ACTIVA',
                      color: AppColors.accentCoral,
                      icon: Icons.explore_rounded,
                    ),
                    if (actionState == ClueActionState.gpsValidated ||
                        actionState == ClueActionState.uploading ||
                        actionState == ClueActionState.submitted) ...[
                      const SizedBox(width: 8),
                      _Badge(
                        label: 'GPS OK',
                        color: AppColors.success,
                        icon: Icons.gps_fixed_rounded,
                        glow: true,
                      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8)),
                    ],
                    const Spacer(),
                    Text(
                      '$stepOrder / $totalSteps',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Texto del acertijo
                Text(
                  riddleText,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Sección de pista extra ───────────────────────────────
                _buildHintSection(),
                const SizedBox(height: 14),

                // Acción dinámica
                _buildAction(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintSection() {
    // Sin pista disponible para esta clue
    if (hintCost == 0) return const SizedBox.shrink();

    // Pista ya desbloqueada
    if (hintText != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accentGold.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentGold.withOpacity(0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_rounded,
                color: AppColors.accentGold, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hintText!,
                style: const TextStyle(
                  color: AppColors.accentGold,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
    }

    // Botón para desbloquear
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: hintLoading ? null : onUnlockHint,
        icon: hintLoading
            ? const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 1.8, color: AppColors.accentGold))
            : const Icon(Icons.lightbulb_outline_rounded, size: 16),
        label: Text(
          hintLoading ? 'Desbloqueando...' : 'Pista extra · $hintCost monedas',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentGold,
          side: BorderSide(color: AppColors.accentGold.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(0, 40),
        ),
      ),
    );
  }

  Widget _buildAction() {
    switch (actionState) {
      case ClueActionState.idle:
        return _GradientButton(
          onPressed: onCheckIn,
          icon: Icons.location_on_rounded,
          label: '¡Estoy aquí!',
          colors: [AppColors.accentCyan, const Color(0xFF00BFA5)],
        );

      case ClueActionState.checkingGps:
        return _GradientButton(
          onPressed: null,
          icon: null,
          label: 'Comprobando ubicación...',
          colors: [AppColors.textSecondary, AppColors.textSecondary],
          loading: true,
        );

      case ClueActionState.tooFar:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (distanceMeters != null && distanceMeters! >= 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.near_me_rounded,
                        color: AppColors.accentGold, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      distanceMeters! >= 1000
                          ? 'Estás a ${(distanceMeters! / 1000).toStringAsFixed(1)} km'
                          : 'Estás a $distanceMeters m del objetivo',
                      style: const TextStyle(
                        color: AppColors.accentGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _GradientButton(
              onPressed: onCheckIn,
              icon: Icons.location_off_rounded,
              label: 'Demasiado lejos... inténtalo de nuevo',
              colors: [AppColors.error, const Color(0xFFD32F2F)],
            ),
          ],
        );

      case ClueActionState.gpsValidated:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '¡Última pista! Toma la foto de victoria como prueba.',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '📸 Recuerda: Todos los miembros del equipo deben salir en la foto',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            _GradientButton(
              onPressed: onTakePhoto,
              icon: Icons.camera_alt_rounded,
              label: 'Tomar foto de victoria',
              colors: [AppColors.accentGold, AppColors.accentCoral],
            ).animate().slideY(begin: 0.4, duration: 350.ms, curve: Curves.easeOut).fadeIn(duration: 300.ms),
          ],
        );

      case ClueActionState.autoValidating:
        return _GradientButton(
          onPressed: null,
          icon: null,
          label: '¡Pista superada! Cargando la siguiente...',
          colors: [AppColors.success, const Color(0xFF00C853)],
          loading: true,
        ).animate().fadeIn(duration: 250.ms);

      case ClueActionState.uploading:
        return _GradientButton(
          onPressed: null,
          icon: null,
          label: 'Subiendo foto...',
          colors: [AppColors.accentGold, AppColors.accentCoral],
          loading: true,
        );

      case ClueActionState.submitted:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accentCyan.withOpacity(0.08),
                AppColors.success.withOpacity(0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accentCyan.withOpacity(0.4), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icono pulsante
              const Icon(Icons.hourglass_top_rounded,
                      color: AppColors.accentCyan, size: 28)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end:   const Offset(1.1, 1.1),
                    duration: 1000.ms,
                    curve: Curves.easeInOut,
                  )
                  .tint(color: AppColors.accentCyan),
              const SizedBox(height: 8),
              const Text(
                'Validando tu hallazgo con el Maestro del Tesoro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Mantente atento — se actualizará automáticamente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              // Dots animados
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) =>
                  Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentCyan,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(delay: (250 * i).ms, duration: 300.ms)
                  .then()
                  .fadeOut(duration: 300.ms)
                  .then()
                  .fadeIn(duration: 300.ms),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool glow;

  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
        boxShadow: glow
            ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData? icon;
  final String label;
  final List<Color> colors;
  final bool loading;

  const _GradientButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.colors,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: disabled
                ? [colors[0].withOpacity(0.35), colors.last.withOpacity(0.35)]
                : colors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: disabled
              ? null
              : [BoxShadow(color: colors[0].withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.backgroundDark),
                  )
                else if (icon != null)
                  Icon(icon, color: AppColors.backgroundDark, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.backgroundDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
