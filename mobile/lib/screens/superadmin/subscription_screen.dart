import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/fleet_provider.dart';
import '../../models/plan.dart';

/// SubscriptionScreen
///
/// role = 'super_admin'  → full CRUD: edit prices, toggle active, live preview
/// role = 'school_admin' → browse plans, select, pay via M-PESA or PayPal
///
/// Path: lib/screens/superadmin/subscription_screen.dart
class SubscriptionScreen extends ConsumerStatefulWidget {
  final String role;
  const SubscriptionScreen({super.key, this.role = 'school_admin'});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  // ── school_admin payment state ─────────────────────────────────────────────
  Plan?  _selectedPlan;
  String _gateway        = 'mpesa';
  String _reference      = '';
  bool   _paying         = false;
  bool   _polling        = false;
  bool   _paymentSuccess = false;

  final _phoneCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  bool get _isSuperAdmin => widget.role == 'super_admin';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isSuperAdmin
          ? ref.read(plansProvider.notifier).fetchAllPlans()
          : ref.read(plansProvider.notifier).fetchActivePlans();
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? AppTheme.danger : AppTheme.primary,
      behavior:        SnackBarBehavior.floating,
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin:          const EdgeInsets.all(16),
    ));
  }

  String _fmt(int v) =>
      v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  void _onPlanSelected(Plan plan) {
    setState(() => _selectedPlan = plan);
    final sub = ref.read(subscriptionProvider).details;
    ref.read(plansProvider.notifier).fetchPreview(
      durationType: plan.durationType,
      isSuperAdmin: _isSuperAdmin,
      buses: sub?.busCount ?? 0,
    );
  }

  // ── payment flow ───────────────────────────────────────────────────────────

  Future<void> _pay() async {
    if (_selectedPlan == null) return;
    if (_gateway == 'mpesa' && !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _paying = true);
    try {
      final res = await ref.read(subscriptionProvider.notifier).initiatePayment(
            durationType: _selectedPlan!.durationType,
            gateway:      _gateway,
            phone:        _gateway == 'mpesa' ? _phoneCtrl.text.trim() : null,
          );
      _reference = res['reference'] as String? ?? '';
      _snack(_gateway == 'mpesa' ? 'STK Push sent — enter PIN on your phone' : 'Opening PayPal…');
      setState(() { _paying = false; _polling = true; });
      _startPolling();
    } catch (e) {
      if (mounted) { setState(() => _paying = false); _snack(e.toString(), isError: true); }
    }
  }

  void _startPolling() async {
    final paid = await ref.read(subscriptionProvider.notifier).pollUntilPaid(_reference);
    if (!mounted) return;
    setState(() { _polling = false; _paymentSuccess = paid; });
    if (paid) {
      _snack('Subscription activated!');
      final sub = ref.read(subscriptionProvider).details;
      if (sub != null) ref.read(subscriptionProvider.notifier).fetchStatus(sub.busCount);
    } else {
      _snack('Payment not confirmed. Try again.', isError: true);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark       = Theme.of(context).brightness == Brightness.dark;
    final subState   = ref.watch(subscriptionProvider);
    final plansState = ref.watch(plansProvider);
    final fleetState = ref.watch(fleetProvider);

    final busesCount = fleetState.buses.where((b) => (b.type ?? 'bus') == 'bus').length;
    final minibusesCount = fleetState.buses.where((b) => (b.type ?? '') == 'minibus').length;
    final vansCount = fleetState.buses.where((b) => (b.type ?? '') == 'van').length;
    final studentsCount = 0; // Student counts aren't exposed in the mobile subscription status payload.

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0A0E0A) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(_isSuperAdmin ? 'Plan Management' : 'Manage Subscription'),
        elevation: 0,
        backgroundColor: dark ? const Color(0xFF0A0E0A) : const Color(0xFFF3F4F6),
        actions: [
          if (_isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.read(plansProvider.notifier).fetchAllPlans(),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── School admin: current status ─────────────────────────────────
            if (!_isSuperAdmin) ...[
              _CurrentStatusCard(state: subState, dark: dark),
              const SizedBox(height: 24),
            ],

            // ── Super admin: stats row ────────────────────────────────────────
            if (_isSuperAdmin) ...[
              _SuperAdminStatsRow(plans: plansState.plans, dark: dark),
              const SizedBox(height: 24),
            ],

            // ── Payment success ───────────────────────────────────────────────
            if (_paymentSuccess) ...[
              _SuccessBanner(dark: dark),
              const SizedBox(height: 20),
            ],

            // ── Polling ───────────────────────────────────────────────────────
            if (_polling) ...[
              _PollingCard(gateway: _gateway, dark: dark),
              const SizedBox(height: 20),
            ],

            // ── Main content ──────────────────────────────────────────────────
            if (!_polling && !_paymentSuccess) ...[
              _SectionLabel(
                title: _isSuperAdmin ? 'All Plans' : 'Available Plans',
                icon:  _isSuperAdmin ? Icons.tune_rounded : Icons.bolt_rounded,
              ),
              const SizedBox(height: 14),
              _buildPlanList(
                plansState,
                dark,
                busesCount: busesCount,
                minibusesCount: minibusesCount,
                vansCount: vansCount,
                studentsCount: studentsCount,
              ),

              // School admin payment flow
              if (!_isSuperAdmin && _selectedPlan != null) ...[
                const SizedBox(height: 28),
                const _SectionLabel(title: 'Payment Method', icon: Icons.payment_rounded),
                const SizedBox(height: 14),
                _buildGatewayRow(dark),
                const SizedBox(height: 16),
                if (_gateway == 'mpesa') _buildPhoneField(),
                const SizedBox(height: 24),
                _buildPayButton(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ── plan list ──────────────────────────────────────────────────────────────

  Widget _buildPlanList(
    PlansState state,
    bool dark, {
    required int busesCount,
    required int minibusesCount,
    required int vansCount,
    required int studentsCount,
  }) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null) {
      return _ErrorCard(
        message: state.error!,
        onRetry: () => _isSuperAdmin
            ? ref.read(plansProvider.notifier).fetchAllPlans()
            : ref.read(plansProvider.notifier).fetchActivePlans(),
        dark: dark,
      );
    }
    if (state.plans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('No plans available.',
              style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }

    return Column(
      children: state.plans.map((plan) {
        return _isSuperAdmin
            ? _SuperAdminPlanCard(
                plan:     plan,
                dark:     dark,
                fmt:      _fmt,
                busesCount: busesCount,
                minibusesCount: minibusesCount,
                vansCount: vansCount,
                studentsCount: studentsCount,
                onSaved:  (fields) async {
                  await ref.read(plansProvider.notifier).updatePlan(plan.id, fields);
                  if (mounted) _snack('${plan.name} updated');
                },
                onToggle: () async {
                  await ref.read(plansProvider.notifier).togglePlan(plan.id);
                  if (mounted) {
                    final updated = ref.read(plansProvider).plans
                        .firstWhere((p) => p.id == plan.id);
                    _snack('${updated.name} ${updated.isActive ? 'activated' : 'deactivated'}');
                  }
                },
              )
            : _SchoolPlanCard(
                plan:       plan,
                isSelected: _selectedPlan?.id == plan.id,
                preview:    state.preview,
                loading:    state.isLoading,
                onTap:      () => _onPlanSelected(plan),
                dark:       dark,
              );
      }).toList(),
    );
  }

  // ── payment widgets ────────────────────────────────────────────────────────

  Widget _buildGatewayRow(bool dark) {
    return Row(children: [
      Expanded(child: _GatewayTile(
        label: 'M-PESA', icon: Icons.phone_android_rounded,
        selected: _gateway == 'mpesa', dark: dark,
        onTap: () => setState(() => _gateway = 'mpesa'),
      )),
      const SizedBox(width: 12),
      Expanded(child: _GatewayTile(
        label: 'PayPal', icon: Icons.language_rounded,
        selected: _gateway == 'paypal', dark: dark,
        onTap: () => setState(() => _gateway = 'paypal'),
      )),
    ]);
  }

  Widget _buildPhoneField() {
    return Form(
      key: _formKey,
      child: TextFormField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText:  'M-PESA Phone Number',
          hintText:   '2547XXXXXXXX',
          prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
          filled:     true,
          fillColor:  Colors.black.withValues(alpha: 0.03),
          border:     OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Phone number required';
          if (!RegExp(r'^2547\d{8}$').hasMatch(v)) return 'Use format: 2547XXXXXXXX';
          return null;
        },
      ),
    );
  }

  Widget _buildPayButton() {
    final preview   = ref.read(plansProvider).preview;
    final priceText = preview != null ? 'PAY ${preview.formatted}' : 'PROCEED TO PAYMENT';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: AppTheme.primary.withValues(alpha: 0.4),
          blurRadius: 24, offset: const Offset(0, 10),
        )],
      ),
      child: FilledButton.icon(
        onPressed: _paying ? null : _pay,
        icon: _paying
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.lock_rounded, size: 18),
        label: Text(_paying ? 'Processing…' : priceText,
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14)),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SUPER ADMIN: Stats Row
// ═════════════════════════════════════════════════════════════════════════════

