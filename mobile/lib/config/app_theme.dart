  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';

  class AppTheme {
    AppTheme._();

    // ── Brand colors ─────────────────────────────────────────────────────────
    //  Primary   →  Salama green  (dominant, from logo)
    //  Accent    →  warm cream    (from logo bottom arc)
    //  Supporting palette stays purposeful — nothing garish
    static const Color primary      = Color(0xFF00C244); // Salama green
    static const Color primaryDark  = Color(0xFF009930); // pressed / header
    static const Color primaryLight = Color(0xFF33D166); // highlight / chip
    static const Color accent       = Color(0xFFF0E9D6); // warm cream
    static const Color accentDark   = Color(0xFFD4C9B0); // cream pressed
    static const Color success      = Color(0xFF00C244); // reuse primary
    static const Color danger       = Color(0xFFE53935); // clear red
    static const Color warning      = Color(0xFFFFA726); // amber — readable
    static const Color info         = Color(0xFF29B6F6); // sky blue

    // ── Dark palette ─────────────────────────────────────────────────────────
    static const Color black        = Color(0xFF050A06); // near-black, green tint
    static const Color darkSurface  = Color(0xFF0D1A0F); // deep green-black surface
    static const Color darkCard     = Color(0xFF132617); // elevated card
    static const Color darkBorder   = Color(0xFF1E3D24); // subtle green border
    static const Color textPrimary  = Color(0xFFF0EDE6); // warm off-white
    static const Color textSecondary= Color(0xFF8FAE94); // muted sage
    static const Color textHint     = Color(0xFF4A6B50); // dim sage hint

    // ── Light palette ─────────────────────────────────────────────────────────
    static const Color lightBg      = Color(0xFFF7FAF7); // barely-green white
    static const Color lightSurface = Color(0xFFFFFFFF); // pure white card
    static const Color lightCard    = Color(0xFFF0F7F1); // soft green tint card
    static const Color lightBorder  = Color(0xFFD4E6D7); // green-tinted border
    static const Color lightText    = Color(0xFF071A09); // near-black green
    static const Color lightMuted   = Color(0xFF3D6B44); // mid green muted
    static const Color lightHint    = Color(0xFF89AC8E); // hint green

    // ── Status bar overlays ───────────────────────────────────────────────────
    static const SystemUiOverlayStyle _darkOverlay = SystemUiOverlayStyle(
      statusBarColor: primaryDark,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: black,
      systemNavigationBarIconBrightness: Brightness.light,
    );

    static const SystemUiOverlayStyle _lightOverlay = SystemUiOverlayStyle(
      statusBarColor: primaryDark,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: lightBg,
      systemNavigationBarIconBrightness: Brightness.dark,
    );

    // ── Shared input decoration ───────────────────────────────────────────────
    static InputDecorationTheme _inputTheme(Color fill, Color border) =>
        InputDecorationTheme(
          filled: true,
          fillColor: fill,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: danger, width: 2),
          ),
        );

    // ── Shared button style ───────────────────────────────────────────────────
    static final _buttonStyle = FilledButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );

    // ── Light theme ───────────────────────────────────────────────────────────
    static ThemeData get light => ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: lightBg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primary,
            brightness: Brightness.light,
            primary: primary,
            secondary: accentDark,
            surface: lightSurface,
            error: danger,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: primaryDark,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            systemOverlayStyle: _lightOverlay,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          cardTheme: CardThemeData(
            color: lightSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: lightBorder),
            ),
          ),
          inputDecorationTheme: _inputTheme(lightCard, lightBorder),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(style: _buttonStyle),
          dividerTheme:
              const DividerThemeData(color: lightBorder, thickness: 1),
          textTheme: const TextTheme(
            displayLarge:  TextStyle(color: lightText,  fontWeight: FontWeight.w900),
            displayMedium: TextStyle(color: lightText,  fontWeight: FontWeight.w800),
            headlineLarge: TextStyle(color: lightText,  fontWeight: FontWeight.w800),
            headlineMedium:TextStyle(color: lightText,  fontWeight: FontWeight.w700),
            titleLarge:    TextStyle(color: lightText,  fontWeight: FontWeight.w700),
            titleMedium:   TextStyle(color: lightText,  fontWeight: FontWeight.w600),
            bodyLarge:     TextStyle(color: lightText),
            bodyMedium:    TextStyle(color: lightMuted),
            bodySmall:     TextStyle(color: lightHint),
            labelLarge:    TextStyle(color: lightText,  fontWeight: FontWeight.w600),
          ),
          iconTheme: const IconThemeData(color: lightMuted),
          chipTheme: ChipThemeData(
            backgroundColor: lightCard,
            selectedColor: primary.withValues(alpha: 0.15),
            labelStyle: const TextStyle(color: lightMuted, fontSize: 13),
            side: const BorderSide(color: lightBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? primary : lightBorder),
            trackColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? primary.withValues(alpha: 0.3)
                    : lightBorder),
          ),
          checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? primary : Colors.transparent),
            checkColor: WidgetStateProperty.all(Colors.white),
            side: const BorderSide(color: lightBorder, width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: primary,
            linearTrackColor: lightCard,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: lightSurface,
            selectedItemColor: primary,
            unselectedItemColor: lightHint,
            elevation: 8,
            type: BottomNavigationBarType.fixed,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: lightSurface,
            indicatorColor: primary.withValues(alpha: 0.12),
            iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
                color: s.contains(WidgetState.selected) ? primary : lightHint)),
          ),
        );

    // ── Dark theme ────────────────────────────────────────────────────────────
    static ThemeData get dark => ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: black,
          colorScheme: const ColorScheme.dark(
            primary: primary,
            secondary: accent,
            surface: darkSurface,
            error: danger,
            onPrimary: Colors.white,
            onSecondary: lightText,
            onSurface: textPrimary,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: primaryDark,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            systemOverlayStyle: _darkOverlay,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          cardTheme: CardThemeData(
            color: darkCard,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: darkBorder),
            ),
          ),
          inputDecorationTheme: _inputTheme(darkCard, darkBorder),
          filledButtonTheme: FilledButtonThemeData(style: _buttonStyle),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          dividerTheme:
              const DividerThemeData(color: darkBorder, thickness: 1),
          textTheme: const TextTheme(
            displayLarge:  TextStyle(color: textPrimary,   fontWeight: FontWeight.w900),
            displayMedium: TextStyle(color: textPrimary,   fontWeight: FontWeight.w800),
            headlineLarge: TextStyle(color: textPrimary,   fontWeight: FontWeight.w800),
            headlineMedium:TextStyle(color: textPrimary,   fontWeight: FontWeight.w700),
            titleLarge:    TextStyle(color: textPrimary,   fontWeight: FontWeight.w700),
            titleMedium:   TextStyle(color: textPrimary,   fontWeight: FontWeight.w600),
            bodyLarge:     TextStyle(color: textPrimary),
            bodyMedium:    TextStyle(color: textSecondary),
            bodySmall:     TextStyle(color: textHint),
            labelLarge:    TextStyle(color: textPrimary,   fontWeight: FontWeight.w600),
          ),
          iconTheme: const IconThemeData(color: textSecondary),
          chipTheme: ChipThemeData(
            backgroundColor: darkCard,
            selectedColor: primary.withValues(alpha: 0.2),
            labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
            side: const BorderSide(color: darkBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? primary : darkBorder),
            trackColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? primary.withValues(alpha: 0.3)
                    : darkBorder),
          ),
          checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? primary : Colors.transparent),
            checkColor: WidgetStateProperty.all(Colors.white),
            side: const BorderSide(color: darkBorder, width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: primary,
            linearTrackColor: darkCard,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: darkSurface,
            selectedItemColor: primary,
            unselectedItemColor: textHint,
            elevation: 8,
            type: BottomNavigationBarType.fixed,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: darkSurface,
            indicatorColor: primary.withValues(alpha: 0.18),
            iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
                color: s.contains(WidgetState.selected) ? primary : textHint)),
          ),
        );

    // ── Theme-aware helpers (unchanged API — drop-in compatible) ──────────────
    static bool _isDark(BuildContext ctx) =>
        Theme.of(ctx).brightness == Brightness.dark;

    static Color bg(BuildContext ctx) =>
        _isDark(ctx) ? black : lightBg;
    static Color card(BuildContext ctx) =>
        _isDark(ctx) ? darkCard : lightSurface;
    static Color cardTint(BuildContext ctx) =>
        _isDark(ctx) ? const Color(0xFF0D2010) : lightCard;
    static Color border(BuildContext ctx) =>
        _isDark(ctx) ? darkBorder : lightBorder;
    static Color text(BuildContext ctx) =>
        _isDark(ctx) ? textPrimary : lightText;
    static Color muted(BuildContext ctx) =>
        _isDark(ctx) ? textSecondary : lightMuted;
    static Color hint(BuildContext ctx) =>
        _isDark(ctx) ? textHint : lightHint;
    static Color surface(BuildContext ctx) =>
        _isDark(ctx) ? darkSurface : lightSurface;
    // ── Public Decoration Helper ──────────────────────────────────────────────
    static InputDecoration inputDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
       // The rest of the styling (borders, colors) is inherited 
       // from the global inputDecorationTheme in light/dark getters.
      );
    }
  }