import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_trip_provider.dart';
import '../../features/messaging/messaging.dart';

// Your existing modular components
import 'driver_header.dart';
import 'driver_bottom_nav.dart';
import 'driver_tabs.dart';
import 'trip_control_sheet.dart';
import 'driver_route_map.dart'; // Ensure this is imported directly

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final trip = ref.watch(driverTripProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final unread = ref.watch(totalUnreadProvider);

    // Bubble trip errors as Snackbars (matching Laravel feedback)
    ref.listen(driverTripProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${next.error}'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(driverTripProvider.notifier).clearError();
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: dark ? AppTheme.black : AppTheme.lightBg,
        body: SafeArea(
          child: Stack(
            children: [
              // ── Main Layout ───────────────────────────────────────────────
              Column(
                children: [
                  // Show header only when not on full-screen map (Tab 1)
                  if (_tab != 1)
                    DriverHeader(
                      driver: auth.user,
                      trip: trip,
                      dark: dark,
                      unread: unread,
                      onMessageTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MessagingInboxScreen(),
                        ),
                      ),
                    ),

                  Expanded(
                    child: IndexedStack(
                      index: _tab,
                      // REMOVED 'const' from children list to fix dart2js error
                      children: [
                        const DriverHomeTab(),
                        DriverRouteMap(), // Likely contains non-const Map logic
                        const DriverStudentsTab(),
                        const DriverReportsTab(),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Global Messaging Overlays ──────────────────────────────
              RepaintBoundary(
                child: Consumer(
                  builder: (ctx, ref, _) {
                    final incoming = ref.watch(incomingPopupProvider);
                    if (incoming == null) return const SizedBox.shrink();
                    return Positioned(
                      top: 8,
                      left: 16,
                      right: 16,
                      child: IncomingMessageBanner(
                        incoming: incoming,
                        onDismiss: () =>
                            ref.read(incomingPopupProvider.notifier).dismiss(),
                        onReply: () {
                          ref.read(incomingPopupProvider.notifier).dismiss();
                          // Navigation logic for the specific chat thread
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // ── Unified Trip Action Button ────────────────────────────────────
        floatingActionButton: _tab == 1
            ? null // Hide on map tab to prevent cluttering map controls
            : _buildTripFab(trip),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

        bottomNavigationBar: DriverBottomNav(
          index: _tab,
          onTap: (i) => setState(() => _tab = i),
          dark: dark,
        ),
      ),
    );
  }

  // ─── Refactored FAB Builder ──────────────────────────────────────────────

  Widget _buildTripFab(DriverTripState trip) {
    if (trip.isOnTrip) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Broadcast Button (Quick alerts to admins)
          FloatingActionButton.small(
            heroTag: 'sos_quick',
            backgroundColor: AppTheme.danger,
            onPressed: () => _showSosConfirm(context),
            child:
                const Icon(Icons.emergency_share_rounded, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'trip_active',
            onPressed: () => _showTripSheet(context),
            backgroundColor: trip.isPaused ? Colors.orange : AppTheme.success,
            icon: Icon(
              trip.isPaused
                  ? Icons.pause_circle_rounded
                  : Icons.navigation_rounded,
              color: Colors.white,
            ),
            label: Text(
              trip.isPaused ? 'TRIP PAUSED' : 'ON TRIP',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    return FloatingActionButton.extended(
      heroTag: 'trip_start',
      onPressed: () => _showTripSheet(context),
      backgroundColor: AppTheme.primary,
      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
      label: const Text(
        'START TRIP',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─── Sheets & Overlays ───────────────────────────────────────────────────

  void _showTripSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TripControlSheet(),
    );
  }

  void _showSosConfirm(BuildContext context) {
    HapticFeedback.vibrate();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send SOS Alert?'),
        content: const Text(
            'This will immediately notify school admins of your current location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              ref.read(driverTripProvider.notifier).triggerSos();
              Navigator.pop(ctx);
            },
            child:
                const Text('SEND SOS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
