import 'package:flutter/foundation.dart';

/// Plan model — mirrors the `plans` DB table exactly.
///
/// [discountLabel] is a computed accessor on the Laravel side.
/// If it is absent from the response, it is built locally from [discountPercent].
class Plan {
  final int id;
  final String name;
  final String durationType; // monthly | termly | yearly | trial

  // Unit prices (KES, admin-editable)
  final int busPrice;
  final int minibusPrice;
  final int vanPrice;
  final int studentPrice;

  // Duration & discount
  final int durationMonths;
  final int discountPercent;
  final String discountLabel; // e.g. "10% off"

  final bool isActive;
  final DateTime? updatedAt;

  const Plan({
    required this.id,
    required this.name,
    required this.durationType,
    required this.busPrice,
    required this.minibusPrice,
    required this.vanPrice,
    required this.studentPrice,
    required this.durationMonths,
    required this.discountPercent,
    required this.discountLabel,
    required this.isActive,
    this.updatedAt,
  });

  // ── Safe integer coercion ─────────────────────────────────────────────────
  // Laravel JSON can return integers as int or double depending on the DB driver.
  // Using `as int` directly throws TypeError on double values like 5000.0.
  static int _parseInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  factory Plan.fromJson(Map<String, dynamic> json) {
    // Print raw JSON in debug mode — reveals exactly which field is null/wrong type
    debugPrint('[Plan.fromJson] $json');

    final discountPercent = _parseInt(json['discount_percent']);

    // discount_label is a computed accessor — may be absent from the API response.
    // Build it locally if missing so the UI never shows an empty badge.
    final String discountLabel = () {
      final raw = json['discount_label'];
      if (raw is String && raw.isNotEmpty) return raw;
      return discountPercent > 0 ? '$discountPercent% off' : '';
    }();

    return Plan(
      id:              _parseInt(json['id']),
      name:            (json['name']          as String?) ?? 'Unknown Plan',
      durationType:    (json['duration_type'] as String?) ?? 'monthly',
      busPrice:        _parseInt(json['bus_price']),
      minibusPrice:    _parseInt(json['minibus_price']),
      vanPrice:        _parseInt(json['van_price']),
      studentPrice:    _parseInt(json['student_price']),
      durationMonths:  _parseInt(json['duration_months'], 1),
      discountPercent: discountPercent,
      discountLabel:   discountLabel,
      // is_active can arrive as bool (true/false) or int (1/0) depending on DB driver
      isActive:  json['is_active'] == true || json['is_active'] == 1,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  /// Human-readable duration, e.g. "3 months".
  String get durationLabel =>
      durationMonths == 1 ? '1 month' : '$durationMonths months';
}

// ─────────────────────────────────────────────────────────────────────────────

/// Lightweight price preview returned by GET /plans/preview.
class PlanPreview {
  final String durationType;
  final int priceKes;
  final String formatted; // e.g. "KES 15,000"

  const PlanPreview({
    required this.durationType,
    required this.priceKes,
    required this.formatted,
  });

  factory PlanPreview.fromJson(Map<String, dynamic> json) {
    debugPrint('[PlanPreview.fromJson] $json');
    return PlanPreview(
      durationType: (json['duration_type'] as String?) ?? '',
      priceKes:     Plan._parseInt(json['price_kes']),
      formatted:    (json['formatted']     as String?) ?? '',
    );
  }
}