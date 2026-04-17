// lib/screens/driver/driver_bottom_nav.dart
//
// Purpose: Driver dashboard bottom navigation bar.
//          4 items: Home / Route / [FAB spacer] / Students / Reports.
//          Imported only by driver_home_screen.dart.

import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class DriverBottomNav extends StatelessWidget {
  final int              index;
  final ValueChanged<int> onTap;
  final bool             dark;

  const DriverBottomNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.dark,
  });

  static const _items = [
    (Icons.home_rounded,      'Home'),
    (Icons.map_rounded,       'Route'),
    (Icons.people_rounded,    'Students'),
    (Icons.bar_chart_rounded, 'Reports'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        height: 70,
        decoration: BoxDecoration(
          color: dark ? AppTheme.black : AppTheme.lightBg,
          border: Border(top: BorderSide(
              color: dark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.08))),
        ),
        child: Row(children: List.generate(_items.length, (i) {
          // Index 2 is the FAB spacer slot
          if (i == 2) return const Expanded(child: SizedBox());

          final selected = index == i;
          return Expanded(
            child: GestureDetector(
              onTap:    () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_items[i].$1,
                      color: selected ? AppTheme.primary : Colors.grey,
                      size:  22),
                  const SizedBox(height: 4),
                  Text(_items[i].$2,
                      style: TextStyle(
                          color:      selected ? AppTheme.primary : Colors.grey,
                          fontSize:   10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400)),
                ],
              ),
            ),
          );
        })),
      );
}