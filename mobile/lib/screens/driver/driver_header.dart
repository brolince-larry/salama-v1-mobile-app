// lib/screens/driver/driver_header.dart
//
// Purpose: Driver dashboard header bar — name, school, LIVE badge,
//          messaging icon with unread count, notifications, profile.
//          Imported only by driver_home_screen.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/driver_trip_provider.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';

class DriverHeader extends ConsumerWidget {
  final dynamic      driver;
  final DriverTripState trip;
  final bool         dark;
  final int          unread;
  final VoidCallback onMessageTap;

  const DriverHeader({
    super.key,
    required this.driver,
    required this.trip,
    required this.dark,
    required this.unread,
    required this.onMessageTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
        decoration: BoxDecoration(
          color: dark ? AppTheme.black : AppTheme.lightBg,
          border: Border(
              bottom: BorderSide(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.08))),
        ),
        child: Row(children: [
          // Shield icon + name + school
          Container(
            padding:    const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color:        AppTheme.primary,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.shield_rounded,
                color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_firstName(driver),
                style: TextStyle(
                    color:      dark ? Colors.white : Colors.black87,
                    fontSize:   15,
                    fontWeight: FontWeight.w700)),
            Text(_schoolName(driver),
                style: TextStyle(
                    color:    dark ? Colors.white54 : Colors.black45,
                    fontSize: 11)),
          ]),
          const Spacer(),

          // Trip badge when trip is active or paused
          if (trip.isOnTrip) ...[
            _TripBadge(paused: trip.isPaused),
            const SizedBox(width: 10),
          ],

          // Messaging
          _IconBtn(
            icon:    Icons.chat_bubble_outline_rounded,
            dark:    dark,
            badge:   unread > 0 ? (unread > 99 ? '99+' : '$unread') : null,
            onTap:   onMessageTap,
          ),
          const SizedBox(width: 8),

          // Notifications
          _IconBtn(
            icon:  Icons.notifications_outlined,
            dark:  dark,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const DriverNotificationScreen())),
          ),
          const SizedBox(width: 8),

          // Profile
          _IconBtn(
            icon:  Icons.person_outline_rounded,
            dark:  dark,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const DriverProfileScreen())),
          ),
        ]),
      );

  // ── Safe field helpers ────────────────────────────────────────────────────

  String _firstName(dynamic u) {
    if (u == null) return 'Driver';
    try { return u.firstName as String; } catch (_) {}
    try { return (u.name as String).split(' ').first; } catch (_) {}
    return 'Driver';
  }

  String _schoolName(dynamic u) {
    if (u == null) return 'Salama';
    try { return u.school?.name as String? ?? 'Salama'; } catch (_) {}
    try { return u.schoolName   as String? ?? 'Salama'; } catch (_) {}
    return 'Salama';
  }
}

// ─── Icon button with optional badge ────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData  icon;
  final bool      dark;
  final String?   badge;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.dark,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.09)
                      : Colors.black.withValues(alpha: 0.07)),
            ),
            child: Icon(icon,
                color: dark ? Colors.white60 : Colors.black54, size: 18),
          ),
          if (badge != null)
            Positioned(
              right: -4, top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Color(0xFFE53935), shape: BoxShape.circle),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(badge!,
                    style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   9,
                        fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
              ),
            ),
        ]),
      );
}

// ─── Animated LIVE badge ─────────────────────────────────────────────────────

class _TripBadge extends StatefulWidget {
  final bool paused;
  const _TripBadge({required this.paused});

  @override
  State<_TripBadge> createState() => _TripBadgeState();
}

class _TripBadgeState extends State<_TripBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
              color: (widget.paused ? Colors.orange : AppTheme.success)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.paused ? Colors.orange : AppTheme.success)),
            const SizedBox(width: 5),
            Text(widget.paused ? 'PAUSED' : 'LIVE',
                style: TextStyle(
                    color: widget.paused ? Colors.orange : AppTheme.success,
                    fontWeight:    FontWeight.w700,
                    fontSize:      10,
                    letterSpacing: 1)),
          ]),
        ),
      );
}