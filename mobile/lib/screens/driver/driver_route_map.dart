// lib/screens/driver/driver_route_map.dart
//
// Real-time navigation screen for drivers — matches reference image:
//   • Live GPS camera follows driver heading at pitch 45°
//   • Green route polyline from current position to final destination
//   • Numbered bus-stop pins with student count
//   • Maneuver card top-left (turn arrow + distance + street name)
//   • Speed badge top-right (current speed + speed limit sign)
//   • Progress panel bottom (remaining km · travel time · ETA · traffic bar)
//   • Turn-by-turn step list drawer (right side button)
//
// Data sources:
//   • Driver GPS: driverTripProvider (Geolocator stream, 10m filter)
//   • Route + stops: GET /driver/route  → waypoints list
//   • Directions: Mapbox Directions API (driving-traffic profile)
//
// Platform:
//   • Mobile → mapbox_maps_flutter native SDK
//   • Web    → flutter_map + Mapbox REST tiles

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart'
    as fmc;
import '../../config/app_theme.dart';
import '../../providers/driver_trip_provider.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kToken =
    'pk.eyJ1IjoiYnJvbGluY2UiLCJhIjoiY21ucWJiMHRyMDU5cDJ3cXB4ZzA5ZmI1ayJ9'
    '.Guvi2WbAjg9hMpfCC6amwQ';
const _kStyle = 'mapbox://styles/mapbox/navigation-night-v1';
const _kTileUrl =
    'https://api.mapbox.com/styles/v1/mapbox/navigation-night-v1/tiles/{z}/{x}/{y}@2x'
    '?access_token=$_kToken';
const _kDirBase = 'https://api.mapbox.com/directions/v5/mapbox/driving-traffic';
const _kSpeedLimitKmh = 60;

// ─── Models ───────────────────────────────────────────────────────────────────

class _RouteData {
  final List<ll.LatLng> geometry;
  final List<_NavStep> steps;
  final double distanceKm;
  final int durationMin;
  final int? durationTrafficMin;
  final List<double> congestion; // 0–1 per vertex

  const _RouteData({
    required this.geometry,
    required this.steps,
    required this.distanceKm,
    required this.durationMin,
    this.durationTrafficMin,
    this.congestion = const [],
  });

