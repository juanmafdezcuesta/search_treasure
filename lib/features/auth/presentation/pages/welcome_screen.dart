import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:consola_tesoro/core/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onProceed;
  const WelcomeScreen({super.key, required this.onProceed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final card   = isDark ? AppColors.cardDark       : AppColors.cardLight;
    final txt    = isDark ? AppColors.textPrimary     : AppColors.textPrimaryLight;
    final sub    = isDark ? AppColors.textSecondary   : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Logo ───────────────────────────────────────────────────
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: AppColors.accentCyan.withOpacity(0.12),
                  border: Border.all(
                      color: AppColors.accentCyan.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentCyan.withOpacity(0.2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(Icons.map_rounded,
                    color: AppColors.accentCyan, size: 40),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 20),

              // ── Título ─────────────────────────────────────────────────
              Text(
                'Búsqueda del Tesoro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: txt,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              const SizedBox(height: 6),
              Text(
                'La caza del tesoro urbana para equipos',
                textAlign: TextAlign.center,
                style: TextStyle(color: sub, fontSize: 14, height: 1.4),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 32),

              // ── Descripción ────────────────────────────────────────────
              _Card(
                card: card,
                txt: txt,
                sub: sub,
                icon: Icons.emoji_events_rounded,
                color: AppColors.accentGold,
                title: '¿Qué es Búsqueda del Tesoro?',
                body: 'Una aventura real por las calles de tu ciudad. '
                    'Resuelve acertijos, llega a los puntos GPS y demuestra '
                    'que estuviste allí con una foto. El primer equipo en '
                    'completar todas las pistas gana.',
                delay: 250,
              ),
              const SizedBox(height: 12),

              // ── Reglas en pasos ────────────────────────────────────────
              _Card(
                card: card,
                txt: txt,
                sub: sub,
                icon: Icons.list_alt_rounded,
                color: AppColors.accentCyan,
                title: 'Cómo se juega',
                body: null,
                delay: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Step(n: '1', txt: txt, sub: sub,
                        text: 'Elige una búsqueda activa en tu comunidad.'),
                    _Step(n: '2', txt: txt, sub: sub,
                        text: 'Lee el acertijo de la pista actual y desplázate hasta el lugar.'),
                    _Step(n: '3', txt: txt, sub: sub,
                        text: 'Pulsa "¡Estoy aquí!" cuando estés cerca. El GPS lo verifica en el servidor.'),
                    _Step(n: '4', txt: txt, sub: sub,
                        text: 'En la última pista, toma una foto de todo el equipo como prueba.'),
                    _Step(n: '5', txt: txt, sub: sub,
                        text: 'El Maestro del Tesoro aprueba la foto. ¡Si eres el primero, ganas!'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── XP y nivel ────────────────────────────────────────────
              _Card(
                card: card,
                txt: txt,
                sub: sub,
                icon: Icons.bolt_rounded,
                color: AppColors.accentCoral,
                title: 'Puntos de experiencia (XP)',
                body: 'Ganas XP al validar cada punto GPS (más XP si eres '
                    'de los primeros en llegar) y +500 XP al completar una '
                    'búsqueda. Sube de nivel y aparece en el ranking nacional.',
                delay: 450,
              ),
              const SizedBox(height: 12),

              // ── Normas ────────────────────────────────────────────────
              _Card(
                card: card,
                txt: txt,
                sub: sub,
                icon: Icons.shield_rounded,
                color: AppColors.accentFuchsia,
                title: 'Normas básicas',
                body: '• Respeta las normas de circulación en todo momento.\n'
                    '• No accedas a propiedades privadas sin autorización.\n'
                    '• Actúa con prudencia y respeto hacia el entorno.\n'
                    '• Edad mínima: 16 años.',
                delay: 550,
              ),
              const SizedBox(height: 32),

              // ── Botón principal ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accentCyan, Color(0xFF00BFA5)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentCyan.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: onProceed,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              color: AppColors.backgroundDark, size: 24),
                          SizedBox(width: 8),
                          Text(
                            '¡Comenzar la aventura!',
                            style: TextStyle(
                              color: AppColors.backgroundDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms)
                  .slideY(begin: 0.3, curve: Curves.easeOut),
              const SizedBox(height: 16),

              // ── Ya tengo cuenta ────────────────────────────────────────
              GestureDetector(
                onTap: onProceed,
                child: Text(
                  'Ya tengo cuenta — Entrar',
                  style: TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).animate().fadeIn(delay: 700.ms),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de sección ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Color card;
  final Color txt;
  final Color sub;
  final IconData icon;
  final Color color;
  final String title;
  final String? body;
  final Widget? child;
  final int delay;

  const _Card({
    required this.card,
    required this.txt,
    required this.sub,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.delay,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: txt,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (body != null) ...[
            const SizedBox(height: 10),
            Text(
              body!,
              style: TextStyle(color: sub, fontSize: 13, height: 1.55),
            ),
          ],
          if (child != null) ...[
            const SizedBox(height: 10),
            child!,
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .slideY(begin: 0.15, curve: Curves.easeOut);
  }
}

// ── Paso numerado ────────────────────────────────────────────────────────────

class _Step extends StatelessWidget {
  final String n;
  final Color txt;
  final Color sub;
  final String text;

  const _Step({
    required this.n,
    required this.txt,
    required this.sub,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentCyan.withOpacity(0.5)),
            ),
            child: Center(
              child: Text(
                n,
                style: const TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: sub, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
