import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../core/extensions.dart';
import '../../../providers/fleet_provider.dart';

class AdminStats extends ConsumerWidget {
  const AdminStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleet = ref.watch(fleetProvider).buses;
    final total = fleet.length;
    final active = fleet.where((b) => b.isActive).length;
    final gps = fleet.where((b) => b.hasGps).length;
    final sos = fleet.where((b) => b.isEmergency).length;

    final stats = [
      ('Total buses', '$total', Icons.directions_bus_rounded,
          AppTheme.primary),
      ('Active now', '$active', Icons.circle, AppTheme.success),
      ('Live GPS', '$gps', Icons.location_on, AppTheme.info),
      ('SOS alerts', '$sos', Icons.warning_amber_rounded,
          AppTheme.danger),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.9,
      children: stats.map((s) => _StatCard(s)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final (String, String, IconData, Color) s;
  const _StatCard(this.s);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: s.$4.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: s.$4.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(s.$3, color: s.$4, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(s.$2,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.txt)),
                Text(s.$1,
                    style: TextStyle(
                        fontSize: 10, color: context.muted)),
              ]),
        ]),
      );
}