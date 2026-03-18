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

  bool _loading = true;
  String? _error;
  List<Hunt> _hunts = const [];

  @override
  void initState() {
    super.initState();
    _ds = HuntDatasource(_supabase);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hunts = await _ds.listActiveHunts(region: widget.region);
      if (!mounted) return;
      setState(() {
        _hunts = hunts;
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
                : _hunts.isEmpty
                    ? const _CenteredMessage(
                        icon: Icons.search_off_rounded,
                        iconColor: AppColors.textSecondary,
                        message: 'No hay tesoros activos en esta región.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        itemCount: _hunts.length,
                        itemBuilder: (_, i) {
                          final h = _hunts[i];
                          return _HuntCard(
                            hunt: h,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MapScreen(
                                  huntId: h.id,
                                  huntTitle: h.title,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(
                                delay: (50 * i).ms,
                                duration: 220.ms,
                              ).slideY(begin: 0.06);
                        },
                      ),
      ),
    );
  }
}

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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
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
                    const SizedBox(height: 8),
                    Row(
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
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Entrar',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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