  String get etaString {
    final t = DateTime.now()
        .add(Duration(minutes: durationTrafficMin ?? durationMin));
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  double remainingKm(double progress) =>
      distanceKm * (1.0 - progress.clamp(0.0, 1.0));
}

class _NavStep {
  final String instruction, type, modifier;
  final double distanceM;
  final ll.LatLng location;
  const _NavStep(
      {required this.instruction,
      required this.type,
      required this.modifier,
      required this.distanceM,
      required this.location});
}

class _BusStop {
  final int index;
  final String name;
  final ll.LatLng location;
  final int studentCount;
  const _BusStop(
      {required this.index,
      required this.name,
      required this.location,
      required this.studentCount});
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _stopsProvider = FutureProvider.autoDispose<List<_BusStop>>((ref) async {
  try {
    final raw = await ApiService.get(ApiConfig.driverRoute);
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final route = map['route'];
    final list = route is Map
        ? (route['stops'] as List? ?? const [])
        : map['stops'] is List
            ? map['stops'] as List
            : map['waypoints'] is List
                ? map['waypoints'] as List
                : map['data'] is List
                    ? map['data'] as List
                    : raw is List
                        ? raw
                        : const [];
    return list
        .asMap()
        .entries
        .map((e) {
          final s = e.value as Map;
          final lat = (s['lat'] as num?)?.toDouble();
          final lng = (s['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return null;
          return _BusStop(
            index: e.key,
            name: s['name'] as String? ?? 'Stop ${e.key + 1}',
            location: ll.LatLng(lat, lng),
            studentCount: (s['student_count'] as num?)?.toInt() ?? 0,
          );
        })
        .whereType<_BusStop>()
        .toList();
  } catch (_) {
    return [];
  }
});

final _directionsProvider = FutureProvider.autoDispose
    .family<_RouteData?, List<ll.LatLng>>((ref, wps) async {
  if (wps.length < 2) return null;
  try {
    final coords = wps.map((p) => '${p.longitude},${p.latitude}').join(';');
    final uri = Uri.parse(
      '$_kDirBase/$coords'
      '?geometries=geojson&steps=true&overview=full'
      '&annotations=congestion_numeric&access_token=$_kToken',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) return null;
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final routes = (body['routes'] as List?)?.cast<Map<String, dynamic>>();
    if (routes == null || routes.isEmpty) return null;
    final route = routes.first;

    final geom = (route['geometry']['coordinates'] as List)
        .map((c) =>
            ll.LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();

    final steps = <_NavStep>[];
    final cong = <double>[];
    for (final leg in (route['legs'] as List)) {
      for (final s in (leg as Map)['steps'] as List) {
        final m = (s as Map)['maneuver'] as Map;
        final loc = m['location'] as List;
        steps.add(_NavStep(
          instruction: m['instruction'] as String? ?? '',
          type: m['type'] as String? ?? 'straight',
          modifier: m['modifier'] as String? ?? 'straight',
          distanceM: (s['distance'] as num).toDouble(),
          location:
              ll.LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
        ));
      }
      final ann = leg['annotation'] as Map?;
      for (final v in (ann?['congestion_numeric'] as List? ?? [])) {
        cong.add(((v as num? ?? 0) / 100.0).clamp(0.0, 1.0));
      }
    }

    return _RouteData(
      geometry: geom,
      steps: steps,
      distanceKm: (route['distance'] as num) / 1000,
      durationMin: ((route['duration'] as num) / 60).round(),
      durationTrafficMin: route['duration_typical'] != null
          ? ((route['duration_typical'] as num) / 60).round()
          : null,
      congestion: cong,
    );
  } catch (_) {
    return null;
  }
});

// ─── Main Widget ──────────────────────────────────────────────────────────────

class DriverRouteMap extends ConsumerStatefulWidget {
  const DriverRouteMap({super.key});
  @override
  ConsumerState<DriverRouteMap> createState() => _DriverRouteMapState();
}

class _DriverRouteMapState extends ConsumerState<DriverRouteMap> {
  // Mobile
  mbx.MapboxMap? _mbMap;
  mbx.PolylineAnnotationManager? _polyAm;
  mbx.PointAnnotationManager? _pinAm;
  mbx.PointAnnotation? _driverPin;
  final Map<int, mbx.PointAnnotation> _stopPins = {};
  String? _lastRouteKey;

  // Web
  final _fmCtrl = fm.MapController();

  // UI state
  bool _followMode = true;
  bool _showSteps = false;
  int _stepIdx = 0;
  double _progress = 0.0;

  // Cached marker bytes
  Uint8List? _driverArrowBytes;
  final Map<int, Uint8List> _stopPinBytes = {};

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(driverTripProvider);
    final stops = ref.watch(_stopsProvider);

    // Build waypoints: driver → each stop
    final waypoints = <ll.LatLng>[];
    if (trip.lat != null) {
      waypoints.add(ll.LatLng(trip.lat!, trip.lng!));
    }
    stops.whenData((list) {
      for (final s in list) {
        waypoints.add(s.location);
      }
    });

    final dirAsync = ref.watch(_directionsProvider(waypoints));
    final route = dirAsync.valueOrNull;

    if (route != null && trip.lat != null) {
      _progress =
          _calcProgress(route.geometry, ll.LatLng(trip.lat!, trip.lng!));
      _stepIdx = _nearestStep(route.steps, ll.LatLng(trip.lat!, trip.lng!));
    }

    // Mobile: follow camera + redraw route
    ref.listen(driverTripProvider, (_, next) {
      if (kIsWeb || next.lat == null || _mbMap == null) return;
      if (_followMode) {
        _mbMap!.flyTo(
          mbx.CameraOptions(
            center: mbx.Point(coordinates: mbx.Position(next.lng!, next.lat!)),
            zoom: 17,
            pitch: 45,
            bearing: next.heading ?? 0,
          ),
          mbx.MapAnimationOptions(duration: 600, startDelay: 0),
        );
      }
      final key = '${route?.distanceKm.toStringAsFixed(2)}_'
          '${next.lat!.toStringAsFixed(4)}';
      if (key != _lastRouteKey && route != null) {
        _lastRouteKey = key;
        _drawMobile(route, next, stops.valueOrNull ?? []);
      }
    });

    final currentStep = (route != null && _stepIdx < route.steps.length)
        ? route.steps[_stepIdx]
        : null;
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(children: [
        // ── MAP ──────────────────────────────────────────────────────────
        if (kIsWeb)
          _buildWebMap(trip, route, stops.valueOrNull ?? [])
        else
          mbx.MapWidget(
            key: const ValueKey('drv_nav'),
            styleUri: _kStyle,
            cameraOptions: mbx.CameraOptions(
              center: mbx.Point(
                  coordinates:
                      mbx.Position(trip.lng ?? 36.8219, trip.lat ?? -1.2921)),
              zoom: 16,
              pitch: 45,
              bearing: trip.heading ?? 0,
            ),
            onMapCreated: (map) async {
              _mbMap = map;
              _polyAm = await map.annotations.createPolylineAnnotationManager();
              _pinAm = await map.annotations.createPointAnnotationManager();
              if (route != null) {
                _drawMobile(route, trip, stops.valueOrNull ?? []);
              }
            },
          ),

        // ── TOP-LEFT: Maneuver card ───────────────────────────────────────
        Positioned(
            top: top + 14,
            left: 14,
            child:
                _ManeuverCard(step: currentStep, loading: dirAsync.isLoading)),

        // ── TOP-RIGHT: Speed badge ────────────────────────────────────────
        Positioned(
            top: top + 14, right: 14, child: _SpeedBadge(speedKmh: trip.speed)),

        // ── RIGHT: Map controls ───────────────────────────────────────────
        Positioned(
          right: 14,
          top: top + 155,
          child: Column(children: [
            _MapBtn(
              icon: _followMode
                  ? Icons.navigation_rounded
                  : Icons.gps_not_fixed_rounded,
              active: _followMode,
              onTap: () {
                setState(() => _followMode = !_followMode);
                if (_followMode && trip.lat != null && !kIsWeb) {
                  _mbMap?.flyTo(
                    mbx.CameraOptions(
                      center: mbx.Point(
                          coordinates: mbx.Position(trip.lng!, trip.lat!)),
                      zoom: 17,
                      pitch: 45,
                      bearing: trip.heading ?? 0,
                    ),
                    mbx.MapAnimationOptions(duration: 600, startDelay: 0),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            _MapBtn(
                icon: Icons.add_rounded,
                onTap: () {
                  if (!kIsWeb) {
                    _mbMap?.getCameraState().then((c) => _mbMap?.setCamera(
                        mbx.CameraOptions(zoom: (c.zoom + 1).clamp(1, 22))));
                  } else {
                    _fmCtrl.move(
                        _fmCtrl.camera.center, _fmCtrl.camera.zoom + 1);
                  }
                }),
            const SizedBox(height: 10),
            _MapBtn(
                icon: Icons.remove_rounded,
                onTap: () {
                  if (!kIsWeb) {
                    _mbMap?.getCameraState().then((c) => _mbMap?.setCamera(
                        mbx.CameraOptions(zoom: (c.zoom - 1).clamp(1, 22))));
                  } else {
                    _fmCtrl.move(
                        _fmCtrl.camera.center, _fmCtrl.camera.zoom - 1);
                  }
                }),
            const SizedBox(height: 10),
            _MapBtn(
                icon: Icons.list_rounded,
                active: _showSteps,
                onTap: () => setState(() => _showSteps = !_showSteps)),
          ]),
        ),

        // ── BOTTOM: Progress panel ────────────────────────────────────────
        Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ProgressPanel(
                route: route,
                progress: _progress,
                loading: dirAsync.isLoading)),

        // ── Step list ─────────────────────────────────────────────────────
        if (_showSteps && route != null)
          Positioned(
            top: top + 14,
            bottom: 170,
            left: 14,
            right: 70,
            child: _StepList(
              steps: route.steps,
              current: _stepIdx,
              onTap: (i) => setState(() {
                _stepIdx = i;
                _showSteps = false;
              }),
              onClose: () => setState(() => _showSteps = false),
            ),
          ),

        // ── Loading indicator ─────────────────────────────────────────────
        if (dirAsync.isLoading && waypoints.length >= 2)
          Positioned(
              top: top + 104,
              left: 0,
              right: 0,
              child: Center(
                  child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(24)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: AppTheme.primary, strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Calculating route…',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ))),

        // ── No trip message ───────────────────────────────────────────────
        if (!trip.isActive && route == null && !dirAsync.isLoading)
          Positioned(
              top: top + 104,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08))),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppTheme.primary, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text(
                    'Start a trip to load your route and turn-by-turn directions.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.4),
                  )),
                ]),
              )),
      ]),
    );
  }

