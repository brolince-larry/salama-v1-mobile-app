// lib/screens/superadmin/superadmin_dashboard.dart
//
// Memory optimisation: replaced IndexedStack with a switch-based _buildPage().
// SchoolListScreen, SubscriptionScreen(super_admin), AddSchoolScreen and
// MessagingInboxScreen are only mounted when active — ~150 MB saved vs
// keeping all 4 alive simultaneously in IndexedStack.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../features/messaging/messaging.dart';
import '../superadmin/school_list_screen.dart';
import '../superadmin/subscription_screen.dart';
import '../superadmin/add_school_screen.dart';

const int _kSchools = 0;
const int _kAddSchool = 1;
const int _kPlans = 2;
const int _kMessages = 3;

class SuperAdminDashboard extends ConsumerStatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  ConsumerState<SuperAdminDashboard> createState() =>
      _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends ConsumerState<SuperAdminDashboard> {
  int _tab = _kSchools;

  // SchoolListScreen is cached — it loads a potentially long list that
  // would be expensive to re-fetch every time the user comes back.
  // All other pages are lightweight enough to recreate.
  Widget? _schoolListCache;

  Widget _buildPage(int tab) {
    switch (tab) {
      case _kSchools:
        // SchoolListScreen handles its own add/edit navigation internally
        _schoolListCache ??= const SchoolListScreen();
        return _schoolListCache!;

      case _kAddSchool:
        // AddSchoolScreen: after save it pops back — we reset cache so list refreshes
        return const AddSchoolScreen(
          school: null, // null = create mode
        );

      case _kPlans:
        return const SubscriptionScreen(role: 'super_admin');

      case _kMessages:
        return const MessagingInboxScreen();

      default:
        _schoolListCache ??= const SchoolListScreen();
        return _schoolListCache!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider)!;
    final unread = ref.watch(totalUnreadProvider);
    final wide = MediaQuery.of(context).size.width > 900;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? AppTheme.black : AppTheme.lightBg,
      body: Stack(children: [
        // ── Main layout ───────────────────────────────────────────────────
        Row(children: [
          // Wide: rail sidebar
          if (wide)
            _SuperSidebar(tab: _tab, onTap: (i) => setState(() => _tab = i)),

          // Page area — RepaintBoundary isolates repaints from sidebar
          Expanded(
            child: Column(children: [
              _TopBar(
                  user: user,
                  onMessages: () => setState(() => _tab = _kMessages)),
              Expanded(
                child: RepaintBoundary(child: _buildPage(_tab)),
              ),
            ]),
          ),
        ]),

        // ── Incoming message banner ───────────────────────────────────────
        RepaintBoundary(
          child: Consumer(builder: (ctx, ref, _) {
            final inc = ref.watch(incomingPopupProvider);
            if (inc == null) return const SizedBox.shrink();
            return Positioned(
              top: MediaQuery.of(ctx).padding.top + 8,
              left: 16,
              right: 16,
              child: IncomingMessageBanner(
                incoming: inc,
                onReply: () {
                  ref.read(incomingPopupProvider.notifier).dismiss();
                  setState(() => _tab = _kMessages);
                },
                onDismiss: () =>
                    ref.read(incomingPopupProvider.notifier).dismiss(),
              ),
            );
          }),
        ),
      ]),

      // Narrow: bottom nav
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.school_outlined),
                    selectedIcon: Icon(Icons.school_rounded),
                    label: 'Schools'),
                const NavigationDestination(
                    icon: Icon(Icons.add_business_outlined),
                    selectedIcon: Icon(Icons.add_business_rounded),
                    label: 'Add School'),
                const NavigationDestination(
                    icon: Icon(Icons.layers_outlined),
                    selectedIcon: Icon(Icons.layers_rounded),
                    label: 'Plans'),
                NavigationDestination(
                  icon: _BadgeIcon(
                      icon: Icons.chat_bubble_outline_rounded, count: unread),
                  selectedIcon: _BadgeIcon(
                      icon: Icons.chat_bubble_rounded,
                      count: unread,
                      selected: true),
                  label: 'Messages',
                ),
              ],
            ),
    );
  }
}

// ── Sidebar (wide screens) ────────────────────────────────────────────────────

class _SuperSidebar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTap;
  const _SuperSidebar({required this.tab, required this.onTap});

  static const _items = [
    (Icons.school_rounded, Icons.school_outlined, 'Schools'),
    (Icons.add_business_rounded, Icons.add_business_outlined, 'Add School'),
    (Icons.layers_rounded, Icons.layers_outlined, 'Plans'),
    (Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Messages'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 200,
      color: dark ? AppTheme.darkCard : Colors.white,
      child: Column(children: [
        const SizedBox(height: 56),
        // Logo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Super Admin',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        ...List.generate(_items.length, (i) {
          final sel = tab == i;
          return _SideItem(
            icon: sel ? _items[i].$1 : _items[i].$2,
            label: _items[i].$3,
            selected: sel,
            onTap: () => onTap(i),
          );
        }),
      ]),
    );
  }
}

class _SideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SideItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(icon,
                color: selected ? AppTheme.primary : Colors.grey, size: 18),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: selected ? AppTheme.primary : Colors.grey,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      );
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final dynamic user;
  final VoidCallback onMessages;
  const _TopBar({required this.user, required this.onMessages});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: dark ? AppTheme.darkCard : Colors.white,
        border: Border(
            bottom: BorderSide(
                color: dark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.07))),
      ),
      child: Row(children: [
        Text('SchoolTrack',
            style: TextStyle(
                color: dark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 16)),
        const Spacer(),
        IconButton(
          onPressed: onMessages,
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
          color: Colors.grey,
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
          child:
              const Icon(Icons.shield_rounded, color: Colors.white, size: 16),
        ),
      ]),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool selected;
  const _BadgeIcon(
      {required this.icon, required this.count, this.selected = false});

  @override
  Widget build(BuildContext context) =>
      Stack(clipBehavior: Clip.none, children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  color: Color(0xFFE53935), shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
              child: Text(count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
            ),
          ),
      ]);
}
