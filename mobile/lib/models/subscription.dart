import 'plan.dart';

/// Mirrors the Laravel SubscriptionController `status()` response:
/// {
///   "is_active": bool,
///   "details": { Subscription + eager-loaded plan },
///   "bus_count": int
/// }
class SubscriptionDetails {
  final bool isActive;
  final String? status;   // active | expired | null
  final int? planId;
  final String planName;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final int busCount;

  // Eagerly-loaded plan relationship (present when subscription exists)
  final Plan? plan;

  const SubscriptionDetails({
    required this.isActive,
    this.status,
    this.planId,
    this.planName = 'No Active Plan',
    this.startsAt,
    this.expiresAt,
    required this.busCount,
    this.plan,
  });

  factory SubscriptionDetails.fromJson(Map<String, dynamic> json) {
    final details = json['details'] as Map<String, dynamic>?;
    final planJson = details?['plan'] as Map<String, dynamic>?;

    // Parse the nested plan if present
    final Plan? plan = planJson != null ? Plan.fromJson(planJson) : null;

    return SubscriptionDetails(
      isActive:  json['is_active'] as bool? ?? false,
      status:    details?['status']  as String?,
      planId:    details?['plan_id'] as int?,
      planName:  plan?.name ?? 'No Active Plan',
      startsAt:  details?['starts_at'] != null
          ? DateTime.tryParse(details!['starts_at'] as String)
          : null,
      expiresAt: details?['expires_at'] != null
          ? DateTime.tryParse(details!['expires_at'] as String)
          : null,
      busCount: json['bus_count'] as int? ?? 0,
      plan:     plan,
    );
  }

  /// Formatted expiry string shown in the UI card.
  String get expiryLabel {
    if (expiresAt == null) return 'No active plan';
    final d = expiresAt!.toLocal();
    return 'Expires ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// True when subscription is within 7 days of expiry.
  bool get isExpiringSoon {
    if (expiresAt == null) return false;
    return expiresAt!.difference(DateTime.now()).inDays <= 7;
  }
}