  // ─── Web map ──────────────────────────────────────────────────────────────

  Widget _buildWebMap(
      DriverTripState trip, _RouteData? route, List<_BusStop> stops) {
    // Follow mode: move camera to driver on GPS update
    if (_followMode && trip.lat != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _fmCtrl.move(ll.LatLng(trip.lat!, trip.lng!), 15);
        } catch (_) {}
      });
    }

    final segments = route != null
        ? _congestionSegments(route.geometry, route.congestion)
        : <_Seg>[];

    return fm.FlutterMap(
      mapController: _fmCtrl,
      options: fm.MapOptions(
        initialCenter: trip.lat != null
            ? ll.LatLng(trip.lat!, trip.lng!)
            : const ll.LatLng(-1.2921, 36.8219),
        initialZoom: 15,
        backgroundColor: const Color(0xFF0D1117),
      ),
      children: [
        fm.TileLayer(
          urlTemplate: _kTileUrl,
          retinaMode: true,
          tileProvider: fmc.CancellableNetworkTileProvider(),
          userAgentPackageName: 'com.schooltrack.app',
        ),

        // Route polyline (split by congestion colour)
        if (segments.isNotEmpty)
          fm.PolylineLayer(polylines: [
            // Shadow
            fm.Polyline(
                points: route!.geometry,
                color: Colors.black.withValues(alpha: 0.5),
                strokeWidth: 10),
            // Coloured segments
            ...segments.map((s) => fm.Polyline(
                points: s.pts, color: Color(s.argbColor), strokeWidth: 7)),
          ]),

        // Bus stop markers
        fm.MarkerLayer(markers: [
          ...stops.map((s) => fm.Marker(
                point: s.location,
                width: 52,
                height: 68,
                alignment: Alignment.bottomCenter,
                child: _WebStopPin(stop: s),
              )),

          // Driver arrow
          if (trip.lat != null)
            fm.Marker(
              point: ll.LatLng(trip.lat!, trip.lng!),
              width: 52,
              height: 52,
              alignment: Alignment.center,
              child: Transform.rotate(
                angle: (trip.heading ?? 0) * math.pi / 180,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.6),
                          blurRadius: 20,
                          spreadRadius: 4)
                    ],
                  ),
                  child: const Icon(Icons.navigation_rounded,
                      color: Colors.white, size: 28),
                ),
              ),
            ),
        ]),
      ],
    );
  }

  // ─── Mobile: draw everything ──────────────────────────────────────────────

  Future<void> _drawMobile(
      _RouteData route, DriverTripState trip, List<_BusStop> stops) async {
    if (_mbMap == null) return;
    await _polyAm?.deleteAll();

    // Route polyline segments by congestion
    if (route.geometry.length > 1) {
      for (final seg in _congestionSegments(route.geometry, route.congestion)) {
        await _polyAm?.create(mbx.PolylineAnnotationOptions(
          geometry: mbx.LineString(
              coordinates: seg.pts
                  .map((p) => mbx.Position(p.longitude, p.latitude))
                  .toList()),
          lineColor: seg.argbColor,
          lineWidth: 8.0,
          lineBlur: 0.6,
        ));
      }
      if (_lastRouteKey == null) _fitMobile(route.geometry);
    }

    // Driver arrow pin
    if (trip.lat != null) {
      _driverArrowBytes ??= await _buildArrowBytes(trip.heading ?? 0);
      final pt = mbx.Point(coordinates: mbx.Position(trip.lng!, trip.lat!));
      if (_driverPin == null) {
        _driverPin = await _pinAm?.create(mbx.PointAnnotationOptions(
          geometry: pt,
          image: _driverArrowBytes!,
          iconSize: 1.0,
        ));
      } else {
        _driverPin!.geometry = pt;
        _driverPin!.image = await _buildArrowBytes(trip.heading ?? 0);
        await _pinAm?.update(_driverPin!);
      }
    }

    // Bus stop pins — only create once, update position if changed
    for (final s in stops) {
      _stopPinBytes[s.index] ??= await _buildStopPinBytes(
          s.index + 1, s.name, s.studentCount, s.index == stops.length - 1);
      final pt = mbx.Point(
          coordinates: mbx.Position(s.location.longitude, s.location.latitude));
      if (_stopPins.containsKey(s.index)) {
        _stopPins[s.index]!.geometry = pt;
        await _pinAm?.update(_stopPins[s.index]!);
      } else {
        final ann = await _pinAm?.create(mbx.PointAnnotationOptions(
          geometry: pt,
          image: _stopPinBytes[s.index]!,
          iconAnchor: mbx.IconAnchor.BOTTOM,
          iconSize: 1.0,
          textField: '${s.name} (${s.studentCount})',
          textSize: 10,
          textColor: 0xFFFFFFFF,
          textOffset: [0, 0.7],
        ));
        if (ann != null) _stopPins[s.index] = ann;
      }
    }
  }

  void _fitMobile(List<ll.LatLng> pts) {
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mbMap
        ?.cameraForCoordinateBounds(
          mbx.CoordinateBounds(
            southwest: mbx.Point(coordinates: mbx.Position(minLng, minLat)),
            northeast: mbx.Point(coordinates: mbx.Position(maxLng, maxLat)),
            infiniteBounds: false,
          ),
          mbx.MbxEdgeInsets(top: 140, left: 40, bottom: 200, right: 80),
          null,
          null,
          null,
          null,
        )
        .then((c) => _mbMap?.flyTo(c, mbx.MapAnimationOptions(duration: 1000)));
  }

  // ─── dart:ui marker builders ──────────────────────────────────────────────

  Future<Uint8List> _buildArrowBytes(double heading) async {
    const s = 64.0;
    final rec = ui.PictureRecorder();
    final cvs = Canvas(rec, const Rect.fromLTWH(0, 0, s, s));
    cvs.translate(s / 2, s / 2);
    cvs.rotate(heading * math.pi / 180);
    cvs.translate(-s / 2, -s / 2);
    // Glow
    cvs.drawCircle(
        const Offset(s / 2, s / 2),
        s / 2 - 1,
        Paint()
          ..color = AppTheme.primary.withValues(alpha: 0.3)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4));
    // Fill
    cvs.drawCircle(
        const Offset(s / 2, s / 2), s / 2 - 6, Paint()..color = AppTheme.primary);
    // Border
    cvs.drawCircle(
        const Offset(s / 2, s / 2),
        s / 2 - 6,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // Arrow chevron
    final path = ui.Path()
      ..moveTo(s / 2, s * 0.12)
      ..lineTo(s * 0.65, s * 0.58)
      ..lineTo(s / 2, s * 0.46)
      ..lineTo(s * 0.35, s * 0.58)
      ..close();
    cvs.drawPath(path, Paint()..color = Colors.white);
    final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<Uint8List> _buildStopPinBytes(
      int num, String name, int students, bool isLast) async {
    const w = 48.0, h = 60.0;
    final rec = ui.PictureRecorder();
    final cvs = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));
    final col = isLast ? const Color(0xFFFF5252) : Colors.orange;

    // Teardrop shadow
    cvs.drawPath(
        _teardrop(w, h),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3));
    // Teardrop fill
    cvs.drawPath(_teardrop(w, h), Paint()..color = col);
    // White circle inside
    cvs.drawCircle(const Offset(w / 2, w / 2 - 2), 14, Paint()..color = Colors.white);

    // Number or star
    final tp = TextPainter(
      text: TextSpan(
        text: isLast ? '★' : '$num',
        style: TextStyle(
            color: col,
            fontSize: isLast ? 15 : 13,
            fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(cvs, Offset(w / 2 - tp.width / 2, w / 2 - 2 - tp.height / 2));

    // Student count badge
    if (students > 0) {
      final badgePaint = Paint()..color = AppTheme.primary;
      cvs.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(w - 18, 0, 18, 14), const Radius.circular(7)),
        badgePaint,
      );
      final bp = TextPainter(
        text: TextSpan(
            text: '$students',
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      bp.paint(cvs, Offset(w - 18 + (18 - bp.width) / 2, (14 - bp.height) / 2));
    }

    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  ui.Path _teardrop(double w, double h) => ui.Path()
    ..moveTo(w / 2, h)
    ..cubicTo(2, h * .72, 2, h * .38, w / 2, 2)
    ..cubicTo(w - 2, h * .38, w - 2, h * .72, w / 2, h);

  // ─── Helpers ──────────────────────────────────────────────────────────────

  double _calcProgress(List<ll.LatLng> geom, ll.LatLng pos) {
    if (geom.length < 2) return 0;
    int best = 0;
    double minD = double.infinity;
    for (int i = 0; i < geom.length; i++) {
      final d = _sq(pos.latitude - geom[i].latitude) +
          _sq(pos.longitude - geom[i].longitude);
      if (d < minD) {
        minD = d;
        best = i;
      }
    }
    return best / (geom.length - 1);
  }

  int _nearestStep(List<_NavStep> steps, ll.LatLng pos) {
    if (steps.isEmpty) return 0;
    int best = 0;
    double minD = double.infinity;
    for (int i = 0; i < steps.length; i++) {
      final d = _sq(pos.latitude - steps[i].location.latitude) +
          _sq(pos.longitude - steps[i].location.longitude);
      if (d < minD) {
        minD = d;
        best = i;
      }
    }
    return best;
  }

  double _sq(double v) => v * v;

  List<_Seg> _congestionSegments(List<ll.LatLng> pts, List<double> cong) {
    if (cong.isEmpty) return [_Seg(pts, 0xFF4CAF50)];
    final segs = <_Seg>[];
    var bucket = <ll.LatLng>[pts[0]];
    int lastC = _ccolor(cong[0]);
    for (int i = 1; i < pts.length; i++) {
      final ci = _ccolor(cong[(i - 1).clamp(0, cong.length - 1)]);
      if (ci != lastC && bucket.length > 1) {
        bucket.add(pts[i]);
        segs.add(_Seg(List.from(bucket), lastC));
        bucket = [pts[i]];
        lastC = ci;
      } else {
        bucket.add(pts[i]);
      }
    }
    if (bucket.length > 1) segs.add(_Seg(bucket, lastC));
    return segs;
  }

  int _ccolor(double c) {
    if (c < 0.3) return 0xFF4CAF50;
    if (c < 0.6) return 0xFFFF9800;
    return 0xFFFF5252;
  }
}

class _Seg {
  final List<ll.LatLng> pts;
  final int argbColor;
  const _Seg(this.pts, this.argbColor);
}

// ─── Web stop pin ─────────────────────────────────────────────────────────────

class _WebStopPin extends StatelessWidget {
  final _BusStop stop;
  const _WebStopPin({required this.stop});

  @override
  Widget build(BuildContext context) {
    final col = stop.index == -1 ? Colors.red : Colors.orange;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: col,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: col.withValues(alpha: 0.5), blurRadius: 8)
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_on_rounded,
                color: Colors.white, size: 11),
            const SizedBox(width: 3),
            Text(stop.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        if (stop.studentCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  color: AppTheme.primary, shape: BoxShape.circle),
              child: Text('${stop.studentCount}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900)),
            ),
          ),
      ]),
      Container(width: 2, height: 6, color: col),
      Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
    ]);
  }
}

