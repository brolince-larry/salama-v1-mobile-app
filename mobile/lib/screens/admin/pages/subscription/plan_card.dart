import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../models/plan.dart';

/// Premium plan card — dark card, price hero, feature bullets, CTA button.
/// Featured (centre) card has green glow and filled button.
/// Path: lib/screens/admin/pages/subscription/plan_card.dart
class PlanCard extends StatelessWidget {
  final Plan         plan;
  final bool         isSelected;
  final bool         isFeatured;
  final String       priceLabel;
  final VoidCallback onSelect;

  const PlanCard({
    super.key,
    required this.plan,
    required this.isSelected,
    required this.isFeatured,
    required this.priceLabel,
    required this.onSelect,
  });

  String _fmt(int v) =>
      v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  List<String> get _features => [
    'KES ${_fmt(plan.busPrice)} per bus / month',
    if (plan.minibusPrice > 0) 'KES ${_fmt(plan.minibusPrice)} per minibus',
    if (plan.vanPrice > 0)     'KES ${_fmt(plan.vanPrice)} per van',
    if (plan.studentPrice > 0) 'KES ${_fmt(plan.studentPrice)} per student',
    '${plan.durationLabel} billing period',
    if (plan.discountPercent > 0) '${plan.discountPercent}% multi-period discount',
    'Real-time GPS tracking',
    'Parent push notifications',
    'SOS emergency alerts',
    'Driver trip control',
  ];

  String get _tagline => switch (plan.durationType) {
    'trial'   => 'Test the platform risk-free',
    'monthly' => 'Flexible month-to-month',
    'termly'  => 'Ideal for school terms',
    'yearly'  => 'Best value, full year',
    _         => 'SchoolTrack fleet plan',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.symmetric(vertical: isFeatured ? 0 : 10),
        decoration: BoxDecoration(
          color: isFeatured ? const Color(0xFF192419) : const Color(0xFF111811),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : isFeatured
                    ? AppTheme.primary.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.07),
            width: isSelected || isFeatured ? 1.5 : 1,
          ),
          boxShadow: isFeatured
              ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.22),
                  blurRadius: 36, offset: const Offset(0, 14))]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Name + badge row ────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Text(plan.name, style: TextStyle(
                      color:      isFeatured ? Colors.white : Colors.white70,
                      fontSize:   18,
                      fontWeight: FontWeight.w700)),
                ),
                if (isFeatured)
                  const _Pill('POPULAR', AppTheme.primary, filled: true)
                else if (plan.discountPercent > 0)
                  _Pill(plan.discountLabel, Colors.green),
              ]),
              const SizedBox(height: 4),

              // ── Tagline ─────────────────────────────────────────────────
              Text(_tagline, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 20),

              // ── Price hero ──────────────────────────────────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Flexible(
                  child: Text(priceLabel, style: TextStyle(
                      color:      isFeatured ? AppTheme.primary : Colors.white,
                      fontSize:   isFeatured ? 34 : 26,
                      fontWeight: FontWeight.w900,
                      height:     1.0)),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('/ ${plan.durationLabel}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 22),

              // ── CTA button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: isFeatured
                    ? FilledButton(
                        onPressed: onSelect,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isSelected ? 'SELECTED ✓' : 'START NOW',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      )
                    : OutlinedButton(
                        onPressed: onSelect,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                              color: isSelected
                                  ? AppTheme.primary
                                  : Colors.white.withValues(alpha: 0.18)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isSelected ? 'SELECTED ✓' : 'SELECT PLAN',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                      ),
              ),
              const SizedBox(height: 22),

              // ── Feature header ──────────────────────────────────────────
              Text('Plan includes:',
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
              const SizedBox(height: 12),

              // ── Feature list ────────────────────────────────────────────
              ..._features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 15,
                            color: isFeatured
                                ? AppTheme.primary
                                : Colors.green.withValues(alpha: 0.65)),
                        const SizedBox(width: 9),
                        Expanded(child: Text(f,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12))),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color  color;
  final bool   filled;
  const _Pill(this.text, this.color, {this.filled = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color:        filled ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border:       Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(text, style: TextStyle(
        color:        color,
        fontSize:     10,
        fontWeight:   FontWeight.w900,
        letterSpacing: 0.6)),
  );
}