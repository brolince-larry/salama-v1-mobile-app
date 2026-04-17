import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';

/// Billing cycle pill toggle — Monthly / Termly / Annually.
/// Path: lib/screens/admin/pages/subscription/billing_toggle.dart
class BillingToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const BillingToggle({super.key, required this.selected, required this.onChanged});

  static const _opts = [
    ('monthly', 'Monthly',  null),
    ('termly',  'Termly',   '10% off'),
    ('yearly',  'Annually', '20% off'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color:        const Color(0xFF141A14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _opts.map((o) {
          final (val, label, badge) = o;
          final sel = selected == val;
          return GestureDetector(
            onTap: () => onChanged(val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color:        sel ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(26),
                boxShadow: sel ? [BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 12, offset: const Offset(0, 3))] : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (sel) ...[
                  Container(width: 7, height: 7,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                ],
                Text(label, style: TextStyle(
                    color:      sel ? Colors.white : Colors.grey[400],
                    fontSize:   13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                if (badge != null && !sel) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(badge, style: const TextStyle(
                        color: Colors.green, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}