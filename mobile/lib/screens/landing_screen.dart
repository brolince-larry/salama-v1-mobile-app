import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'auth/login_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.black : AppTheme.lightBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _HeroSection(isDark: isDark),
            _StatsRow(isDark: isDark),
            _FeaturesGrid(isDark: isDark),
            _HowItWorks(isDark: isDark),
            _TestimonialSection(isDark: isDark),
            _CTASection(isDark: isDark),
            _Footer(isDark: isDark),
          ],
        ),
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final bool isDark;
  const _HeroSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background decorative circles
        Positioned(top: -60, right: -60, child: _GlowCircle(size: 260, color: AppTheme.primary.withValues(alpha: isDark ? 0.07 : 0.06))),
        Positioned(bottom: 40, left: -80, child: _GlowCircle(size: 200, color: AppTheme.primaryLight.withValues(alpha: isDark ? 0.05 : 0.04))),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 72, 24, 56),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Logo mark
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25), width: 1.5),
                ),
                child: const Icon(Icons.directions_bus_rounded, color: AppTheme.primary, size: 36),
              ),
              const SizedBox(height: 20),

              // Badge pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  const Text('Real-time Student Safety Platform',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.3)),
                ]),
              ),
              const SizedBox(height: 28),

              // Headline
              Text(
                'Track Every Bus.\nProtect Every Child.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppTheme.textPrimary : AppTheme.lightText,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Green underline accent
              Container(width: 48, height: 3, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),

              Text(
                'A unified platform for GPS tracking, instant SOS\nalerts, and automated boarding logs.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark ? AppTheme.textSecondary : AppTheme.lightMuted,
                ),
              ),
              const SizedBox(height: 36),

              // Store buttons
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _StoreButton(icon: Icons.apple, store: 'App Store', isDark: isDark),
                const SizedBox(width: 14),
                _StoreButton(icon: Icons.play_arrow_rounded, store: 'Play Store', isDark: isDark),
              ]),
              const SizedBox(height: 16),

              // Admin link
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.dashboard_rounded, color: AppTheme.primary, size: 16),
                    SizedBox(width: 8),
                    Text('Open Admin Dashboard',
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, color: AppTheme.primary, size: 14),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stats ────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final bool isDark;
  const _StatsRow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('500+', 'Schools'),
      ('12k+', 'Daily Trips'),
      ('99.9%', 'Uptime'),
      ('24/7', 'Support'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: stats.map((s) => _StatItem(v: s.$1, l: s.$2, isDark: isDark)).toList(),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String v, l;
  final bool isDark;
  const _StatItem({required this.v, required this.l, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primary)),
      const SizedBox(height: 2),
      Text(l, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textSecondary : AppTheme.lightMuted, letterSpacing: 0.3)),
    ]);
  }
}

