// lib/screens/driver/trip_control_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/driver_trip_provider.dart';

class TripControlSheet extends ConsumerStatefulWidget {
  const TripControlSheet({super.key});

  @override
  ConsumerState<TripControlSheet> createState() => _TripControlSheetState();
}

class _TripControlSheetState extends ConsumerState<TripControlSheet> {
  // Now using IDs for creation instead of a manual Trip ID text field
  int? _selectedRouteId;
  int? _selectedBusId;
  String _selectedDirection = 'morning';

  bool _sosHolding = false;

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(driverTripProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppTheme.black : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
            top: BorderSide(
                color: dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.07))),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Error
          if (trip.error != null) ...[
            _ErrBanner(message: trip.error!, dark: dark),
            const SizedBox(height: 16),
          ],

          if (!trip.isOnTrip) ...[
            // ── START TRIP (CREATE NEW) ─────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_road_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Start a New Trip',
                    style: TextStyle(
                        color: dark ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                Text('Configure your current run',
                    style: TextStyle(
                        color: dark ? Colors.white54 : Colors.black45,
                        fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 22),

            // Note: In a real app, these IDs would come from a dropdown
            // populated by your 'buses' and 'routes' endpoints.
            _SimpleNumericField(
              label: 'Route ID',
              icon: Icons.map_rounded,
              dark: dark,
              onChanged: (v) => _selectedRouteId = int.tryParse(v),
            ),
            const SizedBox(height: 12),
            _SimpleNumericField(
              label: 'Bus ID',
              icon: Icons.directions_bus_filled_rounded,
              dark: dark,
              onChanged: (v) => _selectedBusId = int.tryParse(v),
            ),
            const SizedBox(height: 12),

            // Direction Switcher
            Row(
              children: [
                Expanded(
                  child: _DirectionToggle(
                    label: 'Morning',
                    isActive: _selectedDirection == 'morning',
                    onTap: () => setState(() => _selectedDirection = 'morning'),
                    dark: dark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DirectionToggle(
                    label: 'Evening',
                    isActive: _selectedDirection == 'evening',
                    onTap: () => setState(() => _selectedDirection = 'evening'),
                    dark: dark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Start button - calls updated notifier method
            _ActionBtn(
              label: 'Create & Start Trip',
              icon: Icons.play_circle_rounded,
              color: AppTheme.primary,
              loading: trip.loading,
              onTap: () {
                if (_selectedRouteId == null || _selectedBusId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter Route and Bus IDs')),
                  );
                  return;
                }
                ref.read(driverTripProvider.notifier).startTrip(
                      routeId: _selectedRouteId!,
                      busId: _selectedBusId!,
                      direction: _selectedDirection,
                    );
              },
            ),
          ] else ...[
            // ── ACTIVE TRIP ─────────────────────────────────────────────────

            // Trip info card
            _InfoCard(
              dark: dark,
              borderColor: AppTheme.primary.withValues(alpha: 0.3),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_bus_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trip #${trip.tripId}',
                        style: TextStyle(
                            color: dark ? Colors.white : Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    Text(
                        trip.isPaused
                            ? '${trip.pingCount} pings · GPS paused'
                            : '${trip.pingCount} pings · GPS active',
                        style: TextStyle(
                            color: dark ? Colors.white54 : Colors.black45,
                            fontSize: 12)),
                  ],
                )),
                if (trip.lat != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${trip.speed?.toStringAsFixed(0) ?? '0'} km/h',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    Text('speed',
                        style: TextStyle(
                            color: dark ? Colors.white38 : Colors.black38,
                            fontSize: 10)),
                  ]),
              ]),
            ),
            const SizedBox(height: 12),

            // GPS stat row
            Row(children: [
              _StatBox(
                  icon: Icons.location_on_rounded,
                  label: 'Pings',
                  value: '${trip.pingCount}',
                  dark: dark),
              const SizedBox(width: 10),
              _StatBox(
                  icon: Icons.speed_rounded,
                  label: 'Speed',
                  value: '${trip.speed?.toStringAsFixed(1) ?? '0'} km/h',
                  dark: dark),
              const SizedBox(width: 10),
              _StatBox(
                  icon: Icons.gps_fixed_rounded,
                  label: 'GPS',
                  value: trip.isPaused
                      ? 'Paused'
                      : trip.lat != null
                          ? 'Fixed'
                          : 'Searching',
                  dark: dark,
                  valueColor: trip.isPaused
                      ? Colors.orange
                      : trip.lat != null
                          ? AppTheme.success
                          : Colors.orange),
            ]),
            const SizedBox(height: 12),

            if (trip.isPaused)
              _InfoCard(
                dark: dark,
                borderColor: Colors.orange.withValues(alpha: 0.35),
                bgColor: Colors.orange.withValues(alpha: 0.08),
                child: const Row(children: [
                  Icon(Icons.pause_circle_outline_rounded,
                      color: Colors.orange, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Trip paused. GPS pinging is stopped until you resume.',
                      style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ),
                ]),
              ),
            if (trip.isPaused) const SizedBox(height: 12),

            // Coordinates
            if (trip.lat != null)
              _InfoCard(
                dark: dark,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.my_location_rounded,
                      color: Colors.teal, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    '${trip.lat!.toStringAsFixed(6)}, '
                    '${trip.lng!.toStringAsFixed(6)}',
                    style: TextStyle(
                        color: dark ? Colors.white54 : Colors.black54,
                        fontSize: 12,
                        fontFamily: 'monospace'),
                  ),
                ]),
              ),
            const SizedBox(height: 12),

            // Pause / Resume
            _ActionBtn(
              label: trip.isPaused ? 'Resume Trip' : 'Pause Trip',
              icon: trip.isPaused
                  ? Icons.play_circle_rounded
                  : Icons.pause_circle_rounded,
              color: trip.isPaused ? AppTheme.primary : Colors.orange,
              loading: trip.loading,
              onTap: () {
                final notifier = ref.read(driverTripProvider.notifier);
                if (trip.isPaused) {
                  notifier.resumeTrip();
                } else {
                  notifier.pauseTrip();
                }
              },
            ),
            const SizedBox(height: 12),

            // SOS
            if (!trip.sosSent)
              _SosButton(
                holding: _sosHolding,
                onHoldStart: () => setState(() => _sosHolding = true),
                onHoldEnd: () {
                  if (_sosHolding) {
                    ref.read(driverTripProvider.notifier).triggerSos();
                  }
                  setState(() => _sosHolding = false);
                },
              )
            else
              _InfoCard(
                dark: dark,
                borderColor: Colors.red.withValues(alpha: 0.4),
                bgColor: Colors.red.withValues(alpha: 0.07),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emergency_rounded,
                          color: Colors.red, size: 18),
                      SizedBox(width: 10),
                      Text('SOS Alert Sent — Help is on the way',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ]),
              ),
            const SizedBox(height: 12),

            // End trip
            _ActionBtn(
              label: 'End Trip',
              icon: Icons.stop_circle_rounded,
              color: Colors.red,
              loading: trip.loading,
              onTap: () async {
                final ok = await _confirmEnd(context, dark);
                if (ok == true && context.mounted) {
                  await ref.read(driverTripProvider.notifier).endTrip();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<bool?> _confirmEnd(BuildContext ctx, bool dark) => showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
          backgroundColor: dark ? AppTheme.black : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('End Trip?',
              style: TextStyle(
                  color: dark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w800)),
          content: Text(
              'This will stop GPS tracking and mark the trip as completed.',
              style: TextStyle(
                  color: dark ? Colors.white54 : Colors.black54, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style:
                      TextStyle(color: dark ? Colors.white54 : Colors.black45)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('End Trip',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

// ── Shared UI Components ─────────────────────────────────────────────────────

class _SimpleNumericField extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool dark;
  final ValueChanged<String> onChanged;

  const _SimpleNumericField({
    required this.label,
    required this.icon,
    required this.dark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        style: TextStyle(color: dark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          filled: true,
          fillColor: dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          labelStyle: TextStyle(color: dark ? Colors.white54 : Colors.black45),
        ),
      );
}

class _DirectionToggle extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool dark;

  const _DirectionToggle({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primary
                : (dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? AppTheme.primary
                  : (dark ? Colors.white10 : Colors.black12),
            ),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : (dark ? Colors.white38 : Colors.black45),
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                )),
          ),
        ),
      );
}

class _SosButton extends StatelessWidget {
  final bool holding;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  const _SosButton({
    required this.holding,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 15),
            SizedBox(width: 6),
            Text('Emergency SOS',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          GestureDetector(
            onLongPressStart: (_) => onHoldStart(),
            onLongPressEnd: (_) => onHoldEnd(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 54,
              decoration: BoxDecoration(
                color: holding ? Colors.red : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                boxShadow: holding
                    ? [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  holding
                      ? '🚨  Release to send SOS...'
                      : 'Hold 2 seconds to trigger SOS',
                  style: TextStyle(
                    color: holding ? Colors.white : Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  final bool dark;
  final Color? borderColor;
  final Color? bgColor;
  final EdgeInsets? padding;
  const _InfoCard({
    required this.child,
    required this.dark,
    this.borderColor,
    this.bgColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor ??
              (dark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: borderColor ??
                  (dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06))),
        ),
        child: child,
      );
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool dark;
  final Color? valueColor;
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.dark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(icon, color: AppTheme.primary, size: 17),
            const SizedBox(height: 5),
            Text(value,
                style: TextStyle(
                    color: valueColor ?? (dark ? Colors.white : Colors.black87),
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: dark ? Colors.white38 : Colors.black38,
                    fontSize: 10)),
          ]),
        ),
      );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedOpacity(
          opacity: loading ? 0.6 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      );
}

class _ErrBanner extends StatelessWidget {
  final String message;
  final bool dark;
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
