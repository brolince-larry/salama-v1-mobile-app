import 'dart:math';
import 'package:flutter/material.dart';

class SalamaSplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SalamaSplashScreen({super.key, required this.nextScreen});
  @override
  State<SalamaSplashScreen> createState() => _State();
}

class _State extends State<SalamaSplashScreen> with TickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  late final AnimationController _dot  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _text = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    _ring.addStatusListener((s) async {
      if (s != AnimationStatus.completed) return;
      await _dot.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      await _dot.reverse();
      await _text.forward();
      await Future.delayed(const Duration(milliseconds: 1400));
      await _fade.forward();
      if (mounted) Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (_, __, ___) => widget.nextScreen, transitionDuration: Duration.zero));
    });
  }

  @override
  void dispose() { _ring.dispose(); _dot.dispose(); _text.dispose(); _fade.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_ring, _dot, _text, _fade]),
    builder: (_, __) => Opacity(
      opacity: 1 - _fade.value,
      child: Scaffold(
        backgroundColor: const Color(0xFF050A06),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox.square(dimension: 220, child: CustomPaint(painter: _SalamaPainter(_ring.value, _dot.value, _text.value))),
          const SizedBox(height: 22),
          Opacity(opacity: _text.value, child: const Text('SCHOOLTRACK', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 5))),
          const SizedBox(height: 6),
          Opacity(opacity: _text.value, child: const Text('Smart Fleet · Safe Journeys', style: TextStyle(color: Color(0x80FFFFFF), fontSize: 10, letterSpacing: 2))),
        ])),
      ),
    ),
  );
}

class _SalamaPainter extends CustomPainter {
  final double ring, dot, text;
  _SalamaPainter(this.ring, this.dot, this.text);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    const oR = 88.0; const iR = 64.0; const gap = 0.55;
    final spin = ring * pi * 4 * (1 - Curves.easeOut.transform(ring));
    final entry = (1 - Curves.easeOutQuart.transform(ring)) * pi;

    canvas.save(); canvas.translate(c.dx, c.dy); canvas.rotate(entry + spin);
    _arc(canvas, oR, iR, pi/2 + gap, pi*2 - gap*2, const Color(0xFF00C244), ring);
    canvas.restore();

    canvas.save(); canvas.translate(c.dx, c.dy); canvas.rotate(-entry + spin);
    _arc(canvas, oR, iR, pi/2 - gap, gap * 2, const Color(0xFFF0E9D6), ring);
    canvas.restore();

    if (dot > 0) {
      final r = Curves.elasticOut.transform(dot) * 20;
      canvas.drawCircle(c, r * 2.4, Paint()..color = const Color(0xFF00C244).withValues(alpha: (1-dot) * 0.25));
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF00C244).withValues(alpha: dot));
    }

    if (text > 0) {
      final tp = TextPainter(textDirection: TextDirection.ltr);
      final mx = Matrix4.identity()..setEntry(3, 2, 0.002)..rotateX((1 - text) * pi / 2);
      canvas.save(); canvas.transform(mx.storage);
      double x = c.dx - 80;
      for (int i = 0; i < 6; i++) {
        final t = Curves.easeOut.transform(((text - i * 0.1) / 0.6).clamp(0.0, 1.0));
        tp.text = TextSpan(text: 'SALAMA'[i], style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: const Color(0xFF009930).withValues(alpha: t)));
        tp.layout(); tp.paint(canvas, Offset(x, c.dy - 22)); x += tp.width + 2;
      }
      canvas.restore();
    }
  }

  void _arc(Canvas canvas, double oR, double iR, double start, double sweep, Color color, double opacity) {
    final p = Path()
      ..moveTo(oR * cos(start), oR * sin(start))
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: oR), start, sweep, false)
      ..lineTo(iR * cos(start + sweep), iR * sin(start + sweep))
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: iR), start + sweep, -sweep, false)
      ..close();
    canvas.drawPath(p, Paint()..color = color.withValues(alpha: opacity));
  }

  @override
  bool shouldRepaint(_SalamaPainter o) => o.ring != ring || o.dot != dot || o.text != text;
}