import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../models/user.dart';
import '../../../features/messaging/messaging.dart';

class AdminTopBar extends ConsumerWidget {
  final UserModel user;
  final VoidCallback onRefresh;
  final VoidCallback? onMessages; 
  final VoidCallback onSubscription; // Added parameter
  final bool isPremium; // Added parameter

  const AdminTopBar({
    super.key,
    required this.user,
    required this.onRefresh,
    required this.onSubscription, // Added to constructor
    this.onMessages,
    this.isPremium = false, // Default value
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live unread count from messaging inbox
    final inbox  = ref.watch(inboxProvider);
    final unread = inbox.threads.fold<int>(0, (s, t) => s + t.unreadCount);

    // Premium Palette for Consistency
    const Color topBarBg = Color(0xFF0A0E0A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color:  topBarBg,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Text(
                'Welcome back, ${user.name.split(' ').first} 👋',
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              if (isPremium) _PremiumBadge(onTap: onSubscription),
            ],
          ),
          Text(
            user.isSuperAdmin
                ? 'Super Admin — Global Fleet'
                : 'School Admin — System Active',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ]),
        const Spacer(),

        // ── Subscription Shortcut ─────────────────────────────────────
        _IconBtn(
          icon: Icons.auto_awesome_rounded, 
          onTap: onSubscription,
          iconColor: isPremium ? Colors.orangeAccent : Colors.grey,
        ),
        const SizedBox(width: 8),

        // ── Messaging icon with live unread badge ─────────────────────
        _MsgBtn(unread: unread, onTap: onMessages),
        const SizedBox(width: 8),

        _IconBtn(icon: Icons.refresh, onTap: onRefresh),
        const SizedBox(width: 8),
        _NotifBtn(),
      ]),
    );
  }
}

// ── Premium Status Badge ─────────────────────────────────────────────────────

class _PremiumBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'PRO',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ── Messaging button ──────────────────────────────────────────────────────────

class _MsgBtn extends StatelessWidget {
  final int unread;
  final VoidCallback? onTap;
  const _MsgBtn({required this.unread, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const MessagingInboxScreen())),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:  const Color(0xFF111811),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Icon(Icons.chat_bubble_outline_rounded,
              color: unread > 0 ? AppTheme.primary : Colors.grey, size: 16),
          if (unread > 0)
            Positioned(
              right: -4, top: -4,
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                    color: Color(0xFFE53935), shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  unread > 99 ? '9+' : '$unread',
                  style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   8,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Improved Icon Button ─────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _IconBtn({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:  const Color(0xFF111811),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Icon(icon, color: iconColor ?? Colors.grey, size: 16),
        ),
      );
}

class _NotifBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:  const Color(0xFF111811),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          const Icon(Icons.notifications_outlined, color: Colors.grey, size: 16),
          Positioned(
            right: -2, top: -2,
            child: Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                  color: AppTheme.danger, shape: BoxShape.circle),
            ),
          ),
        ]),
      );
}