// ── Features Grid ────────────────────────────────────────────────────────────
class _FeaturesGrid extends StatelessWidget {
  final bool isDark;
  const _FeaturesGrid({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final features = [
      (Icons.location_on_rounded,     'Live GPS',         'Track every bus in real time — updated every 5 seconds.',          AppTheme.info),
      (Icons.notifications_active_rounded, 'Smart Alerts', 'Parents notified the moment the bus approaches their stop.',      AppTheme.primary),
      (Icons.warning_amber_rounded,   'SOS System',       'One-tap emergency alert from driver to command center.',            AppTheme.danger),
      (Icons.qr_code_scanner_rounded, 'Digital Boarding', 'Contactless student check-in with QR scan logs.',                  AppTheme.warning),
      (Icons.route_rounded,           'Route Planning',   'Optimise routes, assign stops, and manage schedules easily.',       AppTheme.primaryLight),
      (Icons.shield_rounded,          'Safety Reports',   'Detailed trip history and incident logs for every journey.',        AppTheme.accentDark),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Features'),
          const SizedBox(height: 8),
          Text('Everything you need to keep students safe',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.textPrimary : AppTheme.lightText)),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.82),
            itemCount: features.length,
            itemBuilder: (ctx, i) {
              final f = features[i];
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: f.$4.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(f.$1, color: f.$4, size: 22),
                    ),
                    const SizedBox(height: 14),
                    Text(f.$2, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                        color: isDark ? AppTheme.textPrimary : AppTheme.lightText)),
                    const SizedBox(height: 5),
                    Text(f.$3, style: TextStyle(fontSize: 12, height: 1.5,
                        color: isDark ? AppTheme.textSecondary : AppTheme.lightMuted)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── How It Works ─────────────────────────────────────────────────────────────
class _HowItWorks extends StatelessWidget {
  final bool isDark;
  const _HowItWorks({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.settings_rounded,        'Admin Setup',       'Add buses, routes, drivers and students in minutes.'),
      (Icons.play_circle_filled_rounded, 'Driver Starts Trip', 'GPS tracking begins automatically on trip start.'),
      (Icons.map_rounded,             'Live Tracking',     'Parents watch the bus move in real time on their phone.'),
      (Icons.check_circle_rounded,    'Safe Arrival',      'Automatic boarding confirmation sent to parents.'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 36, 0, 0),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      color: isDark ? AppTheme.darkSurface : AppTheme.lightCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'How it Works'),
          const SizedBox(height: 8),
          Text('Simple for schools, powerful for safety',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.textPrimary : AppTheme.lightText)),
          const SizedBox(height: 28),
          ...List.generate(steps.length, (i) {
            final s = steps[i];
            final isLast = i == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Icon(s.$1, color: AppTheme.primary, size: 18),
                  ),
                  if (!isLast)
                    Container(width: 1.5, height: 32,
                        color: AppTheme.primary.withValues(alpha: 0.2)),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 32),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 8),
                      Text(s.$2, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                          color: isDark ? AppTheme.textPrimary : AppTheme.lightText)),
                      const SizedBox(height: 4),
                      Text(s.$3, style: TextStyle(fontSize: 13, height: 1.5,
                          color: isDark ? AppTheme.textSecondary : AppTheme.lightMuted)),
                    ]),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Testimonial ───────────────────────────────────────────────────────────────
class _TestimonialSection extends StatelessWidget {
  final bool isDark;
  const _TestimonialSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel(label: 'Trusted By Schools'),
          const SizedBox(height: 8),
          Text('What administrators say',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.textPrimary : AppTheme.lightText)),
          const SizedBox(height: 20),
          _QuoteCard(
            quote: '"SchoolTrack cut our incident response time by 80%. Parents trust us more than ever."',
            name: 'James Mwangi',
            role: 'Transport Coordinator, Nairobi Academy',
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          _QuoteCard(
            quote: '"The SOS system alone was worth it. Drivers feel safe, parents feel safe."',
            name: 'Aisha Omondi',
            role: 'Head of Operations, Greenfields School',
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final String quote, name, role;
  final bool isDark;
  const _QuoteCard({required this.quote, required this.name, required this.role, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: List.generate(5, (_) => const Icon(Icons.star_rounded, color: AppTheme.primary, size: 16))),
        const SizedBox(height: 12),
        Text(quote, style: TextStyle(fontSize: 13, height: 1.6,
            fontStyle: FontStyle.italic,
            color: isDark ? AppTheme.textPrimary : AppTheme.lightText)),
        const SizedBox(height: 14),
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            child: Text(name[0], style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                color: isDark ? AppTheme.textPrimary : AppTheme.lightText)),
            Text(role, style: TextStyle(fontSize: 11,
                color: isDark ? AppTheme.textSecondary : AppTheme.lightMuted)),
          ])),
        ]),
      ]),
    );
  }
}

// ── CTA ───────────────────────────────────────────────────────────────────────
class _CTASection extends StatelessWidget {
  final bool isDark;
  const _CTASection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('Start Today — Free Setup',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
        const SizedBox(height: 16),
        const Text('Ready to secure your fleet?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: 8),
        Text('Join 500+ schools already using SchoolTrack.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.dashboard_rounded, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text('Get Started — Admin Login',
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Footer ───────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  final bool isDark;
  const _Footer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(children: [
        const Divider(),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.directions_bus_rounded, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Text('SchoolTrack', style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 15,
              color: isDark ? AppTheme.textPrimary : AppTheme.lightText)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('Salama', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        Text('© 2026 SchoolTrack Systems. All rights reserved.',
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textHint : AppTheme.lightHint)),
      ]),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
      ),
      child: Text(label.toUpperCase(),
          style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    );
  }
}

class _StoreButton extends StatelessWidget {
  final IconData icon;
  final String store;
  final bool isDark;
  const _StoreButton({required this.icon, required this.store, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightText,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.transparent),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 26),
        const SizedBox(width: 9),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('GET IT ON', style: TextStyle(color: Colors.white54, fontSize: 8, letterSpacing: 0.5)),
          Text(store, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ]),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}