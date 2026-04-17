// SAVE AS: lib/features/messaging/presentation/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../providers/messaging_providers.dart';
import '../widgets/messaging_widgets.dart';
import 'chat_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxState = ref.watch(inboxProvider);
    final dark       = Theme.of(context).brightness == Brightness.dark;

    // Safe null-aware sort comparator
    int byTime(a, b) {
      final ta = a.lastTime;
      final tb = b.lastTime;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    }

    final unread = inboxState.threads
        .where((t) => t.hasUnread)
        .toList()
      ..sort(byTime);

    final read = inboxState.threads
        .where((t) => !t.hasUnread && t.lastMessage != null)
        .toList()
      ..sort(byTime);

    // Total unread count — null-safe fold
    final totalUnread = unread.fold<int>(0, (sum, t) => sum + t.unreadCount);

    return Scaffold(
      backgroundColor: dark ? AppTheme.black : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: dark ? AppTheme.darkSurface : AppTheme.lightSurface,
        title: const Text('Notifications'),
        actions: [
          if (unread.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(inboxProvider.notifier).fetch(),
              child: const Text('Refresh',
                  style: TextStyle(color: AppTheme.primary, fontSize: 13)),
            ),
        ],
      ),
      body: inboxState.loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : inboxState.error != null
              ? MessagingErrorState(
                  message: inboxState.error!,
                  onRetry: () => ref.read(inboxProvider.notifier).fetch(),
                )
              : (unread.isEmpty && read.isEmpty)
                  ? MessagingEmptyState(
                      title:    'No notifications',
                      subtitle: 'Messages and alerts will appear here.',
                      isDark:   dark,
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (unread.isNotEmpty) ...[
                          _SectionHeader(
                            label: 'Unread',
                            count: totalUnread,
                            dark:  dark,
                          ),
                          const SizedBox(height: 10),
                          ...unread.map((thread) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _NotifCard(
                                  thread: thread,
                                  unread: true,
                                  dark:   dark,
                                  onTap:  () => _openChat(context, thread),
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (read.isNotEmpty) ...[
                          _SectionHeader(label: 'Earlier', dark: dark),
                          const SizedBox(height: 10),
                          ...read.take(15).map((thread) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _NotifCard(
                                  thread: thread,
                                  unread: false,
                                  dark:   dark,
                                  onTap:  () => _openChat(context, thread),
                                ),
                              )),
                        ],
                      ],
                    ),
    );
  }

  void _openChat(BuildContext ctx, thread) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => ChatScreen(thread: thread),
    ));
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int? count;
  final bool dark;
  const _SectionHeader({required this.label, this.count, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: dark ? AppTheme.textSecondary : AppTheme.lightMuted,
              letterSpacing: 1.2)),
      if (count != null && count! > 0) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(10)),
          child: Text('$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ]);
  }
}

// ── Notification card ─────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final dynamic thread; // ChatThread
  final bool unread;
  final bool dark;
  final VoidCallback onTap;

  const _NotifCard({
    required this.thread,
    required this.unread,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isGroup  = thread.isGroup  as bool;
    final String? role  = thread.senderRole as String?;

    final IconData icon;
    final Color iconColor;

    if (isGroup) {
      icon = Icons.campaign_rounded; iconColor = AppTheme.danger;
    } else {
      switch (role) {
        case 'driver':
          icon = Icons.directions_bus_rounded; iconColor = AppTheme.primary;
        case 'parent':
          icon = Icons.family_restroom_rounded; iconColor = AppTheme.info;
        case 'admin':
          icon = Icons.admin_panel_settings_rounded; iconColor = AppTheme.warning;
        default:
          icon = Icons.notifications_rounded;
          iconColor = dark ? AppTheme.textSecondary : AppTheme.lightMuted;
      }
    }

    // Null-safe time display
    final DateTime? lastTime = thread.lastTime as DateTime?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread
              ? (isGroup
                  ? AppTheme.danger.withValues(alpha: dark ? 0.08 : 0.05)
                  : AppTheme.primary.withValues(alpha: dark ? 0.08 : 0.05))
              : (dark ? AppTheme.darkCard : AppTheme.lightSurface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unread
                ? (isGroup
                    ? AppTheme.danger.withValues(alpha: 0.3)
                    : AppTheme.primary.withValues(alpha: 0.25))
                : (dark ? AppTheme.darkBorder : AppTheme.lightBorder),
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    thread.label as String,
                    style: TextStyle(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                      color: dark ? AppTheme.textPrimary : AppTheme.lightText,
                    ),
                  ),
                ),
                if (lastTime != null)
                  Text(
                    _timeAgo(lastTime),
                    style: TextStyle(
                        fontSize: 11,
                        color: dark ? AppTheme.textHint : AppTheme.lightHint),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(
                (thread.lastMessage as String?) ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12, height: 1.4,
                  color: unread
                      ? (dark ? AppTheme.textPrimary : AppTheme.lightText)
                      : (dark ? AppTheme.textSecondary : AppTheme.lightMuted),
                ),
              ),
            ],
          )),
          if (unread)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: isGroup ? AppTheme.danger : AppTheme.primary,
                    shape: BoxShape.circle),
              ),
            ),
        ]),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}