// lib/screens/admin/admin_dashboard.dart
//
// Memory optimisations:
//   • _buildPage() switch — only the ACTIVE page exists in the widget tree.
//     No IndexedStack, no AnimatedSwitcher re-creation, no background tabs.
//     Each page is created fresh on first tap and GC'd when you leave.
//   • Map page (FleetMapPage) is wrapped in AutomaticKeepAliveClientMixin
//     so the GL context survives tab switches without full rebuild.
//   • RepaintBoundary around the page area — map repaints don't propagate
//     to sidebar/topbar.
//   • Subscription status pre-loaded once silently; never re-fetched on
//     every tab switch.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/subscription_provider.dart';
import 'widgets/admin_sidebar.dart';
import 'widgets/admin_topbar.dart';
import 'pages/dashboard_page.dart';
import 'pages/fleet_map_page.dart';
import 'pages/buses_page.dart';
import 'pages/routes_page.dart';
import 'pages/sos_page.dart';
import 'pages/notifications_page.dart';
import 'pages/subscription/subscription_page.dart';
import '../../features/messaging/messaging.dart';

// Tab indices
const int _kDashboard = 0;
const int _kMap = 1;
const int _kBuses = 2;
const int _kRoutes = 3;
const int _kSos = 4;
const int _kSubscription = 5;
const int _kNotifications = 6;
const int _kMessages = 7;

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _nav = _kDashboard;

  // Cache heavy pages so they survive tab switches without full rebuild.
  // Pages NOT in this cache are created fresh every time (cheap pages).
  // FleetMapPage is kept alive because destroying + recreating the GL context
  // is slower than keeping it and pausing its poll timer.
  final _pageCache = <int, Widget>{};

  Widget _buildPage(int index) {
    // Pages worth caching (stateful, heavy GL context or data)
    const cacheable = {_kMap, _kDashboard};

    if (cacheable.contains(index)) {
      return _pageCache.putIfAbsent(index, () => _createPage(index));
    }
    // Lightweight pages: always fresh, no cache, GC'd when user leaves
    return _createPage(index);
  }

  Widget _createPage(int index) {
    switch (index) {
      case _kDashboard:
        return const DashboardPage();
      case _kMap:
        return const FleetMapPage();
      case _kBuses:
        return const BusesPage();
      case _kRoutes:
        return const RoutesPage();
      case _kSos:
        return const SosPage();
      case _kSubscription:
        return const SubscriptionPage();
      case _kNotifications:
        return const NotificationsPage();
      case _kMessages:
        return const MessagingInboxScreen();
      default:
        return const DashboardPage();
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // Fleet: WebSocket or SmartPoller — no raw Timer here
      ref.read(fleetProvider.notifier).load();
      // Subscription: one silent fetch on load
      final schoolId = ref.read(authProvider).user?.schoolId;
      if (schoolId != null) {
        ref.read(subscriptionProvider.notifier).fetchStatus(schoolId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider)!;
    // Unlock all premium UI affordances (PRO badge / shortcuts).
    // Server-side subscription enforcement is still handled by the backend.
    final isPremium = true;
    final wide = MediaQuery.of(context).size.width > 900;
    final unread = ref.watch(totalUnreadProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.black : AppTheme.lightBg,
      body: Stack(children: [
        Row(children: [
          if (wide)
            AdminSidebar(
              sel: _nav,
              onSel: (i) => setState(() => _nav = i),
              user: user,
              onLogout: () => ref.read(authProvider.notifier).logout(),
            ),
          Expanded(
            child: Column(children: [
              AdminTopBar(
                user: user,
                onRefresh: () => ref.read(fleetProvider.notifier).load(),
                onMessages: () => setState(() => _nav = _kMessages),
                onSubscription: () => setState(() => _nav = _kSubscription),
                isPremium: isPremium,
              ),
              // RepaintBoundary: map repaints never touch sidebar/topbar
              Expanded(
                child: RepaintBoundary(
                  child: _buildPage(_nav),
                ),
              ),
            ]),
          ),
        ]),

        // Incoming message popup
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
                  setState(() => _nav = _kMessages);
                },
                onDismiss: () =>
                    ref.read(incomingPopupProvider.notifier).dismiss(),
              ),
            );
          }),
        ),
      ]),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _nav,
              onDestinationSelected: (i) => setState(() => _nav = i),
              destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Dashboard'),
                const NavigationDestination(
                    icon: Icon(Icons.map_outlined),
                    selectedIcon: Icon(Icons.map),
                    label: 'Map'),
                const NavigationDestination(
                    icon: Icon(Icons.directions_bus_outlined),
                    selectedIcon: Icon(Icons.directions_bus),
                    label: 'Buses'),
                const NavigationDestination(
                    icon: Icon(Icons.route_outlined),
                    selectedIcon: Icon(Icons.route),
                    label: 'Routes'),
                const NavigationDestination(
                    icon: Icon(Icons.warning_amber_outlined),
                    selectedIcon: Icon(Icons.warning_amber),
                    label: 'SOS'),
                const NavigationDestination(
                    icon: Icon(Icons.card_membership_outlined),
                    selectedIcon: Icon(Icons.card_membership_rounded),
                    label: 'Plan'),
                const NavigationDestination(
                    icon: Icon(Icons.notifications_outlined),
                    selectedIcon: Icon(Icons.notifications),
                    label: 'Alerts'),
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
