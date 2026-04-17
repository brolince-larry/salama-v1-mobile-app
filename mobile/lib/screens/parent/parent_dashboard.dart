// lib/screens/parent/parent_dashboard.dart
//
// Memory optimisations:
//   • Removed ALL ref.keepAlive() calls — GPS data providers are now GC'd
//     30 s after the card leaves the tree (Riverpod autoDispose default)
//   • ParentMapCard uses SmartPoller, not raw Timer.periodic
//   • RepaintBoundary around map card — GPS updates don't repaint the header
//   • childrenProvider: autoDispose, no keepAlive

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../features/messaging/messaging.dart';
import 'parent_map_card.dart';

// ── Providers (autoDispose only — no keepAlive) ───────────────────────────────

/// Children list — GC'd 30 s after parent dashboard leaves the tree.
final childrenProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final raw = await ApiService.get(ApiConfig.parentChildren);
    final list = raw is Map
        ? (raw['children'] ?? raw['data'] ?? []) as List
        : raw is List
            ? raw
            : const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  } catch (_) {
    return [];
  }
});

/// Bus location — autoDispose + NO keepAlive. GC'd when card leaves tree.
/// SmartPoller inside ParentMapCard drives refreshes — this provider is
/// only used to expose the latest value to other listeners.
final busLocationProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, int>((ref, studentId) async {
  try {
    final raw = await ApiService.get(ApiConfig.parentBusLocation(studentId));
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  } catch (_) {
    return null;
  }
});

/// Trip status — autoDispose + NO keepAlive.
final tripStatusProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, int>((ref, studentId) async {
  try {
    final raw = await ApiService.get(ApiConfig.parentTripStatus(studentId));
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  } catch (_) {
    return null;
  }
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ParentDashboard extends ConsumerWidget {
  const ParentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final children = ref.watch(childrenProvider);
    final unread = ref.watch(totalUnreadProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? AppTheme.black : AppTheme.lightBg,
      body: SafeArea(
          child: Stack(children: [
        Column(children: [
          _Header(
            name: user.name,
            unread: unread,
            dark: dark,
            onChat: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MessagingInboxScreen())),
          ),
          Expanded(
            child: children.when(
              loading: () => _Skeleton(dark: dark),
              error: (e, _) => _ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(childrenProvider)),
              data: (list) => list.isEmpty
                  ? _Empty(dark: dark)
                  : _ChildList(children: list, dark: dark),
            ),
          ),
        ]),

        // Incoming message banner
        RepaintBoundary(
          child: Consumer(builder: (ctx, ref, _) {
            final inc = ref.watch(incomingPopupProvider);
            if (inc == null) return const SizedBox.shrink();
            return Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: IncomingMessageBanner(
                incoming: inc,
                onReply: () {
                  ref.read(incomingPopupProvider.notifier).dismiss();
                  Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const MessagingInboxScreen()));
                },
                onDismiss: () =>
                    ref.read(incomingPopupProvider.notifier).dismiss(),
              ),
            );
          }),
        ),
      ])),
    );
  }
}

// ── Children list ─────────────────────────────────────────────────────────────

class _ChildList extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final bool dark;
  const _ChildList({required this.children, required this.dark});

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: children.length,
        itemBuilder: (_, i) => _ChildCard(child: children[i], dark: dark),
      );
}

class _ChildCard extends ConsumerWidget {
  final Map<String, dynamic> child;
  final bool dark;
  const _ChildCard({required this.child, required this.dark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentId = child['id'] as int?;
    final tripState =
        studentId != null ? ref.watch(tripStatusProvider(studentId)) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: dark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Child info header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.person_rounded,
                  color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(child['name'] as String? ?? 'Student',
                      style: TextStyle(
                          color: dark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  Text(
                      'Grade ${child['grade'] ?? '—'}  ·  ${child['school'] ?? ''}',
                      style: TextStyle(
                          color: dark ? Colors.white54 : Colors.black45,
                          fontSize: 12)),
                ])),

            // Trip status badge
            if (tripState != null)
              tripState.when(
                loading: () => const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 1.5)),
                error: (_, __) => const SizedBox.shrink(),
                data: (d) {
                  final status = d?['status'] as String? ?? 'no_trip';
                  final col = status == 'active'
                      ? AppTheme.success
                      : status == 'completed'
                          ? AppTheme.primary
                          : Colors.grey;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                            color: col,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  );
                },
              ),
          ]),
        ),

        // Map card — RepaintBoundary so GPS updates don't repaint the header
        if (studentId != null)
          RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ParentMapCard(
                studentId: studentId,
                studentName: child['name'] as String? ?? 'Child',
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String name;
  final int unread;
  final bool dark;
  final VoidCallback onChat;
  const _Header(
      {required this.name,
      required this.unread,
      required this.dark,
      required this.onChat});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
        decoration: BoxDecoration(
          color: dark ? AppTheme.black : AppTheme.lightBg,
          border: Border(
              bottom: BorderSide(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.07))),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.family_restroom_rounded,
                color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hello, $name',
                style: TextStyle(
                    color: dark ? Colors.white : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Text('Track your children',
                style: TextStyle(
                    color: dark ? Colors.white54 : Colors.black45,
                    fontSize: 11)),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: onChat,
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
                child: Icon(Icons.chat_bubble_outline_rounded,
                    color: dark ? Colors.white60 : Colors.black54, size: 18),
              ),
              if (unread > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Color(0xFFE53935), shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                  ),
                ),
            ]),
          ),
        ]),
      );
}

class _Skeleton extends StatelessWidget {
  final bool dark;
  const _Skeleton({required this.dark});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
            2,
            (_) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                height: 260,
                decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20)))),
      );
}

class _Empty extends StatelessWidget {
  final bool dark;
  const _Empty({required this.dark});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.child_care_rounded,
            size: 48, color: dark ? Colors.white24 : Colors.black26),
        const SizedBox(height: 12),
        Text('No children registered',
            style: TextStyle(
                color: dark ? Colors.white54 : Colors.black45, fontSize: 14)),
      ]));
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded,
            color: AppTheme.danger, size: 36),
        const SizedBox(height: 8),
        Text(message,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry')),
      ]));
}
