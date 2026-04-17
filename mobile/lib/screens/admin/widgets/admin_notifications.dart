import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/extensions.dart';
import '../../../core/widgets.dart';

class AdminNotifications extends StatelessWidget {
  const AdminNotifications({super.key});

  static const _items = [
    (Icons.location_on, 'BUS 01 arrived at Stop 3', '2m ago',
        AppTheme.success, true),
    (Icons.speed, 'BUS 02 exceeded speed limit', '8m ago',
        AppTheme.warning, true),
    (Icons.check_circle, 'Trip #142 completed', '1h ago',
        AppTheme.info, false),
    (Icons.person, '24 students boarded BUS 01', '2h ago',
        AppTheme.primary, false),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
              title: 'Notifications',
              action: '2 new',
              onAction: () {}),
          const SizedBox(height: 10),
          ..._items.map((n) => Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: n.$5
                      ? AppTheme.primary.withValues(alpha: 0.05)
                      : context.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: n.$5
                          ? AppTheme.primary.withValues(alpha: 0.2)
                          : context.border),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: n.$4.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(n.$1, color: n.$4, size: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                        Text(n.$2,
                            style: TextStyle(
                                color: context.txt,
                                fontSize: 11,
                                fontWeight: n.$5
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                        Text(n.$3,
                            style: TextStyle(
                                color: context.hint,
                                fontSize: 9)),
                      ])),
                  if (n.$5)
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle)),
                ]),
              )),
        ]);
  }
}