// ─── Navigation UI components ─────────────────────────────────────────────────

class _ManeuverCard extends StatelessWidget {
  final _NavStep? step;
  final bool loading;
  const _ManeuverCard({this.step, required this.loading});

  IconData get _icon {
    if (step == null) return Icons.straight_rounded;
    return switch (step!.modifier.toLowerCase()) {
      'left' => Icons.turn_left_rounded,
      'slight left' => Icons.turn_slight_left_rounded,
      'sharp left' => Icons.turn_sharp_left_rounded,
      'right' => Icons.turn_right_rounded,
      'slight right' => Icons.turn_slight_right_rounded,
      'sharp right' => Icons.turn_sharp_right_rounded,
      'uturn' => Icons.u_turn_left_rounded,
      _ => step!.type == 'arrive'
          ? Icons.location_on_rounded
          : Icons.straight_rounded,
    };
  }

  String get _dist {
    if (step == null) return '—';
    final m = step!.distanceM;
    return m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';
  }

  String _street(String instr) {
    final m =
        RegExp(r'onto (.+)$|on (.+)$', caseSensitive: false).firstMatch(instr);
    if (m != null) return m.group(1) ?? m.group(2) ?? instr;
    return instr
        .replaceFirst(
            RegExp(r'^(Turn left|Turn right|Continue straight|Head)\s+',
                caseSensitive: false),
            '')
        .split(' ')
        .take(4)
        .join(' ');
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 178,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A0F).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 4))
          ],
        ),
        child: loading
            ? const SizedBox(
                height: 60,
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: AppTheme.primary, strokeWidth: 2))))
            : step == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        const Icon(Icons.route_rounded,
                            color: AppTheme.primary, size: 28),
                        const SizedBox(height: 8),
                        Text('Start trip\nfor directions',
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                                height: 1.4)),
                      ])
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(10)),
                                child:
                                    Icon(_icon, color: Colors.white, size: 30),
                              ),
                              const SizedBox(width: 10),
                              Text(_dist,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5)),
                            ]),
                        const SizedBox(height: 8),
                        Text(_street(step!.instruction),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ]),
      );
}