class _SuperAdminStatsRow extends StatelessWidget {
  final List<Plan> plans;
  final bool dark;
  const _SuperAdminStatsRow({required this.plans, required this.dark});

  @override
  Widget build(BuildContext context) {
    final active   = plans.where((p) => p.isActive).length;
    final inactive = plans.length - active;

    return Row(children: [
      Expanded(child: _MiniStat(label: 'Total Plans',    value: '${plans.length}', icon: Icons.layers_rounded,     color: Colors.blue,   dark: dark)),
      const SizedBox(width: 12),
      Expanded(child: _MiniStat(label: 'Active',         value: '$active',         icon: Icons.check_circle_rounded, color: AppTheme.primary, dark: dark)),
      const SizedBox(width: 12),
      Expanded(child: _MiniStat(label: 'Inactive',       value: '$inactive',       icon: Icons.pause_circle_rounded, color: Colors.orange, dark: dark)),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value; final IconData icon; final Color color; final bool dark;
  const _MiniStat({required this.label, required this.value, required this.icon, required this.color, required this.dark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        dark ? const Color(0xFF131813) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border:       Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// SUPER ADMIN: Plan Card with inline CRUD
// ═════════════════════════════════════════════════════════════════════════════

class _SuperAdminPlanCard extends StatefulWidget {
  final Plan plan;
  final bool dark;
  final String Function(int) fmt;
  final int busesCount;
  final int minibusesCount;
  final int vansCount;
  final int studentsCount;
  final Future<void> Function(Map<String, dynamic>) onSaved;
  final Future<void> Function() onToggle;

  const _SuperAdminPlanCard({
    required this.plan,
    required this.dark,
    required this.fmt,
    required this.busesCount,
    required this.minibusesCount,
    required this.vansCount,
    required this.studentsCount,
    required this.onSaved,
    required this.onToggle,
  });

  @override
  State<_SuperAdminPlanCard> createState() => _SuperAdminPlanCardState();
}

class _SuperAdminPlanCardState extends State<_SuperAdminPlanCard>
    with SingleTickerProviderStateMixin {
  final _formKey  = GlobalKey<FormState>();
  bool _expanded  = false;
  bool _saving    = false;
  bool _toggling  = false;

  late final TextEditingController _busCtrl;
  late final TextEditingController _minibusCtrl;
  late final TextEditingController _vanCtrl;
  late final TextEditingController _studentCtrl;
  late final TextEditingController _monthsCtrl;
  late final TextEditingController _discountCtrl;

  @override
  void initState() {
    super.initState();
    final p     = widget.plan;
    _busCtrl      = TextEditingController(text: '${p.busPrice}');
    _minibusCtrl  = TextEditingController(text: '${p.minibusPrice}');
    _vanCtrl      = TextEditingController(text: '${p.vanPrice}');
    _studentCtrl  = TextEditingController(text: '${p.studentPrice}');
    _monthsCtrl   = TextEditingController(text: '${p.durationMonths}');
    _discountCtrl = TextEditingController(text: '${p.discountPercent}');
  }

  @override
  void dispose() {
    for (final c in [_busCtrl, _minibusCtrl, _vanCtrl, _studentCtrl, _monthsCtrl, _discountCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSaved({
      'bus_price':        int.parse(_busCtrl.text),
      'minibus_price':    int.parse(_minibusCtrl.text),
      'van_price':        int.parse(_vanCtrl.text),
      'student_price':    int.parse(_studentCtrl.text),
      'duration_months':  int.parse(_monthsCtrl.text),
      'discount_percent': int.parse(_discountCtrl.text),
    });
    if (mounted) setState(() { _saving = false; _expanded = false; });
  }

  Future<void> _toggle() async {
    setState(() => _toggling = true);
    await widget.onToggle();
    if (mounted) setState(() => _toggling = false);
  }

  @override
  Widget build(BuildContext context) {
    final p     = widget.plan;
    final dark  = widget.dark;
    final Color accent = p.isActive ? AppTheme.primary : Colors.grey;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color:        dark ? const Color(0xFF131813) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border:       Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color:     dark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.08),
            blurRadius: 16, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              // Coloured left accent bar
              Container(
                width: 4, height: 48,
                decoration: BoxDecoration(
                  color:        accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(width: 8),
                    if (p.discountPercent > 0) _pill(p.discountLabel, Colors.green),
                    if (!p.isActive) ...[
                      const SizedBox(width: 6),
                      _pill('INACTIVE', AppTheme.danger),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(p.durationLabel,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ]),
              ),
              // Unit price summary chips
              if (!_expanded) ...[
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Bus: KES ${widget.fmt(p.busPrice)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  Text('Student: KES ${widget.fmt(p.studentPrice)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ]),
                const SizedBox(width: 12),
              ],
              // Toggle switch
              _toggling
                  ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Switch.adaptive(
                      value:       p.isActive,
                      activeThumbColor: AppTheme.primary,
                      onChanged:   (_) => _toggle(),
                    ),
              const SizedBox(width: 8),
              Icon(
                _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: Colors.grey,
              ),
            ]),
          ),
        ),

        // ── Expanded Edit Form ──────────────────────────────────────────────
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Divider(height: 1),
                const SizedBox(height: 20),

                // Unit prices grid
                _fieldLabel('Monthly Unit Prices (KES)'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _priceField('Bus / mo', _busCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _priceField('Minibus / mo', _minibusCtrl)),
                ]),
                Row(children: [
                  Expanded(child: _priceField('Van / mo', _vanCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _priceField('Student / mo', _studentCtrl)),
                ]),
                const SizedBox(height: 12),

                // Duration & discount
                _fieldLabel('Duration & Discount'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _priceField('Months', _monthsCtrl, max: 36)),
                  const SizedBox(width: 10),
                  Expanded(child: _priceField('Discount %', _discountCtrl, max: 100)),
                ]),
                const SizedBox(height: 16),

                // Live formula preview (local calc, no API)
                _LivePreview(
                  busPrice:        int.tryParse(_busCtrl.text)      ?? 0,
                  minibusPrice:    int.tryParse(_minibusCtrl.text)  ?? 0,
                  vanPrice:        int.tryParse(_vanCtrl.text)       ?? 0,
                  studentPrice:    int.tryParse(_studentCtrl.text)  ?? 0,
                  busesCount:      widget.busesCount,
                  minibusCount:    widget.minibusesCount,
                  vansCount:       widget.vansCount,
                  studentsCount:   widget.studentsCount,
                  durationMonths:  int.tryParse(_monthsCtrl.text)   ?? 1,
                  discountPercent: int.tryParse(_discountCtrl.text) ?? 0,
                ),
                const SizedBox(height: 16),

                // Action buttons: Cancel + Save
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _expanded = false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(_saving ? 'Saving…' : 'Save Changes'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
  );

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey));

  Widget _priceField(String label, TextEditingController ctrl, {int max = 999999}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller:   ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, _MaxValueFormatter(max)],
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: label,
            filled:    true,
            fillColor: Colors.black.withValues(alpha: 0.02),
            border:    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          onChanged: (_) => setState(() {}), // rebuild live preview
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// SCHOOL ADMIN: Plan selection card
// ═════════════════════════════════════════════════════════════════════════════

class _SchoolPlanCard extends StatelessWidget {
  final Plan        plan;
  final bool        isSelected;
  final PlanPreview? preview;
  final bool        loading;
  final VoidCallback onTap;
  final bool        dark;

  const _SchoolPlanCard({
    required this.plan, required this.isSelected, required this.preview,
    required this.loading, required this.onTap, required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final hasPreview = preview != null && preview!.durationType == plan.durationType;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.08)
              : (dark ? const Color(0xFF131813) : Colors.white),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color:     dark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.07),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          // Radio
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:  isSelected ? AppTheme.primary : Colors.transparent,
              border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(plan.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                if (plan.discountPercent > 0) ...[
                  const SizedBox(width: 8),
                  _DiscountBadge(label: plan.discountLabel),
                ],
              ]),
              const SizedBox(height: 3),
              Text(plan.durationLabel,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ]),
          ),
          // Live price tag
          if (isSelected)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color:        AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasPreview ? preview!.formatted : 'KES —',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13),
                      ),
                    ),
            ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Live formula preview (no API — pure local calc matching backend formula)
