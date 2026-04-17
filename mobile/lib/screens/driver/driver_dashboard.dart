// lib/screens/driver/driver_dashboard.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import 'home_screen.dart'; // The UI you want to display
import '../../providers/driver_trip_provider.dart';

/// This is the entry point after Login.
/// It initializes services and then hosts the HomeScreen.
class DriverDashboard extends ConsumerStatefulWidget {
  const DriverDashboard({super.key});

  @override
  ConsumerState<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<DriverDashboard> {
  Timer? _dataRefreshTimer;

  // Publicly accessible Mapbox Token matching your config
  static const String _kMapboxToken =
      'pk.eyJ1IjoiYnJvbGluY2UiLCJhIjoiY21ucWJiMHRyMDU5cDJ3cXB4ZzA5ZmI1ayJ9.Guvi2WbAjg9hMpfCC6amwQ';

  @override
  void initState() {
    super.initState();

    // 1. Initialize Mapbox once globally for the session
    mbx.MapboxOptions.setAccessToken(_kMapboxToken);

    // 2. Background Task: Refresh underlying route data every 60s
    // This keeps the trip data fresh even if the driver is on the "Home" or "Reports" tab.
    _dataRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        // Silently refresh the trip state to match Laravel backend
        ref.read(driverTripProvider.notifier).refreshStudents();
      }
    });
  }

  @override
  void dispose() {
    _dataRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We return the DriverHomeScreen directly.
    // This effectively "redirects" the logic while keeping the route stack clean.
    return const DriverHomeScreen();
  }
}
