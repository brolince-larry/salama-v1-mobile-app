import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/extensions.dart';
import '../../../core/widgets.dart';

class AdminTrips extends StatelessWidget {
  const AdminTrips({super.key});

  static const _trips = [
    ('BUS 01', 'Route A — Morning', '07:24', 'completed'),
    ('BUS 02', 'Route B — Morning', '07:34', 'active'),
    ('BUS 03', 'Route C — Morning', '08:10', 'pending'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Last Trips', action: 'See all'),
            const SizedBox(height: 12),
            ..._trips.map((t) {
              final c = t.$4 == 'completed'
                  ? AppTheme.success
                  : t.$4 == 'active'
                      ? AppTheme.primary
                      : context.hint;
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(t.$3,
                      style: TextStyle(
                          color: context.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('${t.$1} — ${t.$2}',
                          style: TextStyle(
                              color: context.txt, fontSize: 11),
                          overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(t.$4,
                        style: TextStyle(
                            color: c,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              );
            }),
          ]),
    );
  }
}