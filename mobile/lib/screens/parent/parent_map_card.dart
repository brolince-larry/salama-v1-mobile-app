// lib/screens/parent/parent_map_card.dart
//
// Real-time bus tracking card for parents.
//   • SmartPoller: backs off when bus is stationary, resets when it moves
//   • Tries Reverb WebSocket server-push first (BusLocationUpdated event)
//   • Shows live bus position on map with animated pulsing ring
//   • Shows the route line from bus current position to child's stop
//   • ETA countdown badge
//   • LIVE / OFFLINE status dot
//   • Pauses when app is backgrounded (WidgetsBindingObserver inside SmartPoller)
//   • No ref.keepAlive() — provider GC'd when card leaves tree

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart'
    as fmc;
import '../../config/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/smart_poll.dart';
import '../../config/api_config.dart';

const _kTileUrl =
    'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x'
    '?access_token=pk.eyJ1IjoiYnJvbGluY2UiLCJhIjoiY21ucWJiMHRyMDU5cDJ3cXB4ZzA5ZmI1ayJ9'
    '.Guvi2WbAjg9hMpfCC6amwQ';

// ─── Location equality (drives SmartPoller backoff) ───────────────────────────

class _BusLoc {
  final double lat, lng, speed;
  const _BusLoc(this.lat, this.lng, this.speed);
  @override
  bool operator ==(Object o) =>
      o is _BusLoc && o.lat == lat && o.lng == lng && o.speed == speed;
  @override
  int get hashCode => Object.hash(lat, lng, speed);
}

// ─── Widget ───────────────────────────────────────────────────────────────────

class ParentMapCard extends ConsumerStatefulWidget {
  final int studentId;
  final String studentName;
  const ParentMapCard(
      {super.key, required this.studentId, required this.studentName});

  @override
  ConsumerState<ParentMapCard> createState() => _ParentMapCardState();
}