class _SpeedBadge extends StatelessWidget {
  final double? speedKmh;
  const _SpeedBadge({this.speedKmh});

  @override
  Widget build(BuildContext context) {
    final speed = speedKmh?.toInt() ?? 0;
    final over = speed > _kSpeedLimitKmh;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Current speed
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: over ? const Color(0xFFCC2200) : AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: (over ? Colors.red : AppTheme.primary)
                    .withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$speed',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1)),
          const Text('km/h',
              style: TextStyle(
                  color: Colors.white70, fontSize: 9, letterSpacing: 0.3)),
        ]),
      ),
      const SizedBox(height: 6),
      // US-style speed limit sign
      Container(
        width: 52,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black87, width: 3),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('SPEED\nLIMIT',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  height: 1.15)),
          SizedBox(height: 1),
          Text('$_kSpeedLimitKmh',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1)),
        ]),
      ),
    ]);
  }
}

class _ProgressPanel extends StatelessWidget {
  final _RouteData? route;
  final double progress;
  final bool loading;
  const _ProgressPanel(
      {required this.route, required this.progress, required this.loading});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, bottom + 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(0, -4))
        ],
      ),
      child: loading
          ? const SizedBox(
              height: 48,
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: AppTheme.primary, strokeWidth: 2))))
          : route == null
              ? SizedBox(
                  height: 48,
                  child: Center(
                      child: Text('No route — start a trip',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13))))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  // Stats row
                  Row(children: [
                    _BotStat(
                        value:
                            '${route!.remainingKm(progress).toStringAsFixed(1)} km',
                        label: 'Remaining',
                        icon: Icons.route_rounded),
                    _vDiv(),
                    _BotStat(
                        value:
                            '${route!.durationTrafficMin ?? route!.durationMin} min',
                        label: 'Travel time',
                        icon: Icons.timer_rounded,
                        highlight: route!.durationTrafficMin != null &&
                            route!.durationTrafficMin! >
                                route!.durationMin + 5),
                    _vDiv(),
                    _BotStat(
                        value: route!.etaString,
                        label: 'Arrive',
                        icon: Icons.schedule_rounded),
                  ]),
                  const SizedBox(height: 12),

                  // Traffic progress bar
                  LayoutBuilder(builder: (_, box) {
                    final w = box.maxWidth;
                    final dotX =
                        (w * progress.clamp(0.0, 1.0)).clamp(6.0, w - 6.0);
                    return Stack(clipBehavior: Clip.none, children: [
                      // Gradient track
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 8,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF4CAF50),
                                Color(0xFF4CAF50),
                                Color(0xFFFF9800),
                                Color(0xFFFF5252)
                              ],
                              stops: [0, 0.45, 0.72, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Undriven mask
                      Align(
                        alignment: Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: (1.0 - progress).clamp(0.0, 1.0),
                          child: Container(
                              height: 8,
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                      ),
                      // Driver dot
                      Positioned(
                        left: dotX - 7,
                        top: -3,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppTheme.primary, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.6),
                                  blurRadius: 8)
                            ],
                          ),
                        ),
                      ),
                    ]);
                  }),
                  const SizedBox(height: 5),
                  Row(children: [
                    Text('0',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 10)),
                    const Spacer(),
                    Text('${route!.distanceKm.toStringAsFixed(1)} km',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 10)),
                  ]),
                ]),
    );
  }

  Widget _vDiv() => Container(
      width: 1,
      height: 34,
      color: Colors.white.withValues(alpha: 0.08),
      margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _BotStat extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final bool highlight;
  const _BotStat(
      {required this.value,
      required this.label,
      required this.icon,
      this.highlight = false});
  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(children: [
        Icon(icon,
            color: highlight ? Colors.orange : AppTheme.primary, size: 13),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                color: highlight ? Colors.orange : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ]));
}

