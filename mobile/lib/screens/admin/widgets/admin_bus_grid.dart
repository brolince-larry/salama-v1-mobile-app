import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../core/extensions.dart';
import '../../../core/widgets.dart';
import '../../../models/bus.dart';
import '../../../providers/fleet_provider.dart';

class AdminBusGrid extends ConsumerWidget {
  final int sel;
  final ValueChanged<int> onSel;
  const AdminBusGrid(
      {super.key, required this.sel, required this.onSel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fleetProvider);
    final fleet = state.buses;
    final loading = state.loading;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Text('Fleet Vehicles',
                style: TextStyle(
                    color: context.txt,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color:
                        AppTheme.success.withValues(alpha: 0.3)),
              ),
              child: Text('${fleet.length} vehicles',
                  style: const TextStyle(
                      color: AppTheme.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          if (loading)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: List.generate(4, (_) => const AppShimmer()),
            )
          else if (fleet.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.border),
              ),
              child: Center(
                child: Column(children: [
                  Icon(Icons.directions_bus_outlined,
                      color: context.hint, size: 40),
                  const SizedBox(height: 8),
                  Text('No buses found',
                      style: TextStyle(
                          color: context.muted, fontSize: 13)),
                ]),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.4,
              ),
              itemCount: fleet.length,
              itemBuilder: (_, i) => _BusCard(
                bus: fleet[i],
                selected: sel == i,
                onTap: () => onSel(i),
              ),
            ),
        ]);
  }
}

class _BusCard extends StatelessWidget {
  final Bus bus;
  final bool selected;
  final VoidCallback onTap;
  const _BusCard(
      {required this.bus,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.08)
                : context.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.5)
                  : context.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bus.isActive
                          ? AppTheme.primary
                              .withValues(alpha: 0.12)
                          : context.border,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.directions_bus_rounded,
                        color: bus.isActive
                            ? AppTheme.primary
                            : context.hint,
                        size: 14),
                  ),
                  const Spacer(),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: bus.isActive
                            ? AppTheme.success
                            : context.hint,
                        shape: BoxShape.circle),
                  ),
                ]),
                const Spacer(),
                Text(bus.name,
                    style: TextStyle(
                        color: context.txt,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                Text(bus.plate,
                    style: TextStyle(
                        color: context.muted, fontSize: 10)),
                const SizedBox(height: 5),
                Row(children: [
                  const Icon(Icons.speed,
                      color: AppTheme.primary, size: 11),
                  const SizedBox(width: 3),
                  Text(
                    bus.hasGps
                        ? '${(bus.speed ?? 0).toStringAsFixed(0)} km/h'
                        : 'No GPS',
                    style: TextStyle(
                        color: bus.hasGps
                            ? AppTheme.primary
                            : context.hint,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ]),
        ),
      );
}