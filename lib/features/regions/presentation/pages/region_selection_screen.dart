import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:consola_tesoro/core/theme/app_theme.dart';
import 'package:consola_tesoro/features/hunts/presentation/pages/hunt_list_screen.dart';
import 'package:consola_tesoro/features/profile/presentation/pages/profile_screen.dart';
import 'package:consola_tesoro/features/ranking/presentation/pages/ranking_screen.dart';

class RegionSelectionScreen extends StatelessWidget {
  const RegionSelectionScreen({super.key});

  static const List<_RegionItem> _regions = [
    _RegionItem('Andalucía', Icons.wb_sunny_rounded, Color(0xFFFFB703)),
    _RegionItem('Aragón', Icons.terrain_rounded, Color(0xFFE63946)),
    _RegionItem('Asturias', Icons.water_rounded, Color(0xFF00E5CC)),
    _RegionItem('Illes Balears', Icons.beach_access_rounded, Color(0xFF4CC9F0)),
    _RegionItem('Canarias', Icons.volcano_rounded, Color(0xFFFF6B4A)),
    _RegionItem('Cantabria', Icons.forest_rounded, Color(0xFF2A9D8F)),
    _RegionItem('Castilla-La Mancha', Icons.landscape_rounded, Color(0xFFB5179E)),
    _RegionItem('Castilla y León', Icons.castle_rounded, Color(0xFF6D597A)),
    _RegionItem('Cataluña', Icons.apartment_rounded, Color(0xFFF77F00)),
    _RegionItem('C. Valenciana', Icons.surfing_rounded, Color(0xFF06D6A0)),
    _RegionItem('Extremadura', Icons.park_rounded, Color(0xFF52B788)),
    _RegionItem('Galicia', Icons.cloud_rounded, Color(0xFF3A86FF)),
    _RegionItem('La Rioja', Icons.wine_bar_rounded, Color(0xFF9B2226)),
    _RegionItem('Comunidad de Madrid', Icons.location_city_rounded, Color(0xFF8338EC)),
    _RegionItem('Región de Murcia', Icons.local_florist_rounded, Color(0xFF7CB518)),
    _RegionItem('Navarra', Icons.shield_rounded, Color(0xFFEF476F)),
    _RegionItem('País Vasco', Icons.hiking_rounded, Color(0xFF118AB2)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Elige una región',
          style: TextStyle(
            color: AppColors.accentCyan,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Ranking',
            icon: const Icon(Icons.leaderboard_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RankingScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Mi perfil',
            icon: const Icon(Icons.person_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'España, nivel nacional.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.06),
              const SizedBox(height: 6),
              Text(
                'Selecciona tu Comunidad Autónoma para ver los tesoros disponibles.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.35),
              ).animate().fadeIn(delay: 80.ms, duration: 220.ms).slideY(begin: 0.06),
              const SizedBox(height: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final crossAxisCount = w >= 980
                        ? 4
                        : w >= 680
                            ? 3
                            : 2;
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: _regions.length,
                      itemBuilder: (_, i) {
                        final r = _regions[i];
                        return _RegionCard(
                          region: r,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HuntListScreen(region: r.name),
                            ),
                          ),
                        ).animate().fadeIn(
                              delay: (60 * i).ms,
                              duration: 220.ms,
                            ).scale(begin: const Offset(0.98, 0.98));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  final _RegionItem region;
  final VoidCallback onTap;
  const _RegionCard({required this.region, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = region.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Card(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.35)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.14),
                AppColors.cardDark.withOpacity(1.0),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(region.icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                region.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Ver tesoros',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, color: color, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionItem {
  final String name;
  final IconData icon;
  final Color accent;
  const _RegionItem(this.name, this.icon, this.accent);
}

