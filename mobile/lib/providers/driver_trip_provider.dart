import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

// --- Student Model ---
class TripStudent {
  final int id;
  final String name;
  final String? photoUrl;
  final int stopId;
  final String
      stopName; // Changed from String? to String for easier UI handling
  StudentStatus status;

  TripStudent({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.stopId,
    required this.stopName, // Made required
    this.status = StudentStatus.waiting,
  });

  factory TripStudent.fromJson(Map<String, dynamic> j) => TripStudent(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? 'Student',
        photoUrl: j['photo_url'] as String?,
        stopId: (j['stop_id'] as num? ?? 0).toInt(),
        // Fallback to "Unknown Stop" to satisfy non-nullable String and dart2js strictness
        stopName: (j['stop'] is Map)
            ? (j['stop']['name'] as String? ?? 'Unknown Stop')
            : 'Unknown Stop',
      );
}

enum StudentStatus { waiting, pickedUp, dropped }

enum TripPhase { idle, active, paused, ended }

class DriverTripState {
  final TripPhase phase;
  final int? tripId;
  final int? busId;
  final int? routeId;
  final String? direction;
  final int pingCount;
  final double? lat;
  final double? lng;
  final double? speed;
  final double? heading;
  final bool sosSent;
  final bool loading;
  final String? error;
  final List<TripStudent> students;

  const DriverTripState({
    this.phase = TripPhase.idle,
    this.tripId,
    this.busId,
    this.routeId,
    this.direction,
    this.pingCount = 0,
    this.lat,
    this.lng,
    this.speed,
    this.heading,
    this.sosSent = false,
    this.loading = false,
    this.error,
    this.students = const [],
  });

  bool get isActive => phase == TripPhase.active;
  bool get isPaused => phase == TripPhase.paused;
  bool get isOnTrip => isActive || isPaused;
  int get pickedCount =>
      students.where((s) => s.status == StudentStatus.pickedUp).length;

  DriverTripState copyWith({
    TripPhase? phase,
    int? tripId,
    int? busId,
    int? routeId,
    String? direction,
    int? pingCount,
    double? lat,
    double? lng,
    double? speed,
    double? heading,
    bool? sosSent,
    bool? loading,
    String? error,
    bool clearError = false,
    List<TripStudent>? students,
  }) =>
      DriverTripState(
        phase: phase ?? this.phase,
        tripId: tripId ?? this.tripId,
        busId: busId ?? this.busId,
        routeId: routeId ?? this.routeId,
        direction: direction ?? this.direction,
        pingCount: pingCount ?? this.pingCount,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        speed: speed ?? this.speed,
        heading: heading ?? this.heading,
        sosSent: sosSent ?? this.sosSent,
        loading: loading ?? this.loading,
        error: clearError ? null : error ?? this.error,
        students: students ?? this.students,
      );
}

class DriverTripNotifier extends StateNotifier<DriverTripState> {
  DriverTripNotifier() : super(const DriverTripState()) {
    _restoreActiveTripFromBackend();
  }

  StreamSubscription<Position>? _gpsSub;
  DateTime? _lastPingTime;

