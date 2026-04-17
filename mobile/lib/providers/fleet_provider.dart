// lib/providers/fleet_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bus.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'auth_provider.dart';

class FleetState {
  final List<Bus> buses;
  final bool loading;
  final bool liveViaWs;
  final String? error;

  const FleetState({
    this.buses = const [],
    this.loading = false,
    this.liveViaWs = false,
    this.error,
  });

  FleetState copyWith({
    List<Bus>? buses,
    bool? loading,
    bool? liveViaWs,
    String? error,
  }) =>
      FleetState(
        buses: buses ?? this.buses,
        loading: loading ?? this.loading,
        liveViaWs: liveViaWs ?? this.liveViaWs,
        error: error ?? this.error,
      );
}

class FleetNotifier extends StateNotifier<FleetState> {
  final Ref _ref;
  FleetNotifier(this._ref) : super(const FleetState()) {
    loadFleet();
  }

  Future<void> loadFleet() async {
    state = state.copyWith(loading: true);
    try {
      final user = _ref.read(currentUserProvider);
      // Admin vs Superadmin endpoint logic based on your Laravel structure
      final endpoint =
          (user?.role == 'superadmin') ? '/super/fleets' : ApiConfig.adminFleet;

      final raw = await ApiService.get(endpoint);
      final List list = (raw is Map) ? (raw['fleet'] ?? raw['data'] ?? []) : [];

      final buses =
          list.map((e) => Bus.fromJson(Map<String, dynamic>.from(e))).toList();
      state = state.copyWith(buses: buses, loading: false);
    } catch (e) {
      state =
          state.copyWith(loading: false, error: 'Failed to sync fleet data');
    }
  }

  // Backward-compatible alias used by multiple screens.
  Future<void> load() => loadFleet();

  // Surgically update a bus when a GpsPing or Reverb event comes in
  void updateBusLocation(Map<String, dynamic> data) {
    final id = data['bus_id'];
    state = state.copyWith(
      buses: state.buses.map((b) {
        if (b.id == id) {
          return b.copyWith(
            latitude: (data['lat'] as num?)?.toDouble(),
            longitude: (data['lng'] as num?)?.toDouble(),
            status: data['status'] ?? b.status,
          );
        }
        return b;
      }).toList(),
    );
  }
}

final fleetProvider = StateNotifierProvider<FleetNotifier, FleetState>(
    (ref) => FleetNotifier(ref));
