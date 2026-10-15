import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/theme/app_theme.dart';

class PublicProfileScreen extends StatefulWidget {
  final String profileId;
  const PublicProfileScreen({super.key, required this.profileId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  String _username = 'Explorador';
  String? _avatarUrl;
  String? _originRegion;
  DateTime? _createdAt;
  int _xp = 0;

  List<Map<String, dynamic>> _trophies = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _supabase
          .from('profiles')
          .select('id, username, avatar_url, origin_region, created_at, xp')
          .eq('id', widget.profileId)
          .maybeSingle();

      if (profile == null) {
        setState(() {
          _error = 'No se encontró el perfil.';
          _loading = false;
        });
        return;
      }

      final trophies = await _supabase.rpc('get_public_trophies', params: {
        'p_profile_id': widget.profileId,
      }) as List<dynamic>;

      setState(() {
        _username = (profile['username'] as String?)?.trim().isNotEmpty == true
            ? (profile['username'] as String).trim()
            : 'Explorador';
        _avatarUrl = (profile['avatar_url'] as String?)?.trim().isNotEmpty == true
            ? (profile['avatar_url'] as String).trim()
            : null;
        _originRegion =
            (profile['origin_region'] as String?)?.trim().isNotEmpty == true
                ? (profile['origin_region'] as String).trim()
                : null;
        _createdAt = DateTime.tryParse((profile['created_at'] as String?) ?? '');
        _xp = (profile['xp'] as num?)?.toInt() ?? 0;
        // Deduplicar por hunt_id para evitar sellos repetidos
        final seen = <String>{};
        _trophies = trophies
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((t) {
              final id = (t['hunt_id'] ?? t['hunt_title']) as String?;
              if (id == null) return true;
              return seen.add(id);
            })
            .toList();
        _loading = false;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = _supabase.auth.currentUser?.id == widget.profileId;
    final since = _createdAt == null ? null : _formatMonthYearEs(_createdAt!);
    final level = (_xp ~/ 1000) + 1;
    final xpInLevel = _xp % 1000;
    const xpNext = 1000;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Perfil público',
          style: TextStyle(
            color: AppColors.accentCyan,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (isMe)
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _username));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Nombre copiado al portapapeles',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              },
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Compartir mi carnet'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentGold,
              ),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AdventurerCard(
                          username: _username,
                          avatarUrl: _avatarUrl,
                          originRegion: _originRegion,
                          explorerSince: since,
                          level: level,
                          xpInLevel: xpInLevel,
                          xpNext: xpNext,
                        ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.04),
                        const SizedBox(height: 14),
                        Text(
                          'Tesoros Conquistados',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 10),
                        if (_trophies.isEmpty)
                          const _HintCard(
                            message: 'Aún no hay tesoros conquistados.',
                          )
                        else
                          _StampGrid(
                            trophies: _trophies,
                            originRegion: _originRegion,
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _formatMonthYearEs(DateTime dt) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final m = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
    return '$m ${dt.year}';
  }
}

class _AdventurerCard extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final String? originRegion;
  final String? explorerSince;
  final int level;
  final int xpInLevel;
  final int xpNext;

  const _AdventurerCard({
    required this.username,
    required this.avatarUrl,
    required this.originRegion,
    required this.explorerSince,
    required this.level,
    required this.xpInLevel,
    required this.xpNext,
  });

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    return Card(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accentCyan.withOpacity(0.16),
              AppColors.cardDark,
            ],
          ),
          border: Border.all(color: AppColors.accentCyan.withOpacity(0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.accentGold.withOpacity(0.55), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentCyan.withOpacity(0.18),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                    image: (url != null && url.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(url),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (url == null || url.isEmpty)
                      ? const Icon(Icons.person_rounded,
                          size: 40, color: AppColors.textSecondary)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Carnet de Aventurero',
                        style: TextStyle(
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        username,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (explorerSince != null && explorerSince!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Explorador desde: $explorerSince',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.public_rounded,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              (originRegion == null || originRegion!.trim().isEmpty)
                                  ? 'Comunidad de origen: —'
                                  : 'Comunidad de origen: $originRegion',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: AppColors.accentGold.withOpacity(0.35)),
                            ),
                            child: Text(
                              'Nivel $level',
                              style: const TextStyle(
                                color: AppColors.accentGold,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'XP: $xpInLevel / $xpNext',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: xpNext <= 0 ? 0 : (xpInLevel / xpNext).clamp(0, 1),
                          minHeight: 10,
                          backgroundColor: AppColors.backgroundDark.withOpacity(0.55),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accentCyan.withOpacity(0.95)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.badge_rounded, color: AppColors.accentCyan, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Este perfil es de solo lectura.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StampGrid extends StatelessWidget {
  final List<Map<String, dynamic>> trophies;
  final String? originRegion;

  const _StampGrid({
    required this.trophies,
    required this.originRegion,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < trophies.length; i++)
          _Stamp(
            index: i,
            title: (trophies[i]['hunt_title'] as String?) ?? 'Tesoro',
            huntRegion: (trophies[i]['hunt_region'] as String?)?.trim(),
            validatedAt: trophies[i]['validated_at']?.toString(),
            originRegion: originRegion,
          ),
      ],
    );
  }
}

class _Stamp extends StatelessWidget {
  final int index;
  final String title;
  final String? huntRegion;
  final String? validatedAt;
  final String? originRegion;

  const _Stamp({
    required this.index,
    required this.title,
    required this.huntRegion,
    required this.validatedAt,
    required this.originRegion,
  });

  @override
  Widget build(BuildContext context) {
    final traveler = originRegion != null &&
        huntRegion != null &&
        huntRegion!.isNotEmpty &&
        originRegion!.trim().isNotEmpty &&
        huntRegion != originRegion;

    final angle = (index.isEven ? -1 : 1) * 0.012;
    final accent = traveler ? AppColors.accentCyan : AppColors.accentGold;

    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 164,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (huntRegion != null && huntRegion!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.place_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      huntRegion!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (traveler)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.accentCyan.withOpacity(0.35)),
                    ),
                    child: const Text(
                      'Viajero',
                      style: TextStyle(
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.accentGold.withOpacity(0.35)),
                    ),
                    child: const Text(
                      'Sello',
                      style: TextStyle(
                        color: AppColors.accentGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ),
                const Spacer(),
                if (validatedAt != null && validatedAt!.trim().isNotEmpty)
                  Text(
                    _formatDateShort(validatedAt!),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateShort(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _HintCard extends StatelessWidget {
  final String message;
  const _HintCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentGold.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.accentGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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

