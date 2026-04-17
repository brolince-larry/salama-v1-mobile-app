import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/plan.dart';
import '../models/subscription.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Current school's subscription status.
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>(
  (ref) => SubscriptionNotifier(),
);

/// Available plans:
///   school_admin → fetchActivePlans() → GET /plans       (active only)
///   super_admin  → fetchAllPlans()    → GET /super/plans  (all)
final plansProvider =
    StateNotifierProvider<PlansNotifier, PlansState>(
  (ref) => PlansNotifier(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Response helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Safely extract a List from either shape:
///   { "data": [...] }   ← Laravel Resource Collection wrapper
///   [...]               ← bare array
///
/// Critically: detects HTTP error bodies like { "message": "Unauthorized" }
/// BEFORE attempting to extract data, so the real error surfaces instead of
/// a confusing FormatException about response shape.
List<dynamic> _extractList(dynamic res) {
  // ── Detect Laravel error response bodies ─────────────────────────────────
  // 401 Unauthorized  → { "message": "Unauthenticated." }
  // 403 Forbidden     → { "message": "Unauthorized." }
  // 422 Validation    → { "message": "...", "errors": {...} }
  if (res is Map<String, dynamic>) {
    final msg = res['message'];
    // A real data response never has 'message' as its only key at the root.
    // If 'data' is absent and 'message' is present, it's an error body.
    if (msg != null && !res.containsKey('data')) {
      throw Exception('Server error: $msg');
    }
    final data = res['data'];
    if (data is List) return data;
  }
  if (res is List) return res;

  throw FormatException(
    '[PlansProvider] Unexpected response shape: ${res.runtimeType} — $res',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Subscription State & Notifier
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionState {
  final bool isLoading;
  final SubscriptionDetails? details;
  final String? error;

  const SubscriptionState({
    this.isLoading = false,
    this.details,
    this.error,
  });

  SubscriptionState copyWith({
    bool? isLoading,
    SubscriptionDetails? details,
    String? error,
  }) =>
      SubscriptionState(
        isLoading: isLoading ?? this.isLoading,
        details:   details   ?? this.details,
        error:     error,
      );
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(const SubscriptionState());

  Future<void> fetchStatus(int schoolId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiService.get('/subscription/status/$schoolId');
      debugPrint('[SubscriptionNotifier.fetchStatus] $res');
      state = state.copyWith(
        isLoading: false,
        details: SubscriptionDetails.fromJson(res as Map<String, dynamic>),
      );
    } catch (e, stack) {
      debugPrint('[SubscriptionNotifier.fetchStatus] ERROR: $e\n$stack');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>> initiatePayment({
    required String durationType,
    required String gateway,
    String? phone,
  }) async {
    final res = await ApiService.post(
      '/subscription/pay',
      body: {
        'duration_type': durationType,
        'gateway':       gateway,
        if (phone != null) 'phone': phone,
      },
    );
    return res as Map<String, dynamic>;
  }

  Future<bool> checkPaymentStatus(String reference) async {
    final res = await ApiService.get('/subscription/check/$reference');
    return (res as Map<String, dynamic>)['is_active'] as bool? ?? false;
  }

  Future<bool> pollUntilPaid(
    String reference, {
    Duration interval   = const Duration(seconds: 5),
    int     maxAttempts = 24,
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(interval);
      if (await checkPaymentStatus(reference)) return true;
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plans State & Notifier
// ─────────────────────────────────────────────────────────────────────────────

class PlansState {
  final bool isLoading;
  final List<Plan> plans;
  final PlanPreview? preview;
  final String? error;

  const PlansState({
    this.isLoading = false,
    this.plans     = const [],
    this.preview,
    this.error,
  });

  PlansState copyWith({
    bool?        isLoading,
    List<Plan>?  plans,
    PlanPreview? preview,
    String?      error,
  }) =>
      PlansState(
        isLoading: isLoading ?? this.isLoading,
        plans:     plans     ?? this.plans,
        preview:   preview   ?? this.preview,
        error:     error,
      );
}

class PlansNotifier extends StateNotifier<PlansState> {
  PlansNotifier() : super(const PlansState());

  // ── school_admin: GET /plans (active only) ────────────────────────────────
  Future<void> fetchActivePlans() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res  = await ApiService.get('/plans');
      debugPrint('[PlansNotifier.fetchActivePlans] raw: $res');
      final list = _extractList(res);
      debugPrint('[PlansNotifier.fetchActivePlans] count: ${list.length}');
      state = state.copyWith(
        isLoading: false,
        plans: list.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } catch (e, stack) {
      debugPrint('[PlansNotifier.fetchActivePlans] ERROR: $e\n$stack');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── super_admin: GET /super/plans (all, including inactive) ──────────────
  Future<void> fetchAllPlans() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res  = await ApiService.get('/super/plans');
      debugPrint('[PlansNotifier.fetchAllPlans] raw: $res');
      final list = _extractList(res);
      state = state.copyWith(
        isLoading: false,
        plans: list.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } catch (e, stack) {
      debugPrint('[PlansNotifier.fetchAllPlans] ERROR: $e\n$stack');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Live price preview — school_admin uses /plans/preview ─────────────────
  //    super_admin uses /super/plans/preview
  Future<void> fetchPreview({
    required String durationType,
    required bool   isSuperAdmin,
    int buses     = 0,
    int minibuses = 0,
    int vans      = 0,
    int students  = 0,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final endpoint = isSuperAdmin ? '/super/plans/preview' : '/plans/preview';
    try {
      final res = await ApiService.get(
        endpoint,
        queryParams: {
          'duration_type': durationType,
          'buses':         '$buses',
          'minibuses':     '$minibuses',
          'vans':          '$vans',
          'students':      '$students',
        },
      );
      debugPrint('[PlansNotifier.fetchPreview] $res');
      state = state.copyWith(
        isLoading: false,
        preview: PlanPreview.fromJson(res as Map<String, dynamic>),
      );
    } catch (e, stack) {
      debugPrint('[PlansNotifier.fetchPreview] ERROR: $e\n$stack');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── super_admin: edit plan pricing ───────────────────────────────────────
  Future<void> updatePlan(int planId, Map<String, dynamic> fields) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiService.put('/super/plans/$planId', body: fields);
      final updated = Plan.fromJson(
        (res as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      );
      state = state.copyWith(
        isLoading: false,
        plans: state.plans.map((p) => p.id == planId ? updated : p).toList(),
      );
    } catch (e, stack) {
      debugPrint('[PlansNotifier.updatePlan] ERROR: $e\n$stack');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── super_admin: toggle active / inactive ─────────────────────────────────
  Future<void> togglePlan(int planId) async {
    try {
      final res      = await ApiService.post('/super/plans/$planId/toggle', body: {});
      final isActive = (res as Map<String, dynamic>)['is_active'] as bool;
      state = state.copyWith(
        plans: state.plans.map((p) {
          if (p.id != planId) return p;
          return Plan.fromJson({
            'id':               p.id,
            'name':             p.name,
            'duration_type':    p.durationType,
            'bus_price':        p.busPrice,
            'minibus_price':    p.minibusPrice,
            'van_price':        p.vanPrice,
            'student_price':    p.studentPrice,
            'duration_months':  p.durationMonths,
            'discount_percent': p.discountPercent,
            'discount_label':   p.discountLabel,
            'is_active':        isActive,
            'updated_at':       p.updatedAt?.toIso8601String(),
          });
        }).toList(),
      );
    } catch (e, stack) {
      debugPrint('[PlansNotifier.togglePlan] ERROR: $e\n$stack');
      state = state.copyWith(error: e.toString());
    }
  }
}