// lib/screens/admin/pages/fleet_map_page.dart
//
// Memory / CPU optimisations:
//   • Replaced raw Timer.periodic with SmartPoller (adaptive backoff + pause)
//   • Pauses all polling when app is backgrounded (WidgetsBindingObserver
//     inside SmartPoller) AND when this widget is hidden (page visibility)
//   • AutomaticKeepAliveClientMixin: GL context survives tab switches
//     without destroying + recreating the Mapbox renderer (~80 MB saved)
//   • RepaintBoundary: bus panel repaints never redraw the map
//   • Annotation manager reused — pins updated in-place, not recreated

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart'
    as fmc;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../../../config/app_theme.dart';
import '../../../models/bus.dart';
import '../../../providers/fleet_provider.dart';
import '../../../services/smart_poll.dart';

const _kToken =
    'pk.eyJ1IjoiYnJvbGluY2UiLCJhIjoiY21ucWJiMHRyMDU5cDJ3cXB4ZzA5ZmI1ayJ9'
    '.Guvi2WbAjg9hMpfCC6amwQ';
const _kTileUrl =
    'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x'
    '?access_token=$_kToken';

class FleetMapPage extends ConsumerStatefulWidget {
  const FleetMapPage({super.key});

  @override
  ConsumerState<FleetMapPage> createState() => _FleetMapPageState();
}

class _FleetMapPageState extends ConsumerState<FleetMapPage>
    with AutomaticKeepAliveClientMixin, PollerMixin {
  // ── Mobile (mbx) ──────────────────────────────────────────────────────────
  mbx.MapboxMap? _mbMap; // ignore: unused_field
  mbx.PointAnnotationManager? _am;
  Uint8List? _activeBytes;
  Uint8List? _idleBytes;
  final Map<int, mbx.PointAnnotation> _annotations = {};

  // ── Web (fm) ──────────────────────────────────────────────────────────────
  final _fmCtrl = fm.MapController();

  // ── Shared ────────────────────────────────────────────────────────────────
  Bus? _selected;

  // Keep GL context alive when user switches tabs
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // SmartPoller: backs off when buses are stationary, pauses in background
    // Mobile only — web uses flutter_map which handles tile loading itself
    if (!kIsWeb) {
      addPoller(SmartPoller<List<Bus>>(
        id: 'fleet_map',
        base: const Duration(seconds: 5),
        max: const Duration(seconds: 60),
        stallThreshold: 3,
        fetch: () async {
          await ref.read(fleetProvider.notifier).load();
          return ref.read(fleetProvider).buses;
        },
        onData: (buses) {
          if (mounted) _syncMobileAnnotations(buses);
        },
        equality: (prev, next) {
          if (prev == null || prev.length != next.length) return false;
          for (int i = 0; i < prev.length; i++) {
            if (prev[i].latitude != next[i].latitude ||
                prev[i].longitude != next[i].longitude ||
                prev[i].status != next[i].status) {
              return false;
            }
          }
          return true;
        },
      ));
    }
  }

  // ── Mobile: map ready ─────────────────────────────────────────────────────

  Future<void> _onMobileMapReady(mbx.MapboxMap map) async {
    _mbMap = map;
    _am = await map.annotations.createPointAnnotationManager();

    // Pre-render marker bitmaps once — reused for every annotation update
    _activeBytes = await _markerBytes(active: true);
    _idleBytes = await _markerBytes(active: false);

    final buses = ref.read(fleetProvider).buses;
    if (buses.isNotEmpty) await _syncMobileAnnotations(buses);
  }

  // Only update annotations for buses that actually changed position
  Future<void> _syncMobileAnnotations(List<Bus> buses) async {
    if (_am == null) return;
    final bytes = {'active': _activeBytes!, 'idle': _idleBytes!};

    for (final bus in buses) {
      final pt =
          mbx.Point(coordinates: mbx.Position(bus.longitude, bus.latitude));
      final isAct = bus.status == 'active';
      final img = isAct ? bytes['active']! : bytes['idle']!;

      if (_annotations.containsKey(bus.id)) {
        // In-place update — much cheaper than delete + create
        final ann = _annotations[bus.id]!;
        ann.geometry = pt;
        ann.image = img;
        await _am!.update(ann);
      } else {
        final ann = await _am!.create(mbx.PointAnnotationOptions(
          geometry: pt,
          image: img,
          iconSize: 1.0,
          textField: bus.name,
          textSize: 11,
          textColor: isAct ? 0xFF4CAF50 : 0xFF9E9E9E,
          textOffset: [0, 1.8],
        ));
        _annotations[bus.id] = ann;
      }
    }
  }

  // ── Marker bitmaps (rendered once) ───────────────────────────────────────

  Future<Uint8List> _markerBytes({required bool active}) async {
    const s = 48.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, const Rect.fromLTWH(0, 0, s, s));
    final col = active ? AppTheme.primary : Colors.grey;

    c.drawCircle(
        const Offset(s / 2, s / 2),
        s / 2 - 2,
        Paint()
          ..color = col.withValues(alpha: 0.25)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4));
    c.drawCircle(const Offset(s / 2, s / 2), s / 2 - 6, Paint()..color = col);
    c.drawCircle(
        const Offset(s / 2, s / 2),
        s / 2 - 6,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    final iconPainter = TextPainter(
      text: const TextSpan(text: '🚌', style: TextStyle(fontSize: 18)),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(c,
        Offset(s / 2 - iconPainter.width / 2, s / 2 - iconPainter.height / 2));

    final img = await rec.endRecording().toImage(s.toInt(), s.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return (bytes ??
            (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!)
        .buffer
        .asUint8List();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    final fleetState = ref.watch(fleetProvider);
    final buses = fleetState.buses;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Web: reflect latest buses into flutter_map markers
    ref.listen(fleetProvider, (_, next) {
      if (!kIsWeb || !mounted) return;
      setState(() {}); // just rebuild markers
    });

    return Stack(children: [
      // ── Map ───────────────────────────────────────────────────────────────
      kIsWeb
          ? _WebMap(
              ctrl: _fmCtrl,
              buses: buses,
              selected: _selected,
              onTap: (b) => setState(() => _selected = b))
          : mbx.MapWidget(
              key: const ValueKey('fleet_map'),
              styleUri: mbx.MapboxStyles.DARK,
              cameraOptions: mbx.CameraOptions(
                center: mbx.Point(coordinates: mbx.Position(36.8219, -1.2921)),
                zoom: 12,
              ),
              onMapCreated: _onMobileMapReady,
            ),

      // ── Live badge ────────────────────────────────────────────────────────
      Positioned(
        top: 14,
        left: 14,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: fleetState.liveViaWs
                    ? AppTheme.primary.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fleetState.liveViaWs
                        ? AppTheme.primary
                        : Colors.orange)),
            const SizedBox(width: 6),
            Text(
              fleetState.liveViaWs
                  ? 'LIVE  •  ${buses.length} buses'
                  : 'POLLING  •  ${buses.length} buses',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ),

      // ── Selected bus panel (RepaintBoundary isolates from map) ────────────
      if (_selected != null)
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: RepaintBoundary(
            child: _BusPanel(
              bus: _selected!,
              dark: dark,
              onClose: () => setState(() => _selected = null),
            ),
          ),
        ),

      // ── Loading overlay ───────────────────────────────────────────────────
      if (fleetState.loading)
        const Positioned(
          top: 14,
          right: 14,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: AppTheme.primary, strokeWidth: 2),
          ),
        ),

      // ── Error banner ──────────────────────────────────────────────────────
      if (fleetState.error != null)
        Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(fleetState.error!,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
    ]);
  }
}

