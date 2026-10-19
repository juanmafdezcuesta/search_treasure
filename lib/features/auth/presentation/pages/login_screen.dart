import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/theme/app_theme.dart';
import 'package:consola_tesoro/features/auth/presentation/pages/email_confirmation_screen.dart';

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

  bool _isRegister     = false;
  bool _loading        = false;
  bool _showPassword   = false;
  bool _termsAccepted  = false;
  final _aliasCtrl     = TextEditingController();
  String    _registerRegion = 'Asturias';
  DateTime? _birthDate;

  static const List<String> _regions = [
    'Andalucía', 'Aragón', 'Asturias', 'Illes Balears', 'Canarias',
    'Cantabria', 'Castilla-La Mancha', 'Castilla y León', 'Cataluña',
    'C. Valenciana', 'Extremadura', 'Galicia', 'La Rioja',
    'Comunidad de Madrid', 'Región de Murcia', 'Navarra', 'País Vasco',
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _aliasCtrl.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'FECHA DE NACIMIENTO',
      confirmText: 'CONFIRMAR',
      cancelText: 'CANCELAR',
      builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!),
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  void _showTermsDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Exención de Responsabilidad',
          style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w700),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Al participar en Consola del Tesoro, el jugador asume plena responsabilidad de su seguridad física y vial durante la búsqueda. '
            'Las actividades tienen lugar en entornos exteriores que pueden presentar riesgos naturales o de tráfico. '
            'Los organizadores no se hacen responsables de accidentes, lesiones, daños materiales ni perjuicios de ningún tipo '
            'derivados de la participación en las pruebas.\n\n'
            'El jugador se compromete a:\n'
            '• Respetar las normas de circulación en todo momento.\n'
            '• No acceder a propiedades privadas sin autorización.\n'
            '• Actuar con prudencia y respeto hacia el entorno y otras personas.\n'
            '• Informar de cualquier incidencia a los organizadores.\n\n'
            'La participación implica la aceptación íntegra de estas condiciones.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_isRegister && !_termsAccepted) {
      _snack('Acepta los términos para continuar.', color: AppColors.accentCoral);
      return;
    }
    if (_isRegister) {
      if (_birthDate == null) {
        _snack('La fecha de nacimiento es obligatoria', color: AppColors.error);
        return;
      }
      if (_calculateAge(_birthDate!) < 16) {
        _snack(
          'Debes tener al menos 16 años para jugar y reclamar recompensas reales',
          color: AppColors.error,
        );
        return;
      }
    }
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      if (_isRegister) {
        final alias = _aliasCtrl.text.trim();
        final birthIso = '${_birthDate!.year}-'
            '${_birthDate!.month.toString().padLeft(2, '0')}-'
            '${_birthDate!.day.toString().padLeft(2, '0')}';

        final res = await _client.auth.signUp(
          email: email,
          password: password,
          data: {
            'username':   alias.isNotEmpty ? alias : email.split('@').first,
            'birth_date': birthIso,
          },
        );
        if (!mounted) return;

        if (res.session == null) {
          if (!mounted) return;
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => EmailConfirmationScreen(email: email),
            ),
          );
          if (!mounted) return;
          setState(() { _isRegister = false; _birthDate = null; });
        } else if (res.user != null) {
          await _client.from('profiles').upsert({
            'id':            res.user!.id,
            'username':      alias.isNotEmpty ? alias : email.split('@').first,
            'origin_region': _registerRegion,
            'birth_date':    birthIso,
          });
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
    if (_isRegister && !_termsAccepted) {
      _snack('Acepta los términos para continuar.', color: AppColors.accentCoral);
      return;
    }
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
                              // ── Campos extra de registro ──────────────
                              if (_isRegister) ...[
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _aliasCtrl,
                                  enabled: !_loading,
                                  style: const TextStyle(color: AppColors.textPrimary),
                                  decoration: const InputDecoration(
                                    labelText: 'Alias o Nombre del Equipo',
                                    hintText: 'Sin espacios · aparecerá en el ranking',
                                    prefixIcon: Icon(Icons.badge_rounded),
                                  ),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.isEmpty) return 'Elige un alias para el ranking.';
                                    if (s.contains(' ')) return 'Sin espacios, por favor.';
                                    if (s.contains('@')) return 'No uses un email como alias.';
                                    if (s.length < 3) return 'Mínimo 3 caracteres.';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _registerRegion,
                                  items: _regions
                                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                      .toList(),
                                  onChanged: _loading
                                      ? null
                                      : (v) => setState(() => _registerRegion = v ?? 'Asturias'),
                                  decoration: const InputDecoration(
                                    labelText: 'Tu Comunidad Autónoma',
                                    prefixIcon: Icon(Icons.public_rounded),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // ── Selector de fecha de nacimiento ──────
                                InkWell(
                                  onTap: _loading ? null : _pickBirthDate,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Fecha de nacimiento *',
                                      prefixIcon: const Icon(Icons.cake_rounded),
                                      suffixIcon: Icon(
                                        Icons.calendar_month_rounded,
                                        size: 20,
                                        color: _birthDate != null
                                            ? AppColors.accentCyan
                                            : null,
                                      ),
                                    ),
                                    isEmpty: _birthDate == null,
                                    child: _birthDate == null
                                        ? const SizedBox.shrink()
                                        : Text(
                                            '${_birthDate!.day.toString().padLeft(2, '0')} / '
                                            '${_birthDate!.month.toString().padLeft(2, '0')} / '
                                            '${_birthDate!.year}',
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              // ── Términos y condiciones (solo en registro) ──
                              if (_isRegister) ...[
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: _loading
                                    ? null
                                    : () => setState(
                                        () => _termsAccepted = !_termsAccepted),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _termsAccepted,
                                        onChanged: _loading
                                            ? null
                                            : (v) => setState(
                                                () => _termsAccepted = v ?? false),
                                        activeColor: AppColors.accentCyan,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(5)),
                                        side: BorderSide(
                                            color: AppColors.accentCyan
                                                .withOpacity(0.5)),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              height: 1.45),
                                          children: [
                                            const TextSpan(
                                              text:
                                                  'Acepto los Términos de Uso y asumo la responsabilidad de mi seguridad vial y física durante la búsqueda. ',
                                            ),
                                            WidgetSpan(
                                              alignment:
                                                  PlaceholderAlignment.baseline,
                                              baseline: TextBaseline.alphabetic,
                                              child: GestureDetector(
                                                onTap: _showTermsDialog,
                                                child: const Text(
                                                  'Leer más',
                                                  style: TextStyle(
                                                    color: AppColors.accentCyan,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    decoration:
                                                        TextDecoration.underline,
                                                    decorationColor:
                                                        AppColors.accentCyan,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              ], // end if (_isRegister)
                              ElevatedButton(
                                onPressed: (_loading || (_isRegister && !_termsAccepted)) ? null : _submit,
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
                                onPressed: (_loading || (_isRegister && !_termsAccepted)) ? null : _guest,
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
                              Text(
                                'Nota: El modo invitado permite probar la app, pero necesitas una cuenta registrada para reclamar premios.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary.withOpacity(0.65),
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => setState(() {
                                            _isRegister = !_isRegister;
                                            _birthDate  = null;
                                          }),
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
        const SizedBox(height: 10),
        const Text(
          'Explora tu ciudad en vivo, supera pruebas por GPS y gana premios reales.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
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

