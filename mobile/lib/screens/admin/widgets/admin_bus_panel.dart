import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/extensions.dart';
import '../../../core/widgets.dart';
import '../../../models/bus.dart';

class AdminBusPanel extends StatelessWidget {
  final Bus bus;
  const AdminBusPanel({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    final speed = bus.speed ?? 0.0;
    final pct = (speed / 120).clamp(0.0, 1.0);
    final sColor = speed > 80
        ? AppTheme.danger
        : speed > 50
            ? AppTheme.warning
            : AppTheme.success;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Selected Vehicle',
                  style: TextStyle(
                      color: context.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              StatusBadge(
                label: bus.isActive ? 'Active' : 'Inactive',
                color: bus.isActive
                    ? AppTheme.success
                    : context.hint,
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    AppTheme.primary,
                    AppTheme.primaryDark
                  ]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_bus_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                    Text(bus.name,
                        style: TextStyle(
                            color: context.txt,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(bus.plate,
                        style: TextStyle(
                            color: context.muted,
                            fontSize: 11)),
                  ])),
            ]),
            const SizedBox(height: 14),
            Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
              Text('Speed',
                  style: TextStyle(
                      color: context.muted, fontSize: 11)),
              Text('${speed.toStringAsFixed(0)} km/h',
                  style: TextStyle(
                      color: sColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: context.border,
                valueColor: AlwaysStoppedAnimation(sColor),
                minHeight: 7,
              ),
            ),
            const SizedBox(height: 4),
            Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
              Text('0',
                  style: TextStyle(
                      color: context.hint, fontSize: 9)),
              Text('60',
                  style: TextStyle(
                      color: context.hint, fontSize: 9)),
              Text('120 km/h',
                  style: TextStyle(
                      color: context.hint, fontSize: 9)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.location_on,
                    color: bus.hasGps
                        ? AppTheme.primary
                        : context.hint,
                    size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    bus.hasGps
                        ? '${bus.latitude.toStringAsFixed(4)}, ${bus.longitude.toStringAsFixed(4)}'
                        : 'No GPS signal',
                    style: TextStyle(
                        color: bus.hasGps
                            ? context.txt
                            : context.hint,
                        fontSize: 11),
                  ),
                ),
              ]),
            ),
            if (bus.timestamp != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.access_time,
                    color: context.hint, size: 11),
                const SizedBox(width: 5),
                Expanded(
                  child: Text('Last ping: ${bus.timestamp}',
                      style: TextStyle(
                          color: context.hint, fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
          ]),
    );
  }
}