class _ParentMapCardState extends ConsumerState<ParentMapCard>
    with PollerMixin, SingleTickerProviderStateMixin {
  // Mobile
  mbx.MapboxMap? _mbMap;
  mbx.PointAnnotationManager? _am;
  mbx.PointAnnotation? _busPin;

  // Web
  final _fmCtrl = fm.MapController();
  ll.LatLng? _busLL;

  // State
  bool _isLive = false;
  String _busName = 'Bus';
  String? _etaLabel;
  double? _speedKmh;
  String _status = 'no_trip'; // active | completed | no_trip
  ll.LatLng? _childStopLL; // child's pickup/dropoff stop

  // Pulse animation for live dot
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_pulseCtrl);

    // SmartPoller: 10 s base, back off to 80 s when bus is stationary
    addPoller(SmartPoller<Map<String, dynamic>?>(
      id: 'parent_bus_${widget.studentId}',
      base: const Duration(seconds: 10),
      max: const Duration(seconds: 80),
      stallThreshold: 3,
      fetch: () async {
        final data =
            await ApiService.get(ApiConfig.parentBusLocation(widget.studentId));
        return data is Map ? Map<String, dynamic>.from(data) : null;
      },
      onData: _applyData,
      equality: (prev, next) {
        final p = _extractLoc(prev);
        final n = _extractLoc(next);
        if (p == null && n == null) return true;
        if (p == null || n == null) return false;
        return p == n;
      },
    ));

    // Also watch trip status for ETA
    addPoller(SmartPoller<Map<String, dynamic>?>(
      id: 'parent_trip_${widget.studentId}',
      base: const Duration(seconds: 20),
      max: const Duration(seconds: 120),
      stallThreshold: 2,
      fetch: () async {
        final data =
            await ApiService.get(ApiConfig.parentTripStatus(widget.studentId));
        return data is Map ? Map<String, dynamic>.from(data) : null;
      },
      onData: _applyTripStatus,
    ));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose(); // PollerMixin disposes all pollers
  }

  // ─── Data handlers ────────────────────────────────────────────────────────

  _BusLoc? _extractLoc(Map<String, dynamic>? data) {
    final loc = data?['location'] as Map?;
    if (loc == null) return null;
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    final spd = (loc['speed'] as num?)?.toDouble() ?? 0;
    if (lat == null || lng == null) return null;
    return _BusLoc(lat, lng, spd);
  }

  void _applyData(Map<String, dynamic>? data) {
    if (!mounted || data == null) return;

    final loc = data['location'] as Map?;
    final lat = (loc?['lat'] as num?)?.toDouble();
    final lng = (loc?['lng'] as num?)?.toDouble();
    final spd = (loc?['speed'] as num?)?.toDouble();

    setState(() {
      _isLive = lat != null;
      _busName = data['bus']?['name'] as String? ?? 'Bus';
      _speedKmh = spd;
    });

    if (lat == null || lng == null) return;
    final pos = ll.LatLng(lat, lng);

    if (kIsWeb) {
      setState(() => _busLL = pos);
      try {
        _fmCtrl.move(pos, 15);
      } catch (_) {}
    } else {
      _moveMobilePin(pos);
    }

    // Extract child's stop location if provided
    final stop = data['child_stop'] as Map?;
    if (stop != null) {
      final sLat = (stop['lat'] as num?)?.toDouble();
      final sLng = (stop['lng'] as num?)?.toDouble();
      if (sLat != null && sLng != null) {
        setState(() => _childStopLL = ll.LatLng(sLat, sLng));
      }
    }
  }

  void _applyTripStatus(Map<String, dynamic>? data) {
    if (!mounted || data == null) return;
    setState(() {
      _status = data['status'] as String? ?? 'no_trip';
      _etaLabel = data['eta'] as String?;
    });
  }

  // ─── Mobile pin ───────────────────────────────────────────────────────────

  Future<void> _onMobileReady(mbx.MapboxMap map) async {
    _mbMap = map;
    _am = await map.annotations.createPointAnnotationManager();
    if (_busLL != null) _moveMobilePin(_busLL!);
  }

  Future<void> _moveMobilePin(ll.LatLng pos) async {
    if (_am == null) return;
    final pt =
        mbx.Point(coordinates: mbx.Position(pos.longitude, pos.latitude));
    if (_busPin == null) {
      _busPin = await _am!.create(mbx.PointAnnotationOptions(
        geometry: pt,
        iconColor: 0xFF4CAF50,
        iconSize: 1.4,
        textField: _busName,
        textSize: 11,
        textColor: 0xFF4CAF50,
        textOffset: [0, 1.8],
      ));
      _mbMap?.flyTo(
        mbx.CameraOptions(center: pt, zoom: 15, pitch: 30),
        mbx.MapAnimationOptions(duration: 1000, startDelay: 0),
      );
    } else {
      _busPin!.geometry = pt;
      _busPin!.textField = _busName;
      await _am!.update(_busPin!);
      _mbMap?.easeTo(
        mbx.CameraOptions(center: pt),
        mbx.MapAnimationOptions(duration: 700, startDelay: 0),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            const Icon(Icons.map_rounded, color: AppTheme.primary, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Tracking • ${widget.studentName}',
                    style: TextStyle(
                        color: dark ? Colors.white : Colors.black87,
                        fontSize: 13,
                        fontWeight: FontWeight.w700))),

            // Live / Offline dot
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: _isLive ? _pulseAnim.value : 1.0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_isLive ? AppTheme.success : Colors.grey)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isLive ? AppTheme.success : Colors.grey)),
                    const SizedBox(width: 5),
                    Text(_isLive ? 'LIVE' : 'OFFLINE',
                        style: TextStyle(
                            color: _isLive ? AppTheme.success : Colors.grey,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Manual refresh
            GestureDetector(
              onTap: () {
                for (final p in pollers) {
                  p.resume();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.refresh_rounded,
                    color: AppTheme.primary, size: 14),
              ),
            ),
          ]),
        ),

        // ── Status + ETA strip ────────────────────────────────────────────
        if (_isLive) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              // Trip status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(_status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                        color: _statusColor(_status),
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              // Speed
              if (_speedKmh != null) ...[
                const Icon(Icons.speed_rounded, size: 12, color: Colors.grey),
                const SizedBox(width: 3),
                Text('${_speedKmh!.toStringAsFixed(0)} km/h',
                    style: TextStyle(
                        color: dark ? Colors.white54 : Colors.black45,
                        fontSize: 11)),
                const SizedBox(width: 8),
              ],
              // ETA
              if (_etaLabel != null) ...[
                const Icon(Icons.schedule_rounded,
                    size: 12, color: AppTheme.primary),
                const SizedBox(width: 3),
                Text('ETA $_etaLabel',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ]),
          ),
        ],
        const SizedBox(height: 10),

        // ── Map ───────────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18)),
          child: SizedBox(
            height: 210,
            child: kIsWeb ? _buildWebMap() : _buildMobileMap(),
          ),
        ),
      ]),
    );
  }

  Widget _buildMobileMap() => mbx.MapWidget(
        key: ValueKey('pmap_${widget.studentId}'),
        styleUri: mbx.MapboxStyles.DARK,
        cameraOptions: mbx.CameraOptions(
          center: mbx.Point(coordinates: mbx.Position(36.8219, -1.2921)),
          zoom: 13,
        ),
        onMapCreated: _onMobileReady,
      );

  Widget _buildWebMap() => fm.FlutterMap(
        mapController: _fmCtrl,
        options: fm.MapOptions(
          initialCenter: _busLL ?? const ll.LatLng(-1.2921, 36.8219),
          initialZoom: 14,
          backgroundColor: const Color(0xFF0A0E0A),
        ),
        children: [
          fm.TileLayer(
            urlTemplate: _kTileUrl,
            retinaMode: true,
            tileProvider: fmc.CancellableNetworkTileProvider(),
            userAgentPackageName: 'com.schooltrack.app',
            maxNativeZoom: 18,
          ),

          // Route line: bus → child's stop
          if (_busLL != null && _childStopLL != null)
            fm.PolylineLayer(polylines: [
              fm.Polyline(
                points: [_busLL!, _childStopLL!],
                color: AppTheme.primary.withValues(alpha: 0.7),
                strokeWidth: 4,
              ),
            ]),

          fm.MarkerLayer(markers: [
            // Bus marker (live pulsing)
            if (_busLL != null)
              fm.Marker(
                point: _busLL!,
                width: 56,
                height: 56,
                alignment: Alignment.center,
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) =>
                      Stack(alignment: Alignment.center, children: [
                    // Pulse ring
                    if (_isLive)
                      Container(
                        width: 56 * _pulseAnim.value,
                        height: 56 * _pulseAnim.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.success.withValues(
                                  alpha: 1.0 - _pulseAnim.value * 0.7),
                              width: 2),
                        ),
                      ),
                    // Bus icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _isLive ? AppTheme.success : Colors.grey,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: (_isLive ? AppTheme.success : Colors.grey)
                                  .withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 2)
                        ],
                      ),
                      child: const Icon(Icons.directions_bus_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ]),
                ),
              ),

            // Child's stop marker
            if (_childStopLL != null)
              fm.Marker(
                point: _childStopLL!,
                width: 36,
                height: 48,
                alignment: Alignment.bottomCenter,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: AppTheme.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.person_pin_rounded,
                        color: Colors.white, size: 14),
                  ),
                  Container(width: 2, height: 8, color: AppTheme.primary),
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: AppTheme.primary, shape: BoxShape.circle)),
                ]),
              ),
          ]),
        ],
      );

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return AppTheme.success;
      case 'completed':
        return AppTheme.primary;
      default:
        return Colors.grey;
    }
  }
}
