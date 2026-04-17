import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/driver_home_provider.dart';

class DriverNotificationScreen extends ConsumerWidget {
  const DriverNotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverNotificationsProvider);
    final dark  = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? AppTheme.black : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: dark ? AppTheme.black : AppTheme.lightBg,
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.read(driverNotificationsProvider.notifier).fetch(),
          ),
        ],
      ),
      body: state.loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : state.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _ErrBanner(message: state.error!, dark: dark),
                  ),
                )
              : state.notifications.isEmpty
                  ? _Empty(dark: dark)
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(driverNotificationsProvider.notifier).fetch(),
                      color: AppTheme.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: state.notifications.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final n = state.notifications[i]
                              as Map<String, dynamic>;
                          return _NotifTile(n: n, dark: dark);
                        },
                      ),
                    ),
    );
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> n;
  final bool dark;
  const _NotifTile({required this.n, required this.dark});

  @override
  Widget build(BuildContext context) {
    final type    = n['type'] as String? ?? '';
    final unread  = n['read'] == false;
    final isSos   = type == 'sos';

    final Color iconColor;
    final IconData iconData;

    switch (type) {
      case 'sos':
        iconData  = Icons.emergency_rounded;
        iconColor = Colors.red;
        break;
      case 'trip_started':
        iconData  = Icons.play_circle_rounded;
        iconColor = AppTheme.success;
        break;
      case 'trip_ended':
        iconData  = Icons.stop_circle_rounded;
        iconColor = AppTheme.primary;
        break;
      case 'student_boarded':
        iconData  = Icons.login_rounded;
        iconColor = Colors.teal;
        break;
      case 'student_dropped':
        iconData  = Icons.logout_rounded;
        iconColor = Colors.orange;
        break;
      default:
        iconData  = Icons.notifications_rounded;
        iconColor = dark ? Colors.white54 : Colors.black45;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unread
            ? (isSos
                ? Colors.red.withValues(alpha: 0.07)
                : AppTheme.primary.withValues(alpha: 0.06))
            : (dark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unread
              ? (isSos
                  ? Colors.red.withValues(alpha: 0.35)
                  : AppTheme.primary.withValues(alpha: 0.25))
              : (dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n['title'] as String? ?? '',
                  style: TextStyle(
                    color: isSos
                        ? Colors.red
                        : (dark ? Colors.white : Colors.black87),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  n['message'] as String? ?? '',
                  style: TextStyle(
                      color: dark ? Colors.white54 : Colors.black54,
                      fontSize: 12,
                      height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  _timeAgo(n['time'] as String?),
                  style: TextStyle(
                      color: dark ? Colors.white30 : Colors.black38,
                      fontSize: 11),
                ),
              ],
            ),
          ),
          if (unread)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSos ? Colors.red : AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  String _timeAgo(String? raw) {
    if (raw == null) return '';
    try {
      final dt   = DateTime.parse(raw);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  final bool dark;
  const _Empty({required this.dark});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_off_rounded,
                  color: dark ? Colors.white30 : Colors.black26,
                  size: 32),
            ),
            const SizedBox(height: 16),
            Text('No notifications',
                style: TextStyle(
                    color: dark ? Colors.white54 : Colors.black54,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Trip events and alerts will appear here',
                style: TextStyle(
                    color: dark ? Colors.white30 : Colors.black38,
                    fontSize: 12)),
          ],
        ),
      );
}

class _ErrBanner extends StatelessWidget {
  final String message;
  final bool   dark;
  const _ErrBanner({required this.message, required this.dark});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.red, fontSize: 12))),
        ]),
      );
}