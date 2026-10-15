import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/models/hunt.dart';
import 'package:consola_tesoro/core/theme/app_theme.dart';
import 'package:consola_tesoro/data/datasources/supabase/hunt_datasource.dart';
import 'package:consola_tesoro/features/map/presentation/pages/map_screen.dart';

class HuntListScreen extends StatefulWidget {
  final String region;
  const HuntListScreen({super.key, required this.region});

  @override
  State<HuntListScreen> createState() => _HuntListScreenState();
}

class _HuntListScreenState extends State<HuntListScreen> {
  final _supabase = Supabase.instance.client;
  late final HuntDatasource _ds;

  bool   _loading = true;
  String? _error;
  List<Hunt> _activeHunts    = const [];
  List<Map<String, dynamic>> _completedHunts = const [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _ds = HuntDatasource(_supabase);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _userId = await _ds.ensureUserId();
      final results = await Future.wait([
        _ds.listActiveHunts(region: widget.region),
        _ds.listCompletedHunts(region: widget.region),
      ]);
      if (!mounted) return;
      setState(() {
        _activeHunts    = results[0] as List<Hunt>;
        _completedHunts = results[1] as List<Map<String, dynamic>>;
        _loading        = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(
          widget.region,
          style: const TextStyle(
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
                : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    final hasActive    = _activeHunts.isNotEmpty;
    final hasCompleted = _completedHunts.isNotEmpty;

    if (!hasActive && !hasCompleted) {
      return const _CenteredMessage(
        icon: Icons.search_off_rounded,
        iconColor: AppColors.textSecondary,
        message: 'No hay tesoros en esta región.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── Activos ──────────────────────────────────────────────────────────
        if (hasActive) ...[
          _SectionLabel(label: 'DISPONIBLES', color: AppColors.accentCyan),
          const SizedBox(height: 8),
          for (int i = 0; i < _activeHunts.length; i++)
            _HuntCard(
              hunt: _activeHunts[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MapScreen(
                    huntId:    _activeHunts[i].id,
                    huntTitle: _activeHunts[i].title,
                    region:    widget.region,
                  ),
                ),
              ),
            ).animate()
                .fadeIn(delay: (50 * i).ms, duration: 220.ms)
                .slideY(begin: 0.06),
        ],

        // ── Completadas ───────────────────────────────────────────────────────
        if (hasCompleted) ...[
          SizedBox(height: hasActive ? 24 : 0),
          _SectionLabel(label: 'COMPLETADAS', color: AppColors.textSecondary),
          const SizedBox(height: 8),
          for (int i = 0; i < _completedHunts.length; i++)
            _CompletedHuntCard(
              data:     _completedHunts[i],
              isWinner: _completedHunts[i]['winner_id'] == _userId,
            ).animate()
                .fadeIn(delay: (50 * i).ms, duration: 220.ms)
                .slideY(begin: 0.06),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 3, height: 14, color: color,
          margin: const EdgeInsets.only(right: 8)),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _HuntCard extends StatelessWidget {
  final Hunt hunt;
  final VoidCallback onTap;
  const _HuntCard({required this.hunt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final diff = hunt.difficulty;
    final (label, color, icon) = switch (diff) {
      'easy' => ('Fácil', AppColors.success, Icons.sentiment_satisfied_rounded),
      'hard' => ('Difícil', AppColors.accentCoral, Icons.local_fire_department_rounded),
      _ => ('Media', AppColors.accentCyan, Icons.explore_rounded),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.35)),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hunt.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if ((hunt.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          hunt.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.25,
                          ),
                        ),
                      ],
                      if ((hunt.rewardInfo ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                            decoration: BoxDecoration(
                              color: AppColors.accentGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.accentGold.withOpacity(0.55)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events_rounded,
                                    color: AppColors.accentGold, size: 15),
                                const SizedBox(width: 6),
                                Text(
                                  hunt.rewardInfo!,
                                  style: const TextStyle(
                                    color: AppColors.accentGold,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: color.withOpacity(0.35)),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('Entrar',
                              style: TextStyle(
                                  color: color, fontWeight: FontWeight.w700)),
                          Icon(Icons.chevron_right_rounded, color: color),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _CompletedHuntCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isWinner;
  const _CompletedHuntCard({required this.data, required this.isWinner});

  @override
  Widget build(BuildContext context) {
    final diff  = (data['difficulty'] as String?) ?? 'medium';
    final title = (data['title'] as String?) ?? 'Tesoro';
    final desc  = (data['description'] as String?) ?? '';

    final (_, diffColor, diffIcon) = switch (diff) {
      'easy' => ('Fácil', AppColors.success, Icons.sentiment_satisfied_rounded),
      'hard' => ('Difícil', AppColors.accentCoral, Icons.local_fire_department_rounded),
      _ => ('Media', AppColors.accentCyan, Icons.explore_rounded),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: 0.55,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                // Icono tachado / bloqueado
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.textSecondary.withOpacity(0.2)),
                  ),
                  child: Icon(diffIcon,
                      color: AppColors.textSecondary.withOpacity(0.5)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.textSecondary,
                        ),
                      ),
                      if (desc.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      // Badge de premio (si existe)
                      Builder(builder: (_) {
                        final reward = ((data['reward_info'] as String?) ?? '').trim();
                        if (reward.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                              decoration: BoxDecoration(
                                color: AppColors.accentGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                    color: AppColors.accentGold.withOpacity(0.45)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.emoji_events_rounded,
                                      color: AppColors.accentGold, size: 13),
                                  const SizedBox(width: 5),
                                  Text(
                                    reward,
                                    style: const TextStyle(
                                      color: AppColors.accentGold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      // Badge de resultado
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isWinner
                                  ? AppColors.accentGold
                                  : AppColors.textSecondary)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: (isWinner
                                    ? AppColors.accentGold
                                    : AppColors.textSecondary)
                                .withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isWinner
                                  ? Icons.emoji_events_rounded
                                  : Icons.lock_rounded,
                              color: isWinner
                                  ? AppColors.accentGold
                                  : AppColors.textSecondary,
                              size: 13,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isWinner ? 'Ganador' : 'Completada',
                              style: TextStyle(
                                color: isWinner
                                    ? AppColors.accentGold
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Icono de candado a la derecha
                Icon(Icons.lock_outline_rounded,
                    color: AppColors.textSecondary.withOpacity(0.4),
                    size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
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