class _StepList extends StatelessWidget {
  final List<_NavStep> steps;
  final int current;
  final void Function(int) onTap;
  final VoidCallback onClose;
  const _StepList(
      {required this.steps,
      required this.current,
      required this.onTap,
      required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A0F).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)
          ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(children: [
              const Icon(Icons.turn_right_rounded,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Turn-by-Turn',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.grey, size: 18)),
            ]),
          ),
          Expanded(
              child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: steps.length,
            itemBuilder: (_, i) {
              final sel = i == current;
              return GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppTheme.primary.withValues(alpha: 0.13)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: sel
                            ? AppTheme.primary.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: sel
                            ? AppTheme.primary
                            : Colors.white.withValues(alpha: 0.07),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  color: sel ? Colors.white : Colors.grey[500],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(steps[i].instruction,
                            style: TextStyle(
                                color: sel ? Colors.white : Colors.white54,
                                fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    Text(
                        steps[i].distanceM < 1000
                            ? '${steps[i].distanceM.round()} m'
                            : '${(steps[i].distanceM / 1000).toStringAsFixed(1)} km',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 10)),
                  ]),
                ),
              );
            },
          )),
        ]),
      );
}

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _MapBtn({required this.icon, required this.onTap, this.active = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.primary.withValues(alpha: 0.2)
                : const Color(0xFF0D1117).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active
                    ? AppTheme.primary.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Icon(icon,
              color: active ? AppTheme.primary : Colors.white70, size: 19),
        ),
      );
}
