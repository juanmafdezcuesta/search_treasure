import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/session/app_session.dart';
import 'package:consola_tesoro/core/theme/app_theme.dart';
import 'package:consola_tesoro/features/profile/presentation/pages/public_profile_screen.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

enum _RankFilter { nacional, miComunidad }

class _RankingScreenState extends State<RankingScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  _RankFilter _filter = _RankFilter.nacional;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Vista `leaderboard` (columnas estrictas):
  // - profile_id, username, avatar_url, origin_region, total_hunts
  String _readUsername(Map<String, dynamic> row) =>
      (row['username'] as String?)?.trim().isNotEmpty == true
          ? (row['username'] as String).trim()
          : 'Explorador';

  String? _readAvatarUrl(Map<String, dynamic> row) {
    final v = (row['avatar_url'] as String?)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  String? _readOriginRegion(Map<String, dynamic> row) {
    final v = (row['origin_region'] as String?)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  int _readTotalHunts(Map<String, dynamic> row) {
    final v = row['total_hunts'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  int _readXp(Map<String, dynamic> row) {
    final v = row['xp'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  String _readProfileId(Map<String, dynamic> row) =>
      (row['profile_id'] as String?) ?? '';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _supabase
          .from('leaderboard')
          .select('profile_id, username, avatar_url, origin_region, total_hunts, xp');

      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
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
    final myRegion = AppSession.profile.value?.originRegion?.trim();
    final filtered = _applyFilter(_rows, myRegion: myRegion);
    final sorted = [...filtered]
      ..sort((a, b) => _readTotalHunts(b).compareTo(_readTotalHunts(a)));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.transparent : null,
        elevation: 0,
        foregroundColor: isDark ? AppColors.textPrimary : null,
        iconTheme: isDark ? const IconThemeData(color: AppColors.textPrimary) : null,
        flexibleSpace: isDark ? Container(
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
        ) : null,
        title: Text('Ranking',
            style: TextStyle(
                color: isDark ? AppColors.accentCyan : null,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, color: isDark ? AppColors.textPrimary : null),
          ),
        ],
      ),
      body: _loading
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
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: _FilterToggle(
                        filter: _filter,
                        myRegion: myRegion,
                        onChange: (f) => setState(() => _filter = f),
                      ),
                    ),
                    if (_filter == _RankFilter.miComunidad &&
                        (myRegion == null || myRegion.isEmpty))
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _HintCard(
                          message:
                              'No tienes configurada tu Comunidad de origen. Ve a tu Perfil y selecciónala para usar este filtro.',
                        ),
                      ),
                    Expanded(
                      child: sorted.isEmpty
                          ? const _CenteredMessage(
                              icon: Icons.emoji_events_outlined,
                              iconColor: AppColors.textSecondary,
                              message: 'Aún no hay entradas en el ranking.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: sorted.length,
                              itemBuilder: (_, i) {
                                final row = sorted[i];
                                final profileId = _readProfileId(row);
                                final username = _readUsername(row);
                                final avatarUrl = _readAvatarUrl(row);
                                final region = _readOriginRegion(row);
                                final count = _readTotalHunts(row);
                                final level = (_readXp(row) ~/ 1000) + 1;

                                if (i < 3) {
                                  return _PodiumTile(
                                    place: i + 1,
                                    username: username,
                                    avatarUrl: avatarUrl,
                                    originRegion: region,
                                    treasuresCompleted: count,
                                    level: level,
                                  )
                                      .withTap(
                                        enabled: profileId.isNotEmpty,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PublicProfileScreen(
                                              profileId: profileId,
                                            ),
                                          ),
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(duration: 220.ms)
                                      .slideY(begin: 0.04);
                                }

                                return _RankTile(
                                  place: i + 1,
                                  username: username,
                                  avatarUrl: avatarUrl,
                                  originRegion: region,
                                  treasuresCompleted: count,
                                  level: level,
                                )
                                    .withTap(
                                      enabled: profileId.isNotEmpty,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PublicProfileScreen(
                                            profileId: profileId,
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 180.ms)
                                    .slideY(begin: 0.03);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> rows, {
    required String? myRegion,
  }) {
    if (_filter == _RankFilter.nacional) return rows;
    final r = myRegion?.trim();
    if (r == null || r.isEmpty) return rows;
    return rows.where((x) => (_readOriginRegion(x) ?? '') == r).toList();
  }
}

extension _TapExt on Widget {
  Widget withTap({
    required bool enabled,
    required VoidCallback onTap,
  }) {
    if (!enabled) return this;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: this,
    );
  }
}

class _FilterToggle extends StatelessWidget {
  final _RankFilter filter;
  final String? myRegion;
  final ValueChanged<_RankFilter> onChange;

  const _FilterToggle({
    required this.filter,
    required this.myRegion,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = filter == _RankFilter.nacional ? 0 : 1;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB)),
      ),
      child: ToggleButtons(
        isSelected: [selected == 0, selected == 1],
        onPressed: (i) => onChange(i == 0 ? _RankFilter.nacional : _RankFilter.miComunidad),
        borderRadius: BorderRadius.circular(14),
        constraints: const BoxConstraints(minHeight: 44, minWidth: 150),
        selectedColor: isDark ? AppColors.backgroundDark : Colors.white,
        fillColor: AppColors.accentCyan,
        color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
        borderColor: Colors.transparent,
        selectedBorderColor: Colors.transparent,
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('Nacional', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('Mi Comunidad', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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
          const Icon(Icons.info_outline_rounded, color: AppColors.accentGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Builder(builder: (ctx) => Text(
              message,
              style: TextStyle(
                color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            )),
          ),
        ],
      ),
    );
  }
}

class _PodiumTile extends StatelessWidget {
  final int place;
  final String username;
  final String? avatarUrl;
  final String? originRegion;
  final int treasuresCompleted;
  final int level;

  const _PodiumTile({
    required this.place,
    required this.username,
    required this.avatarUrl,
    required this.originRegion,
    required this.treasuresCompleted,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final (label, color) = switch (place) {
      1 => ('Oro', AppColors.accentGold),
      2 => ('Plata', const Color(0xFFC0C0C0)),
      _ => ('Bronce', const Color(0xFFCD7F32)),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.18),
              cardColor,
            ],
          ),
          border: Border.all(color: color.withOpacity(0.38)),
        ),
        child: Row(
          children: [
            _Avatar(
              radius: place == 1 ? 26 : 24,
              avatarUrl: avatarUrl,
              username: username,
              ringColor: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#$place',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          username,
                          style: TextStyle(
                            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _LevelDot(level: level, color: color),
                    ],
                  ),
                  if (originRegion != null && originRegion!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      originRegion!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withOpacity(0.35)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$treasuresCompleted',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'tesoros',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final int place;
  final String username;
  final String? avatarUrl;
  final String? originRegion;
  final int treasuresCompleted;
  final int level;

  const _RankTile({
    required this.place,
    required this.username,
    required this.avatarUrl,
    required this.originRegion,
    required this.treasuresCompleted,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _Avatar(
              radius: 20,
              avatarUrl: avatarUrl,
              username: username,
              ringColor: AppColors.accentCyan.withOpacity(0.35),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$place. $username',
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (originRegion != null && originRegion!.trim().isNotEmpty)
                    Text(
                      originRegion!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _LevelDot(level: level, color: AppColors.accentCyan),
                const SizedBox(height: 4),
                Text(
                  '$treasuresCompleted',
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'tesoros',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelDot extends StatelessWidget {
  final int level;
  final Color color;
  const _LevelDot({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.14),
        border: Border.all(color: color.withOpacity(0.45), width: 1.2),
      ),
      child: Center(
        child: Text(
          '$level',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final double radius;
  final String? avatarUrl;
  final String username;
  final Color ringColor;

  const _Avatar({
    required this.radius,
    required this.avatarUrl,
    required this.username,
    required this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
        color: AppColors.backgroundDark,
        image: (url != null && url.isNotEmpty)
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: (url == null || url.isEmpty)
          ? Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : null,
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