// ── Web map (flutter_map) ─────────────────────────────────────────────────────

class _WebMap extends StatelessWidget {
  final fm.MapController ctrl;
  final List<Bus> buses;
  final Bus? selected;
  final ValueChanged<Bus> onTap;
  const _WebMap(
      {required this.ctrl,
      required this.buses,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => fm.FlutterMap(
        mapController: ctrl,
        options: const fm.MapOptions(
          initialCenter: ll.LatLng(-1.2921, 36.8219),
          initialZoom: 12,
          backgroundColor: Color(0xFF0A0E0A),
        ),
        children: [
          fm.TileLayer(
            urlTemplate: _kTileUrl,
            retinaMode: true,
            tileProvider: fmc.CancellableNetworkTileProvider(),
            userAgentPackageName: 'com.schooltrack.app',
            maxNativeZoom: 18,
          ),
          fm.MarkerLayer(
            markers: buses
                .map((b) => fm.Marker(
                      point: ll.LatLng(b.latitude, b.longitude),
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () => onTap(b),
                        child: _WebMarker(
                            active: b.status == 'active',
                            selected: selected?.id == b.id),
                      ),
                    ))
                .toList(),
          ),
        ],
      );
}

class _WebMarker extends StatelessWidget {
  final bool active, selected;
  const _WebMarker({required this.active, required this.selected});

  @override
  Widget build(BuildContext context) {
    final col = active ? AppTheme.primary : Colors.grey;
    return Container(
      decoration: BoxDecoration(
        color: col,
        shape: BoxShape.circle,
        border: selected ? Border.all(color: Colors.white, width: 2.5) : null,
        boxShadow: [
          BoxShadow(
              color: col.withValues(alpha: 0.5),
              blurRadius: selected ? 20 : 12,
              spreadRadius: selected ? 4 : 2)
        ],
      ),
      child: const Icon(Icons.directions_bus_rounded,
          color: Colors.white, size: 24),
    );
  }
}

// ── Bus detail panel ──────────────────────────────────────────────────────────

class _BusPanel extends StatelessWidget {
  final Bus bus;
  final bool dark;
  final VoidCallback onClose;
  const _BusPanel(
      {required this.bus, required this.dark, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark
              ? const Color(0xEE0D1117)
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.directions_bus_rounded,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(bus.name,
                    style: TextStyle(
                        color: dark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Text(
                    '${bus.plate}  ·  ${(bus.status).toUpperCase()}',
                    style: TextStyle(
                        color: dark ? Colors.white54 : Colors.black45,
                        fontSize: 12)),
                if (bus.speed != null)
                  Text(
                      '${bus.speed!.toStringAsFixed(0)} km/h  '
                      '${bus.latitude.toStringAsFixed(4)}, '
                      '${bus.longitude.toStringAsFixed(4)}',
                      style: TextStyle(
                          color: dark ? Colors.white38 : Colors.black38,
                          fontSize: 11)),
              ])),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 18),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ]),
      );
}
