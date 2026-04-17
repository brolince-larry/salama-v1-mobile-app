import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../models/user.dart';

/// AdminSidebar — persistent left rail for school_admin on tablet/desktop.
///
/// Matches the dark green design visible in the screenshot:
///   • Dark background (#0D150D)
///   • Green active highlight pill
///   • Icon + label nav items
///   • User avatar + logout at bottom
///
/// Tab index map (must stay in sync with AdminDashboard._page()):
///   0  Dashboard
///   1  Fleet Map
///   2  Buses
///   3  Routes
///   4  SOS Alerts
///   5  Subscription  ← Plan / upgrade
///   6  Notifications
///   7  Messages (handled by topbar shortcut — not shown in sidebar)
///
/// Path: lib/screens/admin/widgets/admin_sidebar.dart
class AdminSidebar extends StatelessWidget {
  final int sel;
  final ValueChanged<int> onSel;
  final UserModel user;

  final VoidCallback? onSubscription; // legacy compat — use onSel(5) instead
  final VoidCallback? onLogout;

  const AdminSidebar({
    super.key,
    required this.sel,
    required this.onSel,
    required this.user,
    this.onSubscription,
    this.onLogout,
  });

  static const _items = [
    _NavItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(1, Icons.map_outlined, Icons.map_rounded, 'Fleet Map'),
    _NavItem(2, Icons.directions_bus_outlined, Icons.directions_bus_rounded,
        'Buses'),
    _NavItem(3, Icons.route_outlined, Icons.route_rounded, 'Routes'),
    _NavItem(4, Icons.warning_amber_outlined, Icons.warning_amber_rounded,
        'SOS Alerts'),
    _NavItem(5, Icons.card_membership_outlined, Icons.card_membership_rounded,
        'Subscription'), // ← Plan
    _NavItem(6, Icons.notifications_outlined, Icons.notifications_rounded,
        'Notifications'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 215,
      color: const Color(0xFF0D150D),
      child: Column(
        children: [
          // ── Logo ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.directions_bus_filled,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('SchoolTrack',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ]),
          ),

          const Divider(color: Color(0xFF1E2E1E), height: 1),
          const SizedBox(height: 8),

          // ── Nav items ────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: _items.map((item) {
                final isSelected = sel == item.index;
                return _SidebarTile(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => onSel(item.index),
                );
              }).toList(),
            ),
          ),

          const Divider(color: Color(0xFF1E2E1E), height: 1),

          // ── User footer ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(user.role,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ),
              if (onLogout != null) ...[
                IconButton(
                  tooltip: 'Logout',
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  onPressed: onLogout,
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar tile
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarTile extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Subscription tile gets a subtle upgrade indicator when not selected
    final bool isSubscription = item.index == 5;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: AppTheme.primary.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected ? AppTheme.primary : Colors.grey[500],
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primary : Colors.grey[400],
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              // Upgrade pill on the Subscription tile when not active
              if (isSubscription && !isSelected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Upgrade',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  final int index;
  final IconData icon, selectedIcon;
  final String label;
  const _NavItem(this.index, this.icon, this.selectedIcon, this.label);
}
