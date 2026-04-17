import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/extensions.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static const _notifications = [
    (Icons.location_on, 'BUS 01 arrived at Stop 3',
        'Route A Morning — Stop 3 reached on time',
        '2 min ago', AppTheme.success),
    (Icons.speed, 'Speed alert — BUS 02',
        'BUS 02 exceeded speed limit of 60 km/h',
        '8 min ago', AppTheme.warning),
    (Icons.check_circle, 'Trip #142 completed',
        'BUS 01 completed morning route successfully',
        '1 hour ago', AppTheme.info),
    (Icons.person, 'Student boarding — BUS 01',
        '24 students boarded successfully',
        '2 hours ago', AppTheme.primary),
    (Icons.warning_amber, 'Maintenance due',
        'BUS 03 scheduled maintenance in 3 days',
        '5 hours ago', AppTheme.warning),
    (Icons.check_circle, 'Trip #141 completed',
        'BUS 02 completed evening route',
        'Yesterday', AppTheme.info),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Text('Notifications',
              style: TextStyle(
                  color: context.txt,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          TextButton(
            onPressed: () {},
            child: const Text('Mark all read',
                style: TextStyle(
                    color: AppTheme.primary, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 16),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final n = _notifications[i];
            final unread = i < 2;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: unread
                    ? n.$5.withValues(alpha: 0.05)
                    : context.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: unread
                        ? n.$5.withValues(alpha: 0.25)
                        : context.border),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: n.$5.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(n.$1, color: n.$5, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                  Text(n.$2,
                      style: TextStyle(
                          color: context.txt,
                          fontSize: 13,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(n.$3,
                      style: TextStyle(
                          color: context.muted,
                          fontSize: 11,
                          height: 1.4)),
                  const SizedBox(height: 5),
                  Text(n.$4,
                      style: TextStyle(
                          color: context.hint, fontSize: 10)),
                ])),
                if (unread)
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                        color: n.$5, shape: BoxShape.circle),
                  ),
              ]),
            );
          },
        ),
      ]),
    );
  }
}