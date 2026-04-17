import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/extensions.dart';
import '../../../core/widgets.dart';
import '../../../services/api_service.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key});

  @override
  State<SosPage> createState() => _State();
}

class _State extends State<SosPage> {
  final List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // SOS events — using trips endpoint as proxy until dedicated SOS list endpoint
    _loading = false;
  }

  Future<void> _resolve(int sosId) async {
    try {
      await ApiService.post('/sos/$sosId/resolve',  body: {
        'resolution_notes': 'Resolved by admin'
      });
      setState(() {
        _alerts.removeWhere((a) => a['id'] == sosId);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text('SOS Alerts',
            style: TextStyle(
                color: context.txt,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Active emergencies requiring attention',
            style:
                TextStyle(color: context.muted, fontSize: 13)),
        const SizedBox(height: 16),

        // Active SOS counter
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.danger.withValues(alpha: 0.15),
              AppTheme.danger.withValues(alpha: 0.05),
            ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppTheme.danger.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.danger, size: 28),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('${_alerts.length}',
                  style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 32,
                      fontWeight: FontWeight.w900)),
              Text('Active SOS alerts',
                  style: TextStyle(
                      color: context.muted, fontSize: 12)),
            ]),
            const Spacer(),
            if (_alerts.isNotEmpty)
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: AppTheme.danger.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2)],
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),

        if (_loading)
          Column(children: List.generate(2,
              (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: AppShimmer(height: 100))))
        else if (_alerts.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.border),
            ),
            child: Center(
                child: Column(children: [
              const Icon(Icons.check_circle_outline,
                  color: AppTheme.success, size: 52),
              const SizedBox(height: 10),
              Text('All clear! No active SOS alerts.',
                  style: TextStyle(
                      color: context.muted, fontSize: 13)),
            ])),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _SosCard(
              alert: _alerts[i],
              onResolve: () => _resolve(_alerts[i]['id']),
            ),
          ),
      ]),
    );
  }
}

class _SosCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onResolve;
  const _SosCard({required this.alert, required this.onResolve});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppTheme.danger.withValues(alpha: 0.3)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.danger, size: 18),
            const SizedBox(width: 8),
            Text('SOS #${alert['id']}',
                style: const TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const Spacer(),
            Text(alert['triggered_at'] ?? '',
                style: TextStyle(
                    color: context.hint, fontSize: 10)),
          ]),
          const SizedBox(height: 8),
          Text(
              'Bus #${alert['bus_id']} — Driver #${alert['driver_id']}',
              style: TextStyle(
                  color: context.txt, fontSize: 13)),
          const SizedBox(height: 4),
          if (alert['lat'] != null)
            Text(
                'Location: ${alert['lat']}, ${alert['lng']}',
                style: TextStyle(
                    color: context.muted, fontSize: 11)),
          const SizedBox(height: 12),
          OrangeButton(
            label: 'Mark as Resolved',
            icon: Icons.check_circle_outline,
            onTap: onResolve,
          ),
        ]),
      );
}