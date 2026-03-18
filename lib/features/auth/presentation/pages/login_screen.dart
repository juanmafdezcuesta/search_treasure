import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _client = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isRegister = false;
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      if (_isRegister) {
        final res = await _client.auth.signUp(email: email, password: password);
        if (!mounted) return;

        // Si el proyecto requiere confirmación por email, la sesión puede venir nula.
        if (res.session == null) {
          _snack(
            'Cuenta creada. Revisa tu correo para confirmar y luego entra.',
            color: AppColors.accentGold,
          );
        }
      } else {
        await _client.auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _snack(_humanAuthError(e.message), color: AppColors.error);
    } catch (e) {
      if (!mounted) return;
      _snack('Error inesperado: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guest() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final res = await _client.auth.signInAnonymously();
      if (!mounted) return;
      if (res.user == null) {
        _snack(
          'No se pudo iniciar como invitado. Habilita "Anonymous Sign-ins" en Supabase.',
          color: AppColors.error,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      _snack(_humanAuthError(e.message), color: AppColors.error);
    } catch (e) {
      if (!mounted) return;
      _snack('Error inesperado: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _humanAuthError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return 'Email o contraseña incorrectos.';
    }
    if (m.contains('password') && m.contains('short')) {
      return 'La contraseña es demasiado corta.';
    }
    if (m.contains('email') && m.contains('invalid')) {
      return 'El email no parece válido.';
    }
    if (m.contains('user already registered') || m.contains('already registered')) {
      return 'Ese email ya está registrado. Prueba a entrar.';
    }
    if (m.contains('email not confirmed')) {
      return 'Tu email aún no está confirmado. Revisa tu correo.';
    }
    return msg;
  }

  void _snack(String msg, {Color color = AppColors.accentCyan}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegister ? 'Crear cuenta' : 'Entrar';
    final subtitle = _isRegister
        ? 'Regístrate y guarda tu progreso.'
        : 'Inicia sesión para continuar tu búsqueda.';

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
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(title: title, subtitle: subtitle),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                enabled: !_loading,
                                style: const TextStyle(color: AppColors.textPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'tu@email.com',
                                  prefixIcon: Icon(Icons.alternate_email_rounded),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return 'Escribe tu email.';
                                  if (!s.contains('@')) return 'Email no válido.';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passCtrl,
                                obscureText: !_showPassword,
                                autofillHints: _isRegister
                                    ? const [AutofillHints.newPassword]
                                    : const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                enabled: !_loading,
                                style: const TextStyle(color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  hintText: _isRegister ? 'Mínimo 6 caracteres' : 'Tu contraseña',
                                  prefixIcon: const Icon(Icons.lock_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                                    onPressed: _loading
                                        ? null
                                        : () => setState(() => _showPassword = !_showPassword),
                                    icon: Icon(
                                      _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  final s = v ?? '';
                                  if (s.isEmpty) return 'Escribe tu contraseña.';
                                  if (_isRegister && s.length < 6) {
                                    return 'Usa al menos 6 caracteres.';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: AppColors.backgroundDark,
                                        ),
                                      )
                                    : Text(_isRegister ? 'Registrarme' : 'Entrar'),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _loading ? null : _guest,
                                icon: const Icon(Icons.person_outline_rounded),
                                label: const Text('Jugar como invitado'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 52),
                                  foregroundColor: AppColors.textPrimary,
                                  side: BorderSide(color: AppColors.accentCyan.withOpacity(0.55)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => setState(() => _isRegister = !_isRegister),
                                  child: Text(
                                    _isRegister
                                        ? '¿Ya tienes cuenta? Entrar'
                                        : '¿No tienes cuenta? Registrarse',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Al entrar aceptas que se guarde tu progreso en Supabase.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
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

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.accentCyan.withOpacity(0.12),
                border: Border.all(color: AppColors.accentCyan.withOpacity(0.35)),
              ),
              child: const Icon(Icons.map_rounded, color: AppColors.accentCyan),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Consola del Tesoro',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
        ),
      ],
    );
  }
}

