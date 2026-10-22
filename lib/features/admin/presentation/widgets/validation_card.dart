import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:consola_tesoro/core/theme/app_theme.dart';

class PendingValidation {
  final String      progressId;
  final String      userId;
  final String      username;
  final String?     avatarUrl;
  final String      clueId;
  final int         stepOrder;
  final String      riddleText;
  final String      photoUrl;      // Ruta en el bucket (NO la URL firmada)
  final DateTime    submittedAt;
  final String?     signedPhotoUrl; // URL firmada para mostrar la imagen

  const PendingValidation({
    required this.progressId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.clueId,
    required this.stepOrder,
    required this.riddleText,
    required this.photoUrl,
    required this.submittedAt,
    this.signedPhotoUrl,
  });
}

class ValidationCard extends StatelessWidget {
  final PendingValidation validation;
  final bool              isProcessing;
  final VoidCallback      onApprove;
  final VoidCallback      onReject;

  const ValidationCard({
    super.key,
    required this.validation,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabecera: jugador + pista ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.accentCyan.withOpacity(0.15),
                  backgroundImage: validation.avatarUrl != null
                      ? NetworkImage(validation.avatarUrl!)
                      : null,
                  child: validation.avatarUrl == null
                      ? Text(
                          validation.username.isNotEmpty
                              ? validation.username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: AppColors.accentCyan,
                              fontWeight: FontWeight.w700,
                              fontSize: 18),
                        )
                      : null,
                ),
                const SizedBox(width: 12),

                // Nombre y pista
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(validation.username,
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      Text(
                        'Pista ${validation.stepOrder} · '
                        '${_formatTime(validation.submittedAt)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // Badge "Pendiente"
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accentGold, width: 1),
                  ),
                  child: const Text('PENDIENTE',
                      style: TextStyle(
                          color: AppColors.accentGold,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1)),
                ),
              ],
            ),
          ),

          // ── Texto de la pista ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.accentCoral.withOpacity(0.3), width: 1),
              ),
              child: Text(
                '"${validation.riddleText}"',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.4),
              ),
            ),
          ),

          // ── Foto enviada por el jugador ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: validation.signedPhotoUrl != null
                  ? Image.network(
                      validation.signedPhotoUrl!,
                      height: 220,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return _PhotoPlaceholder(loading: true);
                      },
                      errorBuilder: (_, __, ___) =>
                          const _PhotoPlaceholder(loading: false),
                    )
                  : const _PhotoPlaceholder(loading: false),
            ),
          ),

          // ── Botones Aprobar / Rechazar ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: isProcessing
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accentCyan))
                : Row(
                    children: [
                      // Rechazar
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Rechazar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(
                                color: AppColors.error, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Aprobar
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: onApprove,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Aprobar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: AppColors.backgroundDark,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, duration: 300.ms);
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} días';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _PhotoPlaceholder extends StatelessWidget {
  final bool loading;
  const _PhotoPlaceholder({required this.loading});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: loading
            ? const CircularProgressIndicator(color: AppColors.accentCyan)
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined,
                      color: AppColors.textSecondary, size: 40),
                  SizedBox(height: 8),
                  Text('No se pudo cargar la foto',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
      ),
    );
  }
}
