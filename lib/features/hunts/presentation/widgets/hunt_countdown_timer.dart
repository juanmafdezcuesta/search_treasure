import 'package:flutter/material.dart';
import 'package:consola_tesoro/core/theme/app_theme.dart';

class HuntCountdownTimer extends StatelessWidget {
  final DateTime? startsAt;
  final DateTime? endsAt;

  const HuntCountdownTimer({super.key, this.startsAt, this.endsAt});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    if (startsAt != null && startsAt!.isAfter(now)) {
      return _CountdownRow(
        icon: Icons.schedule_rounded,
        label: 'Empieza en:',
        diff: startsAt!.difference(now),
        color: AppColors.accentGold,
      );
    }

    if (endsAt != null && endsAt!.isBefore(now)) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock_rounded, size: 13, color: AppColors.error),
          SizedBox(width: 5),
          Text(
            'Evento finalizado',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    if (endsAt != null) {
      return _CountdownRow(
        icon: Icons.timer_rounded,
        label: 'Termina en:',
        diff: endsAt!.difference(now),
        color: AppColors.accentCyan,
      );
    }

    return const SizedBox.shrink();
  }
}

class _CountdownRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Duration diff;
  final Color color;

  const _CountdownRow({
    required this.icon,
    required this.label,
    required this.diff,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;

    final buf = StringBuffer(label);
    if (d > 0) buf.write(' ${d}d');
    buf.write(' ${h.toString().padLeft(2, '0')}h');
    buf.write(' ${m.toString().padLeft(2, '0')}m');
    buf.write(' ${s.toString().padLeft(2, '0')}s');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          buf.toString(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
