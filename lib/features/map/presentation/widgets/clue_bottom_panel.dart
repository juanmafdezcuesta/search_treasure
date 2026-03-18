import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:consola_tesoro/core/theme/app_theme.dart';

// Estado de la acción del panel — controla qué botón y qué mensaje se muestra
enum ClueActionState {
  idle,          // "¡Estoy aquí!" — esperando que el usuario pulse
  checkingGps,   // "Comprobando..." — RPC en curso
  tooFar,        // "Demasiado lejos..." — fallo de proximidad
  gpsValidated,  // "📸 Tomar foto de prueba" — GPS ok, falta foto
  uploading,     // "Subiendo foto..." — upload en curso
  submitted,     // "✓ Foto enviada" — pendiente de validación del Maestro
}

class ClueBottomPanel extends StatelessWidget {
  final String          riddleText;
  final ClueActionState actionState;
  final VoidCallback    onCheckIn;
  final VoidCallback?   onTakePhoto;  // activo solo en gpsValidated

  const ClueBottomPanel({
    super.key,
    required this.riddleText,
    required this.actionState,
    required this.onCheckIn,
    this.onTakePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle visual
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Etiqueta de pista + badge de estado GPS
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentCoral.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentCoral, width: 1),
                ),
                child: const Text(
                  'PISTA ACTIVA',
                  style: TextStyle(
                    color: AppColors.accentCoral, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2,
                  ),
                ),
              ),
              if (actionState == ClueActionState.gpsValidated ||
                  actionState == ClueActionState.uploading ||
                  actionState == ClueActionState.submitted) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gps_fixed_rounded,
                          color: AppColors.success, size: 11),
                      SizedBox(width: 4),
                      Text('GPS OK',
                        style: TextStyle(
                          color: AppColors.success, fontSize: 11,
                          fontWeight: FontWeight.w700, letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8)),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Texto del acertijo
          Text(
            riddleText,
            style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 15, height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // ── Botón / estado dinámico ───────────────────────────────────
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    switch (actionState) {
      // ── Estado inicial ─────────────────────────────────────────────────
      case ClueActionState.idle:
        return _ActionButton(
          onPressed:  onCheckIn,
          icon:       Icons.location_on_rounded,
          label:      '¡Estoy aquí!',
          color:      AppColors.accentCyan,
        );

      // ── Consultando Supabase ────────────────────────────────────────────
      case ClueActionState.checkingGps:
        return _ActionButton(
          onPressed:  null,
          icon:       null,
          label:      'Comprobando ubicación...',
          color:      AppColors.textSecondary,
          loading:    true,
        );

      // ── Demasiado lejos ─────────────────────────────────────────────────
      case ClueActionState.tooFar:
        return _ActionButton(
          onPressed:  onCheckIn,
          icon:       Icons.location_off_rounded,
          label:      'Demasiado lejos... inténtalo de nuevo',
          color:      AppColors.error,
        );

      // ── GPS ok → pedir foto ─────────────────────────────────────────────
      case ClueActionState.gpsValidated:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¡Ubicación confirmada! Ahora toma una foto como prueba.',
              style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            _ActionButton(
              onPressed:  onTakePhoto,
              icon:       Icons.camera_alt_rounded,
              label:      'Tomar foto de prueba',
              color:      AppColors.accentGold,
            ).animate()
                .slideY(begin: 0.4, duration: 350.ms, curve: Curves.easeOut)
                .fadeIn(duration: 300.ms),
          ],
        );

      // ── Subiendo foto ───────────────────────────────────────────────────
      case ClueActionState.uploading:
        return _ActionButton(
          onPressed:  null,
          icon:       null,
          label:      'Subiendo foto...',
          color:      AppColors.accentGold,
          loading:    true,
        );

      // ── Foto enviada, pendiente de validación ───────────────────────────
      case ClueActionState.submitted:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color:        AppColors.success.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(color: AppColors.success, width: 1.5),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.success, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Foto enviada — esperando validación del Maestro',
                  style: TextStyle(
                    color: AppColors.success, fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón genérico reutilizado por todos los estados
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData?     icon;
  final String        label;
  final Color         color;
  final bool          loading;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed == null ? color.withOpacity(0.45) : color,
          foregroundColor: AppColors.backgroundDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: onPressed == null ? 0 : 2,
        ),
        icon: loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: AppColors.backgroundDark))
            : (icon != null ? Icon(icon, size: 20) : const SizedBox.shrink()),
        label: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
