import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/theme/app_theme.dart';

class EmailConfirmationScreen extends StatefulWidget {
  final String email;
  const EmailConfirmationScreen({super.key, required this.email});

  @override
  State<EmailConfirmationScreen> createState() => _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> {
  final _client = Supabase.instance.client;
  bool _resending = false;

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await _client.auth.resend(type: OtpType.signup, email: widget.email);
      if (!mounted) return;
      _snack('Email reenviado. Revisa tu bandeja de entrada.', color: AppColors.success);
    } on AuthException catch (e) {
      if (!mounted) return;
      _snack(e.message, color: AppColors.error);
    } catch (_) {
      if (!mounted) return;
      _snack('No se pudo reenviar el email.', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _snack(String msg, {Color color = AppColors.accentCyan}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundDark,
              Color(0xFF0B2A2C),
              AppColors.backgroundDark,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentCyan.withOpacity(0.10),
                        border: Border.all(
                            color: AppColors.accentCyan.withOpacity(0.35), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentCyan.withOpacity(0.18),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_rounded,
                        color: AppColors.accentCyan,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Título
                    const Text(
                      'Revisa tu correo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Mensaje
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          height: 1.55,
                        ),
                        children: [
                          const TextSpan(
                              text:
                                  'Te hemos enviado un enlace de verificación a\n'),
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                              color: AppColors.accentCyan,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(
                              text:
                                  '\n\nConfirma tu cuenta pulsando el enlace del email y después vuelve aquí para entrar.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Aviso spam
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.accentGold.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline_rounded,
                              color: AppColors.accentGold, size: 16),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Si no lo ves, revisa la carpeta de spam o correo no deseado.',
                              style: TextStyle(
                                color: AppColors.accentGold,
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botón principal: volver al login
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Ya confirmé · Entrar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentCyan,
                          foregroundColor: AppColors.backgroundDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Botón secundario: reenviar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _resending ? null : _resend,
                        icon: _resending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textSecondary),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: const Text('Reenviar email'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(
                              color: AppColors.accentCyan.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
