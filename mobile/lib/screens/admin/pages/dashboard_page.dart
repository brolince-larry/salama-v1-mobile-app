import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/extensions.dart';
import '../../../providers/fleet_provider.dart';
import '../widgets/admin_stats.dart';
import '../widgets/admin_map.dart';
import '../widgets/admin_bus_grid.dart';
import '../widgets/admin_bus_panel.dart';
import '../widgets/admin_notifications.dart';
import '../widgets/admin_trips.dart';

/// DashboardPage — overview tab (index 0) for school_admin.
///
/// Subscription status is pre-loaded by AdminDashboard.initState —
/// no fetch needed here. Subscription management lives on its own tab.
///
/// Path: lib/screens/admin/pages/dashboard_page.dart
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _selBus = 0;

  @override
  Widget build(BuildContext context) {
    final fleet = ref.watch(fleetProvider).buses;
    final wide  = MediaQuery.of(context).size.width > 900;

    if (_selBus >= fleet.length && fleet.isNotEmpty) _selBus = 0;

    return Row(
      children: [
        // ── Main scroll area ──────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const AdminStats(),
                const SizedBox(height: 16),
                const AdminMap(),
                const SizedBox(height: 16),
                AdminBusGrid(
                  sel:   _selBus,
                  onSel: (i) => setState(() => _selBus = i),
                ),
                const SizedBox(height: 16),
                if (fleet.isNotEmpty) ...[
                  AdminBusPanel(bus: fleet[_selBus]),
                  const SizedBox(height: 16),
                ],
                const AdminNotifications(),
                const SizedBox(height: 16),
                const AdminTrips(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // ── Wide sidebar (tablet / desktop) ──────────────────────────────
        if (wide && fleet.isNotEmpty)
          Container(
            width: 280,
            decoration: BoxDecoration(
              color:  context.surface,
              border: Border(left: BorderSide(color: context.border)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  AdminBusPanel(bus: fleet[_selBus]),
                  const SizedBox(height: 14),
                  const AdminNotifications(),
                ],
              ),
            ),
          ),
      ],
    );
  }
}