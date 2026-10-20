import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/session/app_session.dart';
import 'package:consola_tesoro/core/theme/app_theme.dart';
import 'package:consola_tesoro/data/repositories/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  late final ProfileRepository _repo;

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();

  bool    _loading = true;
  bool    _saving = false;
  String? _error;
  String? _originRegion;
  String? _selectedAvatarPreset;

  static const List<String> _avatarPresets = [
    'https://api.dicebear.com/7.x/bottts/png?seed=Explorer',
    'https://api.dicebear.com/7.x/bottts/png?seed=Ranger',
    'https://api.dicebear.com/7.x/bottts/png?seed=Scout',
    'https://api.dicebear.com/7.x/bottts/png?seed=Wanderer',
    'https://api.dicebear.com/7.x/bottts/png?seed=Hunter',
    'https://api.dicebear.com/7.x/bottts/png?seed=Navigator',
    'https://api.dicebear.com/7.x/bottts/png?seed=Pioneer',
    'https://api.dicebear.com/7.x/bottts/png?seed=Adventurer',
  ];

  static const List<String> _regions = [
    'Andalucía',
    'Aragón',
    'Asturias',
    'Illes Balears',
    'Canarias',
    'Cantabria',
    'Castilla-La Mancha',
    'Castilla y León',
    'Cataluña',
    'C. Valenciana',
    'Extremadura',
    'Galicia',
    'La Rioja',
    'Comunidad de Madrid',
    'Región de Murcia',
    'Navarra',
    'País Vasco',
  ];

  @override
  void initState() {
    super.initState();
    _repo = ProfileRepository(_supabase);
    _hydrateFromSession();
    _load();
  }

  void _hydrateFromSession() {
    final p = AppSession.profile.value;
    if (p == null) return;
    _usernameCtrl.text = p.username;
    _avatarCtrl.text = p.avatarUrl ?? '';
    _originRegion = p.originRegion;
    _selectedAvatarPreset =
        _avatarPresets.contains(p.avatarUrl) ? p.avatarUrl : null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _repo.getMyProfile();
      if (!mounted) return;
      setState(() {
        _usernameCtrl.text = p.username;
        _avatarCtrl.text = p.avatarUrl ?? '';
        _originRegion = p.originRegion;
        _selectedAvatarPreset =
            _avatarPresets.contains(p.avatarUrl) ? p.avatarUrl : null;
        _loading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await _repo.updateMyProfile(
        username: _usernameCtrl.text,
        avatarUrl: _avatarCtrl.text,
        originRegion: _originRegion,
      );
      if (!mounted) return;
      _snack('Perfil actualizado', color: AppColors.success);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _snack(e.message, color: AppColors.error);
    } on AuthException catch (e) {
      if (!mounted) return;
      _snack(e.message, color: AppColors.error);
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppSession.profile.value;
    final avatarUrl = _avatarCtrl.text.trim().isEmpty ? (p?.avatarUrl ?? '') : _avatarCtrl.text.trim();
    final avatar = avatarUrl.isEmpty
        ? null
        : NetworkImage(avatarUrl);

    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.surfaceDark, Color(0xFF0C1220)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accentCyan.withOpacity(0.7),
                      AppColors.accentCyan.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        title: const Text(
          'Mi perfil',
          style: TextStyle(
            color: AppColors.accentCyan,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accentCyan),
              )
            : _error != null
                ? _CenteredMessage(
                    icon: Icons.error_outline_rounded,
                    iconColor: AppColors.error,
                    message: _error!,
                    actionLabel: 'Reintentar',
                    onAction: _load,
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          color: AppColors.cardDark,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                            child: Column(
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.accentCyan.withOpacity(0.45),
                                        width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accentCyan.withOpacity(0.18),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                    image: avatar != null
                                        ? DecorationImage(image: avatar, fit: BoxFit.cover)
                                        : null,
                                  ),
                                  child: avatar == null
                                      ? const Icon(Icons.person_rounded,
                                          size: 48, color: AppColors.textSecondary)
                                      : null,
                                ).animate().fadeIn(duration: 220.ms).scale(begin: const Offset(0.96, 0.96)),
                                const SizedBox(height: 12),
                                Text(
                                  p?.username ?? 'Jugador',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                ),
                                if ((_originRegion ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _originRegion!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          color: AppColors.cardDark,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _usernameCtrl,
                                    enabled: !_saving,
                                    style: const TextStyle(color: AppColors.textPrimary),
                                    decoration: const InputDecoration(
                                      labelText: 'Alias o Nombre del Equipo',
                                      prefixIcon: Icon(Icons.badge_rounded),
                                    ),
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) return 'Escribe un nombre de usuario.';
                                      if (s.length < 3) return 'Usa al menos 3 caracteres.';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Elige tu avatar',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 68,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _avatarPresets.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                                      itemBuilder: (_, i) {
                                        final url = _avatarPresets[i];
                                        final selected = _selectedAvatarPreset == url;
                                        return GestureDetector(
                                          onTap: _saving ? null : () => setState(() {
                                            _selectedAvatarPreset = url;
                                            _avatarCtrl.text = url;
                                          }),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: selected
                                                    ? AppColors.accentCyan
                                                    : AppColors.textSecondary.withOpacity(0.2),
                                                width: selected ? 2.5 : 1.5,
                                              ),
                                              boxShadow: selected
                                                  ? [BoxShadow(
                                                      color: AppColors.accentCyan.withOpacity(0.35),
                                                      blurRadius: 10,
                                                    )]
                                                  : null,
                                            ),
                                            child: ClipOval(
                                              child: Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Icon(
                                                  Icons.person_rounded,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: _originRegion != null && _regions.contains(_originRegion)
                                        ? _originRegion
                                        : null,
                                    items: _regions
                                        .map((r) => DropdownMenuItem(
                                              value: r,
                                              child: Text(r),
                                            ))
                                        .toList(),
                                    onChanged: _saving ? null : (v) => setState(() => _originRegion = v),
                                    decoration: const InputDecoration(
                                      labelText: 'Comunidad Autónoma de origen',
                                      prefixIcon: Icon(Icons.public_rounded),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _saving ? null : _save,
                                    child: _saving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: AppColors.backgroundDark,
                                            ),
                                          )
                                        : const Text('Guardar cambios'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // ── Selector de tema ─────────────────────────────
                        Card(
                          color: AppColors.cardDark,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                            child: Row(
                              children: [
                                Icon(Icons.brightness_6_rounded,
                                    color: AppColors.accentCyan, size: 20),
                                const SizedBox(width: 12),
                                const Text(
                                  'Apariencia',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                ValueListenableBuilder<ThemeMode>(
                                  valueListenable: AppSession.themeMode,
                                  builder: (ctx, mode, _) =>
                                      DropdownButton<ThemeMode>(
                                    value: mode,
                                    underline: const SizedBox.shrink(),
                                    dropdownColor: AppColors.cardDark,
                                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                    items: const [
                                      DropdownMenuItem(
                                          value: ThemeMode.system,
                                          child: Text('Sistema')),
                                      DropdownMenuItem(
                                          value: ThemeMode.light,
                                          child: Text('Claro')),
                                      DropdownMenuItem(
                                          value: ThemeMode.dark,
                                          child: Text('Oscuro')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) AppSession.themeMode.value = v;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _supabase.auth.signOut();
                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Cerrar sesión'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(color: AppColors.accentCoral.withOpacity(0.6)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
      ), // Scaffold
    ); // Theme
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredMessage({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 52),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 15, height: 1.5),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      );
}

