import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/extensions.dart';
import '../../../core/widgets.dart';
import '../../../services/api_service.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({super.key});

  @override
  State<RoutesPage> createState() => _State();
}

class _State extends State<RoutesPage> {
  List<Map<String, dynamic>> _routes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.get('/routes');
      setState(() {
        _routes = List<Map<String, dynamic>>.from(
            data['data'] as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load routes'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Text('Routes',
              style: TextStyle(
                  color: context.txt,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          OrangeButton(label: 'Add Route', icon: Icons.add,
              onTap: () {}),
        ]),
        const SizedBox(height: 16),

        if (_loading)
          Column(children: List.generate(3,
              (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: AppShimmer(height: 90))))
        else if (_error != null)
          ErrorState(message: _error!, onRetry: _load)
        else if (_routes.isEmpty)
          const EmptyState(
              icon: Icons.route_outlined,
              message: 'No routes yet.')
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _routes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _RouteItem(route: _routes[i]),
          ),
      ]),
    );
  }
}

class _RouteItem extends StatelessWidget {
  final Map<String, dynamic> route;
  const _RouteItem({required this.route});

  @override
  Widget build(BuildContext context) {
    final dir = route['direction'] ?? 'inbound';
    final color =
        dir == 'inbound' ? AppTheme.info : AppTheme.success;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.route_rounded, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text(route['name'] ?? '',
              style: TextStyle(
                  color: context.txt,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.access_time,
                color: context.hint, size: 12),
            const SizedBox(width: 4),
            Text(route['departure_time'] ?? '',
                style: TextStyle(
                    color: context.muted, fontSize: 11)),
          ]),
        ])),
        StatusBadge(label: dir, color: color),
      ]),
    );
  }
}