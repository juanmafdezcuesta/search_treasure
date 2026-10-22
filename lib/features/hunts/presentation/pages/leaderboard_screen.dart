import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/models/hunt_leaderboard_entry.dart';
import 'package:consola_tesoro/core/theme/app_theme.dart';
import 'package:consola_tesoro/data/datasources/supabase/hunt_datasource.dart';

class LeaderboardScreen extends StatefulWidget {
  final String huntId;
  final String huntTitle;

  const LeaderboardScreen({
    super.key,
    required this.huntId,
    required this.huntTitle,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final HuntDatasource _ds;
  Future<List<HuntLeaderboardEntry>>? _future;
  final String? _myId = Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _ds = HuntDatasource(Supabase.instance.client);
    _load();
  }

  void _load() {
    setState(() {
      _future = _ds.getHuntLeaderboard(widget.huntId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: _buildAppBar(isDark),
      body: FutureBuilder<List<HuntLeaderboardEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            );
          }
          if (snap.hasError) {
            return _ErrorState(onRetry: _load);
          }
          final entries = snap.data ?? [];
          if (entries.isEmpty) {
            return const _EmptyState();
          }
          return _buildBody(context, entries, isDark);
        },
      ),
    );
  }

  AppBar _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppColors.surfaceDark, const Color(0xFF0C1220)]
                : [AppColors.surfaceLight, const Color(0xFFE8EDF2)],
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ranking',
            style: GoogleFonts.poppins(
              color: AppColors.accentGold,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            widget.huntTitle,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          icon: Icon(
            Icons.refresh_rounded,
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
          ),
          onPressed: _load,
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<HuntLeaderboardEntry> entries,
    bool isDark,
  ) {
    final top  = entries.take(3).toList();
    final rest = entries.length > 3 ? entries.sublist(3) : <HuntLeaderboardEntry>[];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Podium(entries: top, isDark: isDark),
        ),
        if (rest.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppColors.accentGold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CLASIFICACIÓN',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final entry = rest[i];
                final isMe  = entry.userId == _myId;
                return _LeaderboardRow(entry: entry, isMe: isMe, isDark: isDark)
                    .animate()
                    .fadeIn(delay: (40 * i).ms, duration: 220.ms)
                    .slideX(begin: 0.05, curve: Curves.easeOut);
              },
              childCount: rest.length,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ─── Podio ────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<HuntLeaderboardEntry> entries;
  final bool isDark;

  const _Podium({required this.entries, required this.isDark});

  static const Color _gold   = AppColors.accentGold;
  static const Color _silver = Color(0xFFB0B7C3);
  static const Color _bronze = Color(0xFFCD7F32);

  @override
  Widget build(BuildContext context) {
    final first  = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third  = entries.length > 2 ? entries[2] : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppColors.surfaceDark, AppColors.cardDark]
              : [AppColors.surfaceLight, AppColors.cardLight],
        ),
        border: Border.all(
          color: _gold.withOpacity(0.22),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2.º lugar
          Expanded(
            child: _PodiumColumn(
              entry: second,
              rank: 2,
              color: _silver,
              avatarRadius: 22,
              baseHeight: 64,
              isDark: isDark,
            ).animate().fadeIn(delay: 180.ms, duration: 300.ms)
                .slideY(begin: 0.15, curve: Curves.easeOut),
          ),
          // 1.er lugar
          Expanded(
            child: _PodiumColumn(
              entry: first,
              rank: 1,
              color: _gold,
              avatarRadius: 29,
              baseHeight: 96,
              isDark: isDark,
              isFirst: true,
            ).animate().fadeIn(duration: 350.ms)
                .slideY(begin: 0.08, curve: Curves.easeOut),
          ),
          // 3.er lugar
          Expanded(
            child: _PodiumColumn(
              entry: third,
              rank: 3,
              color: _bronze,
              avatarRadius: 22,
              baseHeight: 44,
              isDark: isDark,
            ).animate().fadeIn(delay: 360.ms, duration: 300.ms)
                .slideY(begin: 0.15, curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final HuntLeaderboardEntry? entry;
  final int     rank;
  final Color   color;
  final double  avatarRadius;
  final double  baseHeight;
  final bool    isDark;
  final bool    isFirst;

  const _PodiumColumn({
    required this.entry,
    required this.rank,
    required this.color,
    required this.avatarRadius,
    required this.baseHeight,
    required this.isDark,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor  = isDark ? AppColors.textPrimary    : AppColors.textPrimaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Corona / medalla para el primero
        if (isFirst)
          const Icon(Icons.emoji_events_rounded, color: AppColors.accentGold, size: 24)
              .animate()
              .scale(delay: 500.ms, duration: 400.ms, curve: Curves.elasticOut)
        else
          const SizedBox(height: 4),

        const SizedBox(height: 4),

        // Avatar con badge de rango
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: color.withOpacity(0.18),
              backgroundImage: entry?.avatarUrl != null
                  ? NetworkImage(entry!.avatarUrl!)
                  : null,
              child: entry == null
                  ? Icon(Icons.person_outline_rounded,
                      color: color.withOpacity(0.4),
                      size: avatarRadius * 0.9)
                  : (entry!.avatarUrl == null
                      ? Text(
                          entry!.username.isNotEmpty
                              ? entry!.username[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.poppins(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: avatarRadius * 0.7,
                          ),
                        )
                      : null),
            ),
            // Badge de posición
            if (entry != null)
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: scaffoldBg, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // Nombre
        if (entry != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              entry!.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: textColor,
                fontWeight: isFirst ? FontWeight.w900 : FontWeight.w700,
                fontSize: isFirst ? 13 : 11,
              ),
            ),
          )
        else
          const SizedBox(height: 13),

        const SizedBox(height: 3),

        // Puntos
        if (entry != null)
          Text(
            '${entry!.pointsEarned} pts',
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          )
        else
          const SizedBox(height: 14),

        const SizedBox(height: 10),

        // Bloque de podio
        Container(
          height: baseHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.35), color.withOpacity(0.12)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            border: Border(
              top:   BorderSide(color: color.withOpacity(0.55), width: 1.5),
              left:  BorderSide(color: color.withOpacity(0.25), width: 1),
              right: BorderSide(color: color.withOpacity(0.25), width: 1),
            ),
          ),
          child: entry == null
              ? Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: color.withOpacity(0.3),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

// ─── Fila de la lista (posición 4 en adelante) ────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final HuntLeaderboardEntry entry;
  final bool isMe;
  final bool isDark;

  const _LeaderboardRow({
    required this.entry,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textColor = isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isMe ? AppColors.accentCyan.withOpacity(0.07) : cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? AppColors.accentCyan.withOpacity(0.42)
              : (isDark
                  ? AppColors.textSecondary.withOpacity(0.09)
                  : AppColors.textSecondary.withOpacity(0.18)),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Número de posición
          SizedBox(
            width: 34,
            child: Text(
              '#${entry.finishRank}',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accentCyan.withOpacity(0.12),
            backgroundImage: entry.avatarUrl != null
                ? NetworkImage(entry.avatarUrl!)
                : null,
            child: entry.avatarUrl == null
                ? Text(
                    entry.username.isNotEmpty
                        ? entry.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  )
                : null,
          ),

          const SizedBox(width: 12),

          // Nombre + badge TÚ
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    entry.username,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.accentCyan.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'TÚ',
                      style: GoogleFonts.poppins(
                        color: AppColors.accentCyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Puntos
          Text(
            '+${entry.pointsEarned}',
            style: GoogleFonts.poppins(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),

          const SizedBox(width: 10),

          // Tiempo relativo
          Text(
            _relativeTime(entry.validatedAt),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'Ahora';
    if (diff.inMinutes < 60)  return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24)    return 'hace ${diff.inHours}h';
    return 'hace ${diff.inDays}d';
  }
}

// ─── Estados vacío / error ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_outlined,
              color: AppColors.textSecondary, size: 56),
          const SizedBox(height: 16),
          Text(
            'Nadie lo ha completado aún',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¡Sé el primero en descubrir el tesoro!',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Error al cargar el ranking',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text('Reintentar',
                style: TextStyle(color: AppColors.accentCyan)),
          ),
        ],
      ),
    );
  }
}