  /// FIX: Added back the refresh method required by driver_dashboard.dart
  Future<void> refreshStudents() async {
    final tid = state.tripId;
    if (tid == null) return;

    state = state.copyWith(loading: true);
    try {
      await _fetchStudents(tid);
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> startTrip({
    required int routeId,
    required int busId,
    required String direction,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await ApiService.post(ApiConfig.startTrip, body: {
        'route_id': routeId,
        'bus_id': busId,
        'direction': direction,
      });

      final data = Map<String, dynamic>.from(response as Map);
      final newTripId = (data['trip_id'] as num).toInt();

      state = state.copyWith(
        phase: TripPhase.active,
        tripId: newTripId,
        busId: busId,
        routeId: routeId,
        direction: direction,
        loading: false,
      );

      await _startGps();
      await _fetchStudents(newTripId);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> triggerSos() async {
    if (state.tripId == null || state.sosSent) return;
    try {
      await ApiService.post(ApiConfig.tripSos(state.tripId!));
      state = state.copyWith(sosSent: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _onPosition(Position pos) {
    state = state.copyWith(
      lat: pos.latitude,
      lng: pos.longitude,
      speed: pos.speed * 3.6,
      heading: pos.heading,
    );

    final now = DateTime.now();
    if (_lastPingTime == null ||
        now.difference(_lastPingTime!) >= const Duration(seconds: 2)) {
      _lastPingTime = now;
      _sendPing(pos);
    }
  }

  Future<void> _sendPing(Position pos) async {
    if (!state.isActive || state.tripId == null) return;
    try {
      await ApiService.post(
        ApiConfig.gpsPing,
        body: {
          'trip_id': state.tripId,
          'bus_id': state.busId,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'speed': pos.speed * 3.6,
          'heading': pos.heading,
        },
      );
      state = state.copyWith(pingCount: state.pingCount + 1);
    } catch (_) {}
  }

  Future<void> _fetchStudents(int tripId) async {
    try {
      final raw = await ApiService.get(ApiConfig.tripStudents(tripId));

      List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        list = raw['students'] as List? ?? raw['data'] as List? ?? [];
      } else {
        list = [];
      }

      final students = list
          .map((e) => TripStudent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      await _syncStudentStatuses(tripId, students);
      state = state.copyWith(students: students, clearError: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _syncStudentStatuses(
      int tripId, List<TripStudent> students) async {
    await Future.wait(students.map((s) async {
      try {
        final raw =
            await ApiService.get(ApiConfig.tripStudentStatus(tripId, s.id));
        final statusRaw = _extractStatusString(raw);
        s.status = _statusFromRaw(statusRaw);
      } catch (_) {}
    }));
  }

  String? _extractStatusString(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    if (raw is Map) {
      return (raw['status'] ?? raw['action'] ?? raw['student_status'])
          ?.toString();
    }
    return null;
  }

  StudentStatus _statusFromRaw(String? raw) {
    if (raw == null) return StudentStatus.waiting;
    final norm = raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (norm.contains('boarded') || norm.contains('pickedup'))
      return StudentStatus.pickedUp;
    if (norm.contains('dropped') || norm.contains('dropoff'))
      return StudentStatus.dropped;
    return StudentStatus.waiting;
  }

  Future<void> pauseTrip() async {
    final tripId = state.tripId;
    if (tripId == null || state.isPaused) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      await ApiService.post(ApiConfig.pauseTrip(tripId));
      _stopGps();
      state = state.copyWith(phase: TripPhase.paused, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> resumeTrip() async {
    final tripId = state.tripId;
    if (tripId == null || state.isActive) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      await ApiService.post(ApiConfig.resumeTrip(tripId));
      state = state.copyWith(phase: TripPhase.active, loading: false);
      await _startGps();
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> endTrip() async {
    final tripId = state.tripId;
    if (tripId == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      await ApiService.post(ApiConfig.tripEnd(tripId));
      _stopGps();
      state = const DriverTripState(phase: TripPhase.ended);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> _restoreActiveTripFromBackend() async {
    await _syncActiveTripContext();
  }

  Future<void> _syncActiveTripContext() async {
    try {
      final raw = await ApiService.get(ApiConfig.driverRoute);
      final data = Map<String, dynamic>.from(raw as Map);
      final tripData = data['trip'] ?? data['active_trip'];

      if (tripData == null) {
        if (state.isOnTrip) _stopGps();
        state =
            state.copyWith(phase: TripPhase.idle, tripId: null, loading: false);
        return;
      }

      final tripMap = Map<String, dynamic>.from(tripData as Map);
      final status = (tripMap['status'] as String? ?? 'active').toLowerCase();
      final tripId = (tripMap['id'] as num).toInt();
      final busId = (tripMap['bus_id'] as num?)?.toInt() ?? 0;

      final phase = status == 'paused' ? TripPhase.paused : TripPhase.active;

      state = state.copyWith(
        phase: phase,
        tripId: tripId,
        busId: busId,
        loading: false,
        clearError: true,
      );

      if (phase == TripPhase.active) {
        await _startGps();
      } else {
        _stopGps();
      }

      await _fetchStudents(tripId);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> _startGps() async {
    if (_gpsSub != null) return;
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen(_onPosition);
  }

  void _stopGps() {
    _gpsSub?.cancel();
    _gpsSub = null;
  }

  void clearError() => state = state.copyWith(clearError: true);

  @override
  void dispose() {
    _stopGps();
    super.dispose();
  }
}

final driverTripProvider =
    StateNotifierProvider<DriverTripNotifier, DriverTripState>(
        (ref) => DriverTripNotifier());
