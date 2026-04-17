import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart'                         as fm;
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart' as fmc;
import 'package:latlong2/latlong.dart'               as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import '../../../config/app_theme.dart';
import '../../../providers/fleet_provider.dart';

const _kTileUrl =
    'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}@2x'
    '?access_token=pk.eyJ1IjoiYnJvbGluY2UiLCJhIjoiY21ucWJiMHRyMDU5cDJ3cXB4ZzA5ZmI1ayJ9.Guvi2WbAjg9hMpfCC6amwQ';

/// AdminMap — compact live fleet map on DashboardPage.
/// Path: lib/screens/admin/widgets/admin_map.dart
class AdminMap extends ConsumerStatefulWidget {
  final VoidCallback? onExpand;
  const AdminMap({super.key, this.onExpand});

  @override
  ConsumerState<AdminMap> createState() => _AdminMapState();
}

class _AdminMapState extends ConsumerState<AdminMap> {
  mbx.PointAnnotationManager? _am;
  final _fmCtrl = fm.MapController();

  @override
  Widget build(BuildContext context) {
    final fleet  = ref.watch(fleetProvider).buses;
    final online = fleet.where((b) => b.isActive).length;

    if (!kIsWeb) {
      ref.listen(fleetProvider, (_, next) => _renderMobile(next.buses));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header ─────────────────────────────────────────────────────────
      Row(children: [
        const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 16),
        const SizedBox(width: 6),
        const Text('Live Fleet', style: TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: AppTheme.primary, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('$online online', style: const TextStyle(
                color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
        if (widget.onExpand != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onExpand,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Text('Full Map', style: TextStyle(
                  color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 10),

      // ── Map ─────────────────────────────────────────────────────────────
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 220,
          child: Stack(children: [
            if (kIsWeb)
              fm.FlutterMap(
                mapController: _fmCtrl,
                options: const fm.MapOptions(
                  initialCenter:   ll.LatLng(-1.2921, 36.8219),
                  initialZoom:     10,
                  backgroundColor: Color(0xFF0A0E0A),
                ),
                children: [
                  fm.TileLayer(
                tileProvider:          fmc.CancellableNetworkTileProvider(),
                urlTemplate:          _kTileUrl,
                retinaMode:           true,
                    userAgentPackageName: 'com.schooltrack.app',
                  ),
                  fm.MarkerLayer(
                    markers: fleet.where((b) => b.hasGps).map((bus) => fm.Marker(
                      point: ll.LatLng(bus.latitude, bus.longitude),
                      width: 40, height: 52,
                      child: _WebPin(bus: bus),
                    )).toList(),
                  ),
                ],
              )
            else
              mbx.MapWidget(
                key:           const ValueKey('admin_mini_map'),
                styleUri:      mbx.MapboxStyles.DARK,
                cameraOptions: mbx.CameraOptions(
                  center: mbx.Point(coordinates: mbx.Position(36.8219, -1.2921)),
                  zoom: 10, pitch: 20,
                ),
                onMapCreated: _onMobileReady,
              ),

            // Bottom fade
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(height: 40,
                decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent,
                    const Color(0xFF0A0E0A).withValues(alpha: 0.85)],
                )),
              ),
            ),

            // LIVE chip
            Positioned(top: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, color: AppTheme.primary, size: 7),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(color: AppTheme.primary,
                      fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  void _onMobileReady(mbx.MapboxMap map) async {
    _am    = await map.annotations.createPointAnnotationManager();
    await _renderMobile(ref.read(fleetProvider).buses);
  }

  Future<void> _renderMobile(List buses) async {
    if (_am == null) return;
    await _am!.deleteAll();
    for (final bus in buses) {
      if (!bus.hasGps) continue;
      await _am!.create(mbx.PointAnnotationOptions(
        geometry:   mbx.Point(coordinates: mbx.Position(bus.longitude, bus.latitude)),
        iconColor:  bus.isActive ? 0xFF4CAF50 : 0xFF555555,
        iconSize:   bus.isActive ? 1.2 : 0.9,
        textField:  bus.name,
        textSize:   10,
        textColor:  bus.isActive ? 0xFF4CAF50 : 0xFF888888,
        textOffset: [0, 1.6],
      ));
    }
  }
}

class _WebPin extends StatelessWidget {
  final dynamic bus;
  const _WebPin({required this.bus});
  @override
  Widget build(BuildContext context) {
    final c = (bus.isActive as bool) ? AppTheme.primary : Colors.grey;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle,
            boxShadow: (bus.isActive as bool)
                ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)] : []),
        child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 11)),
      Container(width: 2, height: 5, color: c),
      Container(width: 4, height: 4,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    ]);
  }
}