import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_theme.dart';
import '../../../../providers/subscription_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/plan.dart';
import 'billing_toggle.dart';
import 'payment_sheet.dart';
import 'plan_card.dart';

/// SubscriptionPage — school_admin premium subscription management screen.
///
/// Three sections in one scrollable page:
///   § 1 — Current subscription status card (live data)
///   § 2 — Plan selector: billing toggle + plan cards
///   § 3 — Payment triggered via PaymentSheet bottom sheet on plan tap
///
/// Path: lib/screens/admin/pages/subscription/subscription_page.dart
class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  String _cycle = 'monthly';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(plansProvider.notifier).fetchActivePlans();
    });
  }

  // Local price fallback (mirrors backend formula exactly)
  String _priceLabel(Plan plan, int busCount) {
    final preview = ref.read(plansProvider).preview;
    if (preview != null && preview.durationType == plan.durationType) {
      return preview.formatted;
    }
    final monthly  = busCount * plan.busPrice;
    final extended = (monthly * plan.durationMonths * (1 - plan.discountPercent / 100)).round();
    final v        = extended.toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return 'KES $v';
  }

  void _selectPlan(Plan plan, String priceLabel) {
    // Fetch live price preview for this plan + fleet
    final sub = ref.read(subscriptionProvider).details;
    ref.read(plansProvider.notifier).fetchPreview(
      durationType: plan.durationType,
      isSuperAdmin: false,
      buses: sub?.busCount ?? 0,
    );

    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => PaymentSheet(plan: plan, priceLabel: priceLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plansState = ref.watch(plansProvider);
    final subState   = ref.watch(subscriptionProvider);
    final busCount   = subState.details?.busCount ?? 0;
    final isWide     = MediaQuery.of(context).size.width > 760;

    // Plans visible for the selected cycle + always show trial
    final visible = plansState.plans
        .where((p) => p.durationType == _cycle || p.durationType == 'trial')
        .toList();

    return Container(
      color: const Color(0xFF0A0E0A),
      child: CustomScrollView(
        slivers: [
          // ── App bar ───────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0E0A),
            pinned:          true,
            title: const Text('Subscription',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                icon:      const Icon(Icons.refresh_rounded, color: Colors.grey),
                tooltip:   'Refresh plans',
                onPressed: () {
                  ref.read(plansProvider.notifier).fetchActivePlans();
                  final id = ref.read(authProvider).user?.schoolId;
                  if (id != null) ref.read(subscriptionProvider.notifier).fetchStatus(id);
                },
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ══════════════════════════════════════════════════════════
                // § 1 — CURRENT SUBSCRIPTION STATUS
                // ══════════════════════════════════════════════════════════
                const _SectionLabel(label: 'YOUR SUBSCRIPTION'),
                const SizedBox(height: 12),
                _CurrentPlanCard(state: subState),
                const SizedBox(height: 32),

                // ══════════════════════════════════════════════════════════
                // § 2 — PLAN SELECTOR
                // ══════════════════════════════════════════════════════════
                // Hero heading
                Center(
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color:        AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Text('Pricing',
                          style: TextStyle(color: AppTheme.primary,
                              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose the Perfect\nPlan for Your School',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color:      Colors.white,
                          fontSize:   28,
                          fontWeight: FontWeight.w900,
                          height:     1.2),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Whether you\'re a small school or a large district,\nSchoolTrack has a plan that fits your fleet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    BillingToggle(
                      selected:  _cycle,
                      onChanged: (v) => setState(() => _cycle = v),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),

                // Plan cards
                if (plansState.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  )
                else if (plansState.error != null)
                  _ErrorCard(
                    message: plansState.error!,
                    onRetry: () => ref.read(plansProvider.notifier).fetchActivePlans(),
                  )
                else if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('No plans for this billing cycle.',
                        style: TextStyle(color: Colors.grey[600]))),
                  )
                else if (isWide)
                  _WideGrid(
                    plans:    visible,
                    busCount: busCount,
                    price:    _priceLabel,
                    onSelect: _selectPlan,
                  )
                else
                  _NarrowList(
                    plans:    visible,
                    busCount: busCount,
                    price:    _priceLabel,
                    onSelect: _selectPlan,
                  ),

                const SizedBox(height: 16),

                // ── Bottom trust strip ──────────────────────────────────
                _TrustStrip(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// § 1 — Current plan card (premium dark card matching image 3 dashboard style)
// ═══════════════════════════════════════════════════════════════════════════════

class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionState state;
  const _CurrentPlanCard({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color:        const Color(0xFF111811),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final sub    = state.details;
    final active = sub?.isActive ?? false;
    final soon   = sub?.isExpiringSoon ?? false;

    final Color accent = !active
        ? AppTheme.danger
        : soon ? Colors.orange : AppTheme.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.18),
            const Color(0xFF111811),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Status circle
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color:  accent.withValues(alpha: 0.18),
              shape:  BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Icon(
              active
                  ? (soon ? Icons.access_time_rounded : Icons.verified_rounded)
                  : Icons.warning_amber_rounded,
              color: accent, size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(sub?.planName ?? 'No Active Plan',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                _StatusPill(label: (sub?.status ?? 'INACTIVE').toUpperCase(), color: accent),
              ]),
              const SizedBox(height: 4),
              Text(
                !active
                    ? 'Subscribe below to activate your fleet'
                    : soon
                        ? 'Renew soon to avoid disruption'
                        : 'Ecosystem fully synchronised',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              if (sub?.expiresAt != null) ...[
                const SizedBox(height: 4),
                Text(sub!.expiryLabel,
                    style: TextStyle(
                        color: soon ? Colors.orange : Colors.grey[400],
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ],
          )),

          // Bus count badge
          if ((sub?.busCount ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(children: [
                Text('${sub!.busCount}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20)),
                Text('buses', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label; final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: const TextStyle(
        color: Colors.white, fontSize: 9,
        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Plan card layouts
// ═══════════════════════════════════════════════════════════════════════════════

class _WideGrid extends StatelessWidget {
  final List<Plan>                  plans;
  final int                         busCount;
  final String Function(Plan, int)  price;
  final void Function(Plan, String) onSelect;
  const _WideGrid({required this.plans, required this.busCount,
      required this.price, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: plans.asMap().entries.map((e) {
        final featured = e.key == plans.length ~/ 2;
        final p = price(e.value, busCount);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: featured ? 0 : 6),
            child: PlanCard(
              plan:       e.value,
              isSelected: false,
              isFeatured: featured,
              priceLabel: p,
              onSelect:   () => onSelect(e.value, p),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NarrowList extends StatelessWidget {
  final List<Plan>                  plans;
  final int                         busCount;
  final String Function(Plan, int)  price;
  final void Function(Plan, String) onSelect;
  const _NarrowList({required this.plans, required this.busCount,
      required this.price, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: plans.asMap().entries.map((e) {
        final featured = e.key == plans.length ~/ 2;
        final p = price(e.value, busCount);
        return PlanCard(
          plan:       e.value,
          isSelected: false,
          isFeatured: featured,
          priceLabel: p,
          onSelect:   () => onSelect(e.value, p),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Trust strip
// ═══════════════════════════════════════════════════════════════════════════════

class _TrustStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.lock_rounded,      'Secure payments'),
      (Icons.cancel_rounded,    'Cancel anytime'),
      (Icons.support_agent_rounded, '24/7 support'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items.map((item) {
          final (icon, label) = item;
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
                color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          color:         Colors.grey[600],
          fontSize:      11,
          fontWeight:    FontWeight.w700,
          letterSpacing: 1.2));
}

class _ErrorCard extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFF111811), borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      const Icon(Icons.sync_problem_rounded, color: AppTheme.danger, size: 36),
      const SizedBox(height: 8),
      Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: onRetry,
        icon:  const Icon(Icons.refresh_rounded, color: AppTheme.primary),
        label: const Text('Retry', style: TextStyle(color: AppTheme.primary)),
      ),
    ]),
  );
}