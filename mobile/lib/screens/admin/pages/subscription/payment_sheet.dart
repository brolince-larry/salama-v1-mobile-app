import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/app_theme.dart';
import '../../../../providers/subscription_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/plan.dart';

/// Premium payment bottom sheet.
/// Three internal states: Pay form → Polling → Success.
/// Path: lib/screens/admin/pages/subscription/payment_sheet.dart
class PaymentSheet extends ConsumerStatefulWidget {
  final Plan   plan;
  final String priceLabel;
  const PaymentSheet({super.key, required this.plan, required this.priceLabel});

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  String _gateway = 'mpesa';
  bool   _paying  = false;
  bool   _polling = false;
  bool   _success = false;

  final _phoneCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  @override
  void dispose() { _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _pay() async {
    if (_gateway == 'mpesa' && !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _paying = true);
    try {
      final res = await ref.read(subscriptionProvider.notifier).initiatePayment(
            durationType: widget.plan.durationType,
            gateway:      _gateway,
            phone:        _gateway == 'mpesa' ? _phoneCtrl.text.trim() : null,
          );
      final ref_ = res['reference'] as String? ?? '';
      if (_gateway == 'paypal') {
        final url = Uri.tryParse(res['approval_url'] as String? ?? '');
        if (url != null && await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } else {
        _snack('STK Push sent — enter your M-PESA PIN');
      }
      setState(() { _paying = false; _polling = true; });
      _poll(ref_);
    } catch (e) {
      if (mounted) { setState(() => _paying = false); _snack('$e', err: true); }
    }
  }

  void _poll(String reference) async {
    final paid = await ref.read(subscriptionProvider.notifier).pollUntilPaid(reference);
    if (!mounted) return;
    if (paid) {
      final schoolId = ref.read(authProvider).user?.schoolId;
      if (schoolId != null) {
        await ref.read(subscriptionProvider.notifier).fetchStatus(schoolId);
      }
      setState(() { _polling = false; _success = true; });
    } else {
      setState(() => _polling = false);
      _snack('Payment not confirmed. Try again.', err: true);
    }
  }

  void _snack(String msg, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: err ? AppTheme.danger : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        Color(0xFF0F160F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, MediaQuery.of(context).viewInsets.bottom + 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Center(child: Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 20),
        if (_success)
          _SuccessView(onDone: () => Navigator.pop(context))
        else if (_polling)
          _PollingView(gateway: _gateway)
        else
          _PayForm(
            plan:      widget.plan,
            price:     widget.priceLabel,
            gateway:   _gateway,
            paying:    _paying,
            ctrl:      _phoneCtrl,
            formKey:   _formKey,
            onGateway: (g) => setState(() => _gateway = g),
            onPay:     _pay,
          ),
      ]),
    );
  }
}

// ── Pay form ──────────────────────────────────────────────────────────────────

class _PayForm extends StatelessWidget {
  final Plan plan; final String price, gateway;
  final bool paying;
  final TextEditingController ctrl;
  final GlobalKey<FormState> formKey;
  final ValueChanged<String> onGateway;
  final VoidCallback onPay;

  const _PayForm({required this.plan, required this.price, required this.gateway,
      required this.paying, required this.ctrl, required this.formKey,
      required this.onGateway, required this.onPay});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plan.name, style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(plan.durationLabel,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:        AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
          ),
          child: Text(price, style: const TextStyle(
              color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.w900)),
        ),
      ]),
      const SizedBox(height: 22),
      Divider(color: Colors.white.withValues(alpha: 0.06)),
      const SizedBox(height: 18),

      // Gateway label
      Text('PAYMENT METHOD', style: TextStyle(
          color: Colors.grey[600], fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 12),

      // Gateway tiles
      Row(children: [
        Expanded(child: _GatewayTile(
          label: 'M-PESA', icon: Icons.phone_android_rounded,
          color: Colors.green, selected: gateway == 'mpesa',
          onTap: () => onGateway('mpesa'),
        )),
        const SizedBox(width: 12),
        Expanded(child: _GatewayTile(
          label: 'PayPal', icon: Icons.language_rounded,
          color: Colors.blue, selected: gateway == 'paypal',
          onTap: () => onGateway('paypal'),
        )),
      ]),

      // Phone field
      if (gateway == 'mpesa') ...[
        const SizedBox(height: 18),
        Form(
          key: formKey,
          child: TextFormField(
            controller:   ctrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              labelText:      'M-PESA Number',
              labelStyle:     const TextStyle(color: Colors.grey),
              hintText:       '2547XXXXXXXX',
              hintStyle:      TextStyle(color: Colors.grey[700]),
              prefixIcon: const Icon(Icons.phone_android_rounded,
                  color: Colors.green, size: 20),
              filled:         true,
              fillColor:      Colors.white.withValues(alpha: 0.04),
              border:         OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Phone required';
              if (!RegExp(r'^2547\d{8}$').hasMatch(v)) return 'Format: 2547XXXXXXXX';
              return null;
            },
          ),
        ),
      ] else
        const SizedBox(height: 6),
      const SizedBox(height: 20),

      // Pay button
      SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: paying ? null : onPay,
          icon: paying
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.lock_rounded, size: 18),
          label: Text(paying ? 'Processing…' : 'PAY $price',
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    ]);
  }
}

// ── Gateway tile ──────────────────────────────────────────────────────────────

class _GatewayTile extends StatelessWidget {
  final String label; final IconData icon; final Color color;
  final bool selected; final VoidCallback onTap;
  const _GatewayTile({required this.label, required this.icon,
      required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.07),
            width: 1.5),
      ),
      child: Column(children: [
        Icon(icon, color: selected ? color : Colors.grey[600], size: 26),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(
            color:      selected ? color : Colors.grey[600],
            fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    ),
  );
}

// ── Polling ───────────────────────────────────────────────────────────────────

class _PollingView extends StatelessWidget {
  final String gateway;
  const _PollingView({required this.gateway});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(children: [
      const CircularProgressIndicator(color: AppTheme.primary),
      const SizedBox(height: 24),
      Text(
        gateway == 'mpesa'
            ? 'Waiting for M-PESA confirmation…'
            : 'Waiting for PayPal confirmation…',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
        textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(
        gateway == 'mpesa'
            ? 'Enter your PIN on your phone to complete.'
            : 'Complete payment in the browser, then return.',
        style: TextStyle(color: Colors.grey[500], fontSize: 13),
        textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text('Checking every 5 s · max 2 min',
          style: TextStyle(color: Colors.grey[700], fontSize: 11)),
    ]),
  );
}

// ── Success ───────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(children: [
      Container(
        width: 68, height: 68,
        decoration: BoxDecoration(
          color:  AppTheme.primary.withValues(alpha: 0.15),
          shape:  BoxShape.circle,
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 2),
        ),
        child: const Icon(Icons.check_rounded, color: AppTheme.primary, size: 34),
      ),
      const SizedBox(height: 18),
      const Text('Subscription Activated!',
          style: TextStyle(color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('Your ecosystem is now fully synchronised.',
          style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onDone,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('DONE',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        ),
      ),
    ]),
  );
}