import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_home_provider.dart';

class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth    = ref.watch(authProvider);
    final history = ref.watch(tripHistoryProvider);
    final driver  = auth.user;
    final dark    = Theme.of(context).brightness == Brightness.dark;

    // Safe field accessors — works regardless of UserModel shape
    final name   = _str(driver, 'name')   ?? 'Driver';
    final email  = _str(driver, 'email')  ?? '';
    final phone  = _str(driver, 'phone')  ?? 'Not set';
    final school = _school(driver)         ?? 'Salama';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'D';

    return Scaffold(
      backgroundColor: dark ? AppTheme.black : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: dark ? AppTheme.black : AppTheme.lightBg,
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            tooltip: 'Sign out',
            onPressed: () async {
              final ok = await _confirmLogout(context, dark);
              if (ok == true && context.mounted) {
                ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Avatar ─────────────────────────────────────────────────────────
          Center(
            child: Column(children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 16),
              Text(name,
                  style: TextStyle(
                      color: dark ? Colors.white : Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(email,
                  style: TextStyle(
                      color: dark ? Colors.white54 : Colors.black45,
                      fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Text(school,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          // ── Info card ───────────────────────────────────────────────────────
          _Card(
            dark: dark,
            child: Column(children: [
              _InfoRow(icon: Icons.person_outline_rounded,
                  label: 'Full Name', value: name,  dark: dark),
              _Divider(dark: dark),
              _InfoRow(icon: Icons.email_outlined,
                  label: 'Email',     value: email, dark: dark),
              _Divider(dark: dark),
              _InfoRow(icon: Icons.phone_outlined,
                  label: 'Phone',     value: phone, dark: dark),
              _Divider(dark: dark),
              _InfoRow(icon: Icons.school_outlined,
                  label: 'School',    value: school, dark: dark),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Trip history ────────────────────────────────────────────────────
          Text("RECENT TRIPS",
              style: TextStyle(
                  color: dark ? Colors.white38 : Colors.black45,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 14),

          if (history.loading)
            const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
          else if (history.error != null)
            _ErrBanner(message: history.error!, dark: dark)
          else if (history.trips.isEmpty)
            _Empty(dark: dark)
          else
            ...history.trips.take(10).map((t) =>
                _TripRow(trip: t as Map<String, dynamic>, dark: dark)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Safe field accessors — handles any UserModel shape
  String? _str(dynamic u, String field) {
    if (u == null) return null;
    try {
      switch (field) {
        case 'name':  return u.name  as String?;
        case 'email': return u.email as String?;
        case 'phone': return u.phone as String?;
      }
    } catch (_) {}
    return null;
  }

  String? _school(dynamic u) {
    if (u == null) return null;
    try { return u.school?.name as String?; } catch (_) {}
    try { return u.schoolName   as String?; } catch (_) {}
    return null;
  }

  Future<bool?> _confirmLogout(BuildContext ctx, bool dark) =>
      showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
          backgroundColor: dark ? AppTheme.black : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Sign Out?',
              style: TextStyle(
                  color: dark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w800)),
          content: Text(
              'You will need to sign in again to start a new trip.',
              style: TextStyle(
                  color: dark ? Colors.white54 : Colors.black54,
                  height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: dark ? Colors.white54 : Colors.black45)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign Out',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

// ── Row widgets ───────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final bool     dark;
  const _InfoRow({required this.icon, required this.label,
      required this.value, required this.dark});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(label,
                style: TextStyle(
                    color: dark ? Colors.white30 : Colors.black38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: dark ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ]);
}

class _TripRow extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool dark;
  const _TripRow({required this.trip, required this.dark});

  @override
  Widget build(BuildContext context) {
    final status = trip['status'] as String? ?? 'pending';
    final isDone = status == 'completed';
    final color  = isDone ? AppTheme.primary
        : (dark ? Colors.white24 : Colors.black26);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: color, size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${(trip['direction'] as String? ?? '').capitalize()} trip',
              style: TextStyle(
                  color: dark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            Text(
              trip['route']?['name'] as String? ?? 'Route —',
              style: TextStyle(
                  color: dark ? Colors.white54 : Colors.black45,
                  fontSize: 12),
            ),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status.toUpperCase(),
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ── Shared primitives ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final bool   dark;
  const _Card({required this.child, required this.dark});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
        ),
        child: child,
      );
}

class _Divider extends StatelessWidget {
  final bool dark;
  const _Divider({required this.dark});

  @override
  Widget build(BuildContext context) => Divider(
      color: dark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.black.withValues(alpha: 0.07),
      height: 24);
}

class _Empty extends StatelessWidget {
  final bool dark;
  const _Empty({required this.dark});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.history_rounded,
                color: dark ? Colors.white30 : Colors.black26, size: 32),
            const SizedBox(height: 12),
            Text('No trips yet',
                style: TextStyle(
                    color: dark ? Colors.white54 : Colors.black54,
                    fontSize: 14)),
          ]),
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

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}