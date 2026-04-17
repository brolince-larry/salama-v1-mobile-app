// lib/screens/driver/driver_tabs.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/driver_trip_provider.dart';
import '../../providers/driver_home_provider.dart';

// Note: Ensure tripHistoryProvider is defined in your providers folder
// import '../../providers/trip_history_provider.dart';

class DriverHomeTab extends ConsumerWidget {
  const DriverHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(driverHomeProvider);
    final trip = ref.watch(driverTripProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (home.loading) return _Skeleton(dark: dark);

    final data = home.data;
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(driverHomeProvider.notifier).fetch();
        if (trip.isOnTrip) {
          await ref.read(driverTripProvider.notifier).refreshStudents();
        }
      },
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          if (home.error != null) ...[
            _ErrBanner(message: home.error!, dark: dark),
            const SizedBox(height: 14),
          ],
          _TripStatusCard(trip: trip, dark: dark),
          const SizedBox(height: 14),
          if (data?.bus != null) ...[
            _BusCard(bus: data!.bus!, dark: dark),
            const SizedBox(height: 14),
          ],
          if (trip.isOnTrip) ...[
            _BoardingCard(
              total: trip.students.length,
              boarded: trip.pickedCount,
              dark: dark,
            ),
            const SizedBox(height: 14),
          ],
          if (data?.nextTrip != null) ...[
            _NextTripCard(trip: data!.nextTrip!, dark: dark),
            const SizedBox(height: 14),
          ],
          if (data != null && data.todayTrips.isNotEmpty) ...[
            _SectionLabel("TODAY'S TRIPS", dark: dark),
            const SizedBox(height: 10),
            ...data.todayTrips.map(
              (t) => _TripRow(trip: t as Map<String, dynamic>, dark: dark),
            ),
          ],
        ],
      ),
    );
  }
}

class DriverStudentsTab extends ConsumerWidget {
  const DriverStudentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(driverTripProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final students = trip.students;

    if (students.isEmpty) {
      final hint = trip.tripId == null
          ? 'Start a trip to load your student manifest'
          : 'No students found for this trip';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 48, color: dark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 16),
            Text(hint,
                style: TextStyle(
                    color: dark ? Colors.white38 : Colors.grey.shade600)),
          ],
        ),
      );
    }

    final currentlyBoarded =
        students.where((s) => s.status == StudentStatus.pickedUp).toList();
    final expected =
        students.where((s) => s.status == StudentStatus.waiting).toList();
    final dropped =
        students.where((s) => s.status == StudentStatus.dropped).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(driverTripProvider.notifier).refreshStudents(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          if (expected.isNotEmpty)
            _ManifestSection(
              title: 'EXPECTED STUDENTS',
              subtitle: '${expected.length} waiting at stops',
              accent: AppTheme.primary.withAlpha(50),
              children: expected.map((s) => _StudentRow(s)).toList(),
            ),
          if (currentlyBoarded.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ManifestSection(
              title: 'CURRENTLY ONBOARD',
              subtitle: '${currentlyBoarded.length} student(s) on bus',
              accent: AppTheme.success.withAlpha(50),
              children: currentlyBoarded.map((s) => _StudentRow(s)).toList(),
            ),
          ],
          if (dropped.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ManifestSection(
              title: 'DROPPED OFF',
              subtitle: '${dropped.length} student(s) reached destination',
              accent: Colors.orange.withAlpha(50),
              children: dropped.map((s) => _StudentRow(s)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class DriverReportsTab extends ConsumerWidget {
  const DriverReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Note: ensure tripHistoryProvider exists. Using dummy UI if not.
    final history =
        ref.watch(driverHomeProvider); // Replace with actual history provider

    if (history.loading) return _Skeleton(dark: false);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      itemCount: 5, // Replace with dynamic count
      itemBuilder: (ctx, i) {
        return _TripReportCard(
          routeName: "Morning Route A",
          plate: "KCD 123X",
          direction: "MORNING",
          scheduledAt: "16/04 07:30",
          status: "completed",
          dark: Theme.of(context).brightness == Brightness.dark,
        );
      },
    );
  }
}

// ─── Component Primitives (FIXES COMPILER ERRORS) ─────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final bool dark;
  const _Card({required this.child, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: dark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: child,
    );
  }
}

class _Skeleton extends StatelessWidget {
  final bool dark;
  const _Skeleton({required this.dark});

  @override
  Widget build(BuildContext context) {
    return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary));
  }
}

class _ErrBanner extends StatelessWidget {
  final String message;
  final bool dark;
  const _ErrBanner({required this.message, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(message,
          style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool dark;
  const _SectionLabel(this.label, {required this.dark});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: dark ? Colors.white54 : Colors.black54));
  }
}

class _TripStatusCard extends StatelessWidget {
  final DriverTripState trip;
  final bool dark;
  const _TripStatusCard({required this.trip, required this.dark});

  @override
  Widget build(BuildContext context) {
    final active = trip.isOnTrip;
    return _Card(
      dark: dark,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                active ? AppTheme.success : Colors.grey.withOpacity(0.2),
            child: Icon(active ? Icons.local_shipping : Icons.pause,
                color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(active ? "TRIP IN PROGRESS" : "NO ACTIVE TRIP",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(active ? "Direction: ${trip.direction}" : "Ready for dispatch",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ],
      ),
    );
  }
}

class _BusCard extends StatelessWidget {
  final dynamic bus;
  final bool dark;
  const _BusCard({required this.bus, required this.dark});

  @override
  Widget build(BuildContext context) {
    return _Card(
      dark: dark,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.directions_bus, color: AppTheme.primary),
        title: Text(bus['plate'] ?? "Unknown Bus"),
        subtitle: Text("Capacity: ${bus['capacity'] ?? '—'} students"),
      ),
    );
  }
}

class _BoardingCard extends StatelessWidget {
  final int total;
  final int boarded;
  final bool dark;
  const _BoardingCard(
      {required this.total, required this.boarded, required this.dark});

  @override
  Widget build(BuildContext context) {
    return _Card(
      dark: dark,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionLabel('BOARDING PROGRESS', dark: dark),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _StatBox(label: 'Total', value: '$total', dark: dark),
          _StatBox(
              label: 'Boarded',
              value: '$boarded',
              dark: dark,
              valueColor: AppTheme.success),
          _StatBox(
              label: 'Left',
              value: '${total - boarded}',
              dark: dark,
              valueColor: Colors.orange),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: total > 0 ? boarded / total : 0,
          backgroundColor: dark ? Colors.white12 : Colors.black12,
          color: AppTheme.success,
        ),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool dark;
  final Color? valueColor;
  final IconData? icon;

  const _StatBox(
      {required this.label,
      required this.value,
      required this.dark,
      this.valueColor,
      this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor ?? (dark ? Colors.white : Colors.black))),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }
}

class _NextTripCard extends StatelessWidget {
  final dynamic trip;
  final bool dark;
  const _NextTripCard({required this.trip, required this.dark});

  @override
  Widget build(BuildContext context) {
    return _Card(
      dark: dark,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text("Next Scheduled Trip",
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(trip['route_name'] ?? 'Route',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool dark;
  const _TripRow({required this.trip, required this.dark});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(trip['route_name'] ?? 'Route'),
      subtitle: Text(trip['time'] ?? '--:--'),
    );
  }
}

class _ManifestSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final List<Widget> children;
  const _ManifestSection(
      {required this.title,
      required this.subtitle,
      required this.accent,
      required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
      Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      const SizedBox(height: 12),
      ...children,
    ]);
  }
}

class _TripReportCard extends StatelessWidget {
  final String routeName, plate, direction, scheduledAt, status;
  final bool dark;
  const _TripReportCard(
      {required this.routeName,
      required this.plate,
      required this.direction,
      required this.scheduledAt,
      required this.status,
      required this.dark});

  @override
  Widget build(BuildContext context) {
    return _Card(
      dark: dark,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(routeName, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(status.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  color: status == 'completed' ? Colors.green : Colors.grey)),
        ]),
        const Divider(),
        Text("Bus: $plate | Direction: $direction",
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text("Started: $scheduledAt",
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final TripStudent student;
  const _StudentRow(this.student);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(student.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: statusColor.withOpacity(0.1),
              child: Text(student.name[0],
                  style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(student.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(student.stopName,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
          _StatusChip(status: student.status, color: statusColor),
        ],
      ),
    );
  }

  Color _getStatusColor(StudentStatus s) {
    return switch (s) {
      StudentStatus.waiting => AppTheme.primary,
      StudentStatus.pickedUp => AppTheme.success,
      StudentStatus.dropped => Colors.orange,
    };
  }
}

class _StatusChip extends StatelessWidget {
  final StudentStatus status;
  final Color color;
  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      StudentStatus.waiting => 'EXPECTED',
      StudentStatus.pickedUp => 'BOARDED',
      StudentStatus.dropped => 'DROPPED',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
