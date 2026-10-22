import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:consola_tesoro/core/models/hunt.dart';
import 'package:consola_tesoro/core/theme/app_theme.dart';
import 'package:consola_tesoro/data/datasources/supabase/hunt_datasource.dart';
import 'package:consola_tesoro/features/hunts/presentation/widgets/hunt_countdown_timer.dart';
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
  List<Map<String, dynamic>> _draftHunts     = const [];
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
        _ds.listDraftHunts(region: widget.region),
        _ds.getUserFullyCompletedHuntIds(),
      ]);
      if (!mounted) return;

      final active      = results[0] as List<Hunt>;
      final completed   = List<Map<String, dynamic>>.from(results[1] as List);
      final draft       = results[2] as List<Map<String, dynamic>>;
      final userDoneIds = results[3] as Set<String>;

      // Hunts activos que el usuario ya terminó (servidor no los marcó
      // 'completed' porque se completaron con la versión antigua del RPC).
      // Los movemos al bloque COMPLETADAS para que no aparezcan en DISPONIBLES.
      final stillActive = <Hunt>[];
      for (final h in active) {
        if (userDoneIds.contains(h.id)) {
          completed.insert(0, {
            'id':          h.id,
            'title':       h.title,
            'description': h.description,
            'difficulty':  h.difficulty,
            'reward_info': h.rewardInfo,
            'region':      h.region,
            'winner_id':   null,
          });
        } else {
          stillActive.add(h);
        }
      }

      setState(() {
        _activeHunts    = stillActive;
        _completedHunts = completed;
        _draftHunts     = draft;
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surfaceDark, Color(0xFF0C1220)],
            ),
          ),
        ) : null,
        bottom: isDark ? PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            height: 1.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.accentCyan,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ) : null,
        title: Text(
          widget.region,
          style: TextStyle(
            color: isDark ? AppColors.accentCyan : null,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, color: isDark ? AppColors.textPrimary : null),
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

  void _showExpeditionRules(Hunt hunt) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExpeditionRulesSheet(
        onConfirm: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MapScreen(
                huntId:    hunt.id,
                huntTitle: hunt.title,
                region:    widget.region,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList() {
    final hasActive    = _activeHunts.isNotEmpty;
    final hasCompleted = _completedHunts.isNotEmpty;
    final hasDraft     = _draftHunts.isNotEmpty;

    if (!hasActive && !hasCompleted && !hasDraft) {
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
              onTap: () => _showExpeditionRules(_activeHunts[i]),
            ).animate()
                .fadeIn(delay: (50 * i).ms, duration: 220.ms)
                .slideY(begin: 0.06),
        ],

        // ── Próximamente (draft) ──────────────────────────────────────────────
        if (hasDraft) ...[
          SizedBox(height: hasActive ? 24 : 0),
          _SectionLabel(label: 'PRÓXIMAMENTE', color: AppColors.accentGold),
          const SizedBox(height: 8),
          for (int i = 0; i < _draftHunts.length; i++)
            _DraftHuntCard(data: _draftHunts[i])
                .animate()
                .fadeIn(delay: (50 * i).ms, duration: 220.ms)
                .slideY(begin: 0.06),
        ],

        // ── Completadas ───────────────────────────────────────────────────────
        if (hasCompleted) ...[
          SizedBox(height: (hasActive || hasDraft) ? 24 : 0),
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
class _HuntCard extends StatefulWidget {
  final Hunt hunt;
  final VoidCallback onTap;
  const _HuntCard({required this.hunt, required this.onTap});

  @override
  State<_HuntCard> createState() => _HuntCardState();
}

class _HuntCardState extends State<_HuntCard> {
  Timer? _timer;

  bool get _hasTemporal =>
      widget.hunt.startsAt != null || widget.hunt.endsAt != null;

  bool get _isPlayable {
    final now = DateTime.now();
    if (widget.hunt.startsAt != null && widget.hunt.startsAt!.isAfter(now)) return false;
    if (widget.hunt.endsAt   != null && widget.hunt.endsAt!.isBefore(now))  return false;
    return true;
  }

  bool get _isPending {
    final now = DateTime.now();
    return widget.hunt.startsAt != null && widget.hunt.startsAt!.isAfter(now);
  }

  @override
  void initState() {
    super.initState();
    if (_hasTemporal) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diff = widget.hunt.difficulty;
    final (label, color, icon) = switch (diff) {
      'easy' => ('Fácil', AppColors.success, Icons.sentiment_satisfied_rounded),
      'hard' => ('Difícil', AppColors.accentCoral, Icons.local_fire_department_rounded),
      _ => ('Media', AppColors.accentCyan, Icons.explore_rounded),
    };
    final stripeColor = widget.hunt.isSpecial ? AppColors.accentGold : color;

    Widget card = Padding(
      padding: EdgeInsets.only(top: widget.hunt.isSpecial ? 10 : 0, bottom: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (widget.hunt.isSpecial)
                  BoxShadow(
                    color: AppColors.accentGold.withOpacity(0.32),
                    blurRadius: 26,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                BoxShadow(color: color.withOpacity(0.20), blurRadius: 20, offset: const Offset(0, 6)),
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.33 : 0.10), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Material(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _isPlayable ? widget.onTap : null,
                borderRadius: BorderRadius.circular(16),
                splashColor: stripeColor.withOpacity(0.12),
                highlightColor: stripeColor.withOpacity(0.06),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.hunt.isSpecial
                          ? AppColors.accentGold.withOpacity(0.65)
                          : color.withOpacity(0.30),
                      width: widget.hunt.isSpecial ? 1.5 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(width: 4, color: stripeColor),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42, height: 42,
                                    decoration: BoxDecoration(
                                      color: stripeColor.withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: stripeColor.withOpacity(0.35)),
                                    ),
                                    child: Icon(
                                      widget.hunt.isSpecial ? Icons.star_rounded : icon,
                                      color: stripeColor,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.hunt.title,
                                          style: TextStyle(
                                            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if ((widget.hunt.description ?? '').trim().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.hunt.description!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              height: 1.25,
                                            ),
                                          ),
                                        ],
                                        if ((widget.hunt.rewardInfo ?? '').trim().isNotEmpty) ...[
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
                                                    widget.hunt.rewardInfo!,
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
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: stripeColor.withOpacity(0.14),
                                                borderRadius: BorderRadius.circular(999),
                                                border: Border.all(color: stripeColor.withOpacity(0.35)),
                                              ),
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                  color: stripeColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            if (_isPlayable) ...[
                                              Text('Entrar',
                                                  style: TextStyle(
                                                      color: stripeColor,
                                                      fontWeight: FontWeight.w700)),
                                              Icon(Icons.chevron_right_rounded, color: stripeColor),
                                            ] else ...[
                                              Text(
                                                _isPending ? 'Bloqueado' : 'Finalizado',
                                                style: const TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontWeight: FontWeight.w700),
                                              ),
                                              const Icon(Icons.lock_rounded,
                                                  color: AppColors.textSecondary, size: 16),
                                            ],
                                          ],
                                        ),
                                        if (_hasTemporal) ...[
                                          const SizedBox(height: 6),
                                          HuntCountdownTimer(
                                            startsAt: widget.hunt.startsAt,
                                            endsAt: widget.hunt.endsAt,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
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
          ),

          // Badge "EVENTO ESPECIAL"
          if (widget.hunt.isSpecial)
            Positioned(
              top: -8,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGold.withOpacity(0.50),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 11, color: AppColors.backgroundDark),
                    SizedBox(width: 4),
                    Text(
                      'EVENTO ESPECIAL',
                      style: TextStyle(
                        color: AppColors.backgroundDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.hunt.isSpecial) {
      card = card
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(
            duration: 2200.ms,
            color: AppColors.accentGold.withOpacity(0.16),
            angle: 0.3,
          );
    }

    return card;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _DraftHuntCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DraftHuntCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = (data['title'] as String?) ?? 'Próximo Tesoro';
    final desc  = (data['description'] as String?) ?? '';
    final diff  = (data['difficulty'] as String?) ?? 'medium';
    final reward = ((data['reward_info'] as String?) ?? '').trim();

    final (_, diffColor, diffIcon) = switch (diff) {
      'easy' => ('Fácil', AppColors.success, Icons.sentiment_satisfied_rounded),
      'hard' => ('Difícil', AppColors.accentCoral, Icons.local_fire_department_rounded),
      _ => ('Media', AppColors.accentCyan, Icons.explore_rounded),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentGold.withOpacity(0.20), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentGold.withOpacity(0.20)),
                ),
                child: Icon(diffIcon, color: AppColors.accentGold.withOpacity(0.45)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: (isDark ? AppColors.textPrimary : AppColors.textPrimaryLight).withOpacity(0.65),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (desc.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.70),
                          height: 1.25,
                        ),
                      ),
                    ],
                    if (reward.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.accentGold.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events_rounded,
                                  color: AppColors.accentGold.withOpacity(0.50), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                reward,
                                style: TextStyle(
                                  color: AppColors.accentGold.withOpacity(0.60),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.accentGold.withOpacity(0.28)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_clock_rounded,
                              color: AppColors.accentGold.withOpacity(0.60), size: 13),
                          const SizedBox(width: 5),
                          Text(
                            'Próximamente',
                            style: TextStyle(
                              color: AppColors.accentGold.withOpacity(0.70),
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
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.textSecondary.withOpacity(0.10), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.textSecondary.withOpacity(0.14)),
                ),
                child: Icon(diffIcon, color: AppColors.textSecondary.withOpacity(0.35)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.textSecondary.withOpacity(0.5),
                      ),
                    ),
                    if (desc.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.50),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    Builder(builder: (_) {
                      final reward = ((data['reward_info'] as String?) ?? '').trim();
                      if (reward.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                          decoration: BoxDecoration(
                            color: AppColors.accentGold.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.accentGold.withOpacity(0.22)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events_rounded,
                                  color: AppColors.accentGold.withOpacity(0.50), size: 12),
                              const SizedBox(width: 5),
                              Text(
                                reward,
                                style: TextStyle(
                                  color: AppColors.accentGold.withOpacity(0.60),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isWinner ? AppColors.accentGold : AppColors.textSecondary)
                            .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: (isWinner ? AppColors.accentGold : AppColors.textSecondary)
                              .withOpacity(0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isWinner ? Icons.emoji_events_rounded : Icons.lock_rounded,
                            color: (isWinner ? AppColors.accentGold : AppColors.textSecondary)
                                .withOpacity(0.55),
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isWinner ? 'Ganador' : 'Completada',
                            style: TextStyle(
                              color: (isWinner ? AppColors.accentGold : AppColors.textSecondary)
                                  .withOpacity(0.65),
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
              const SizedBox(width: 8),
              Icon(Icons.lock_outline_rounded,
                  color: AppColors.textSecondary.withOpacity(0.22), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ExpeditionRulesSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  const _ExpeditionRulesSheet({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Reglas de la Expedición',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.accentCyan,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 20),
            const _RuleRow(
              emoji: '🐺',
              title: 'Lobo solitario o Escuadrón',
              body: 'Juega por tu cuenta y llévate toda la gloria, o forma un equipo de hasta 4 personas compartiendo un solo móvil.',
            ),
            const SizedBox(height: 14),
            const _RuleRow(
              emoji: '🧠',
              title: 'Cero spoilers',
              body: 'Disfruta del reto y no compartas las respuestas con otros exploradores por redes sociales.',
            ),
            const SizedBox(height: 14),
            const _RuleRow(
              emoji: '📸',
              title: 'Selfie de validación',
              body: 'Para que el Maestro apruebe tu posición, tu cara (y la de todo tu equipo si vas acompañado) debe aparecer claramente en la foto junto al lugar clave.',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: AppColors.backgroundDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                child: const Text('¡Entendido, al mapa!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  const _RuleRow({required this.emoji, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(builder: (ctx) {
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                return Text(
                  title,
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                );
              }),
              const SizedBox(height: 3),
              Text(
                body,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
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
