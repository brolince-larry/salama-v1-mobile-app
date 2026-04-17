import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

// ── Safe cast helpers ─────────────────────────────────────────────────────────

Map<String, dynamic>? _mapOrNull(dynamic v) {
  if (v == null) return null;
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

Map<String, dynamic> _map(dynamic v) => _mapOrNull(v) ?? {};

List<dynamic> _list(dynamic v) => v is List ? v : [];

// ── Home data model ───────────────────────────────────────────────────────────

class DriverHomeData {
  final Map<String, dynamic>? driver;
  final Map<String, dynamic>? bus;
  final Map<String, dynamic>? activeTrip;
  final Map<String, dynamic>? nextTrip;
  final List<dynamic>         todayTrips;
  final Map<String, dynamic>? boardingStats;
  final Map<String, dynamic>? liveLocation;

  const DriverHomeData({
    this.driver,
    this.bus,
    this.activeTrip,
    this.nextTrip,
    this.todayTrips   = const [],
    this.boardingStats,
    this.liveLocation,
  });

  // Fix lines 27-33: replace `as Map<String,dynamic>?` and `as List?`
  // with helpers that return null/[] instead of throwing on wrong types.
  factory DriverHomeData.fromJson(Map<String, dynamic> j) => DriverHomeData(
        driver:        _mapOrNull(j['driver']),
        bus:           _mapOrNull(j['bus']),
        activeTrip:    _mapOrNull(j['active_trip']),
        nextTrip:      _mapOrNull(j['next_trip']),
        todayTrips:    _list(j['today_trips']),
        boardingStats: _mapOrNull(j['boarding_stats']),
        liveLocation:  _mapOrNull(j['live_location']),
      );
}

// ── Home state ────────────────────────────────────────────────────────────────

class DriverHomeState {
  final DriverHomeData? data;
  final bool            loading;
  final String?         error;

  const DriverHomeState({this.data, this.loading = false, this.error});

  DriverHomeState copyWith({
    DriverHomeData? data,
    bool?           loading,
    String?         error,
    bool            clearError = false,
  }) =>
      DriverHomeState(
        data:    data    ?? this.data,
        loading: loading ?? this.loading,
        error:   clearError ? null : error ?? this.error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class DriverHomeNotifier extends StateNotifier<DriverHomeState> {
  DriverHomeNotifier() : super(const DriverHomeState(loading: true)) {
    fetch();
  }

  Future<void> fetch() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final raw = await ApiService.get(ApiConfig.driverHome);
      // Fix line 71: `json as Map<String,dynamic>` → _map() never throws
      state = DriverHomeState(
        data:    DriverHomeData.fromJson(_map(raw)),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading:    false,
        error:      e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

final driverHomeProvider =
    StateNotifierProvider<DriverHomeNotifier, DriverHomeState>(
  (ref) => DriverHomeNotifier(),
);

// ── Trip history ──────────────────────────────────────────────────────────────

class TripHistoryState {
  final List<dynamic> trips;
  final bool          loading;
  final String?       error;

  const TripHistoryState({
    this.trips   = const [],
    this.loading = false,
    this.error,
  });
}

class TripHistoryNotifier extends StateNotifier<TripHistoryState> {
  TripHistoryNotifier() : super(const TripHistoryState(loading: true)) {
    fetch();
  }

  Future<void> fetch() async {
    try {
      final raw = await ApiService.get(ApiConfig.tripHistory);
      // Fix line 111: `json as Map<String,dynamic>` → _map()
      final data = _map(raw);
      state = TripHistoryState(
        trips:   _list(data['data']),
        loading: false,
      );
    } catch (e) {
      state = TripHistoryState(
        loading: false,
        error:   e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

final tripHistoryProvider =
    StateNotifierProvider.autoDispose<TripHistoryNotifier, TripHistoryState>(
  (ref) => TripHistoryNotifier(),
);

// ── Driver notifications ──────────────────────────────────────────────────────

class DriverNotificationsState {
  final List<dynamic> notifications;
  final bool          loading;
  final String?       error;

  const DriverNotificationsState({
    this.notifications = const [],
    this.loading       = false,
    this.error,
  });
}

class DriverNotificationsNotifier
    extends StateNotifier<DriverNotificationsState> {
  DriverNotificationsNotifier()
      : super(const DriverNotificationsState(loading: true)) {
    fetch();
  }

  Future<void> fetch() async {
    try {
      final raw = await ApiService.get(ApiConfig.driverNotifications);
      // Fix line 155: `json as Map<String,dynamic>` → _map()
      final data = _map(raw);
      state = DriverNotificationsState(
        notifications: _list(data['notifications']),
        loading:       false,
      );
    } catch (e) {
      state = DriverNotificationsState(
        loading: false,
        error:   e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

final driverNotificationsProvider = StateNotifierProvider.autoDispose<
    DriverNotificationsNotifier, DriverNotificationsState>(
  (ref) => DriverNotificationsNotifier(),
);