import 'package:flutter/material.dart';
import '../config/app_theme.dart';

extension ThemeX on BuildContext {
  bool   get dark    => Theme.of(this).brightness == Brightness.dark;
  Color  get bg      => dark ? AppTheme.black       : AppTheme.lightBg;
  Color  get surface => dark ? AppTheme.darkSurface  : AppTheme.lightSurface;
  Color  get card    => dark ? AppTheme.darkCard      : AppTheme.lightSurface;
  Color  get border  => dark ? AppTheme.darkBorder    : AppTheme.lightBorder;
  Color  get txt     => dark ? AppTheme.textPrimary   : AppTheme.lightText;
  Color  get muted   => dark ? AppTheme.textSecondary : AppTheme.lightMuted;
  Color  get hint    => dark ? AppTheme.textHint      : AppTheme.lightHint;
}