// ═════════════════════════════════════════════════════════════════════════════

class _LivePreview extends StatelessWidget {
  final int busPrice, minibusPrice, vanPrice, studentPrice;
  final int durationMonths, discountPercent;
  final int busesCount, minibusCount, vansCount, studentsCount;
  const _LivePreview({
    required this.busPrice, required this.minibusPrice, required this.vanPrice,
    required this.studentPrice, required this.durationMonths, required this.discountPercent,
    required this.busesCount,
    required this.minibusCount,
    required this.vansCount,
    required this.studentsCount,
  });

  int _calc(int buses, int mini, int vans, int students) {
    final monthly = (buses * busPrice) + (mini * minibusPrice) + (vans * vanPrice) + (students * studentPrice);
    return (monthly * durationMonths * (1 - discountPercent / 100)).round();
  }

  String _fmt(int v) =>
      'KES ${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    final total = _calc(busesCount, minibusCount, vansCount, studentsCount);
    final monthly = (busesCount * busPrice) +
        (minibusCount * minibusPrice) +
        (vansCount * vanPrice) +
        (studentsCount * studentPrice);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('LIVE PREVIEW',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                letterSpacing: 1, color: AppTheme.primary)),
        const SizedBox(height: 10),
        Text(
          'Your fleet (${busesCount}B / ${minibusCount}M / ${vansCount}V / ${studentsCount}S)',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          'Monthly: ${_fmt(monthly)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 10),
        Text(
          _fmt(total),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.primary),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Current Status Card (school_admin)
// ═════════════════════════════════════════════════════════════════════════════

class _CurrentStatusCard extends StatelessWidget {
  final SubscriptionState state;
  final bool dark;
  const _CurrentStatusCard({required this.state, required this.dark});

  @override
  Widget build(BuildContext context) {
    final sub    = state.details;
    final active = sub?.isActive ?? false;
    final Color accent = !active
        ? AppTheme.danger
        : (sub?.isExpiringSoon ?? false) ? Colors.orange : Colors.blue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: state.isLoading
          ? const Center(child: SizedBox(width: 120, child: LinearProgressIndicator()))
          : Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  active ? Icons.verified_rounded : Icons.warning_amber_rounded,
                  color: accent, size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sub?.planName ?? 'No Active Plan',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(sub?.expiryLabel ?? 'Subscribe to get started',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(8),
                ),
                child: Text((sub?.status ?? 'INACTIVE').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Polling card
// ═════════════════════════════════════════════════════════════════════════════

class _PollingCard extends StatelessWidget {
  final String gateway; final bool dark;
  const _PollingCard({required this.gateway, required this.dark});

  @override
  Widget build(BuildContext context) {
    final mpesa = gateway == 'mpesa';
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF131813) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 22),
        Text(mpesa ? 'Waiting for M-PESA…' : 'Waiting for PayPal…',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(mpesa
            ? 'Enter your M-PESA PIN to complete payment.'
            : 'Complete payment in the browser, then return here.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Checking every 5 seconds (max 2 min)',
            style: TextStyle(color: Colors.grey[400], fontSize: 11)),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Success banner
// ═════════════════════════════════════════════════════════════════════════════

class _SuccessBanner extends StatelessWidget {
  final bool dark;
  const _SuccessBanner({required this.dark});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppTheme.primary.withValues(alpha: 0.15), AppTheme.primary.withValues(alpha: 0.05)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
    ),
    child: Column(children: [
      const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 56),
      const SizedBox(height: 14),
      const Text('Subscription Activated!',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: AppTheme.primary)),
      const SizedBox(height: 6),
      Text('Your ecosystem is now fully synchronised.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
          textAlign: TextAlign.center),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared helper widgets
// ═════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionLabel({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: AppTheme.primary, size: 20),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
  ]);
}

class _GatewayTile extends StatelessWidget {
  final String label; final IconData icon;
  final bool selected, dark; final VoidCallback onTap;
  const _GatewayTile({required this.label, required this.icon,
      required this.selected, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primary.withValues(alpha: 0.1)
            : (dark ? const Color(0xFF131813) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppTheme.primary : Colors.transparent, width: 2),
        boxShadow: selected ? [
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2),
              blurRadius: 12, offset: const Offset(0, 4)),
        ] : [],
      ),
      child: Column(children: [
        Icon(icon, color: selected ? AppTheme.primary : Colors.grey, size: 30),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppTheme.primary : Colors.grey[600])),
      ]),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message; final VoidCallback onRetry; final bool dark;
  const _ErrorCard({required this.message, required this.onRetry, required this.dark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF131813) : Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(children: [
      const Icon(Icons.sync_problem_rounded, color: AppTheme.danger, size: 36),
      const SizedBox(height: 8),
      Text(message,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 12),
      TextButton.icon(onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
    ]),
  );
}

class _DiscountBadge extends StatelessWidget {
  final String label;
  const _DiscountBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color:        Colors.green.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      border:       Border.all(color: Colors.green.withValues(alpha: 0.3)),
    ),
    child: Text(label,
        style: const TextStyle(color: Colors.green, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 0.3)),
  );
}

// ── Input formatter: clamp to max int ─────────────────────────────────────────

class _MaxValueFormatter extends TextInputFormatter {
  final int max;
  _MaxValueFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue nv) {
    if (nv.text.isEmpty) return nv;
    final n = int.tryParse(nv.text);
    return (n != null && n > max) ? old : nv;
  }
}