import 'dart:math';
import 'package:flutter/material.dart';
import 'assistant_screen.dart';

const String kMyImage = 'assets/images/me.jpg';
const cCyan = Color(0xFF00E5FF);
const cViolet = Color(0xFF9D4EDD);
const cPink = Color(0xFFFF2E93);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();
  final _rnd = Random(7);
  late final List<_Particle> _ps = List.generate(70, (_) => _Particle(_rnd));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 900),
          pageBuilder: (_, __, ___) => const AssistantScreen(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 1.15, end: 1.0).animate(a),
              child: child,
            ),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _loop.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final base = min(size.width, size.height);
    final imgSize = base * 0.36;
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_loop, _intro]),
        builder: (context, _) {
          final t = _loop.value;
          final pulse = 0.5 + 0.5 * sin(t * 2 * pi * 4);
          final pop = Curves.elasticOut.transform(_intro.value.clamp(0.0, 1.0));
          final fade = Curves.easeIn.transform(
            ((_intro.value - 0.4) / 0.6).clamp(0.0, 1.0),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _FxPainter(t, _ps, pulse, _intro.value)),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(0, sin(t * 2 * pi * 2) * base * 0.012),
                      child: Transform.scale(
                        scale: pop * (1 + 0.025 * pulse),
                        child: Container(
                          width: imgSize,
                          height: imgSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: cCyan.withOpacity(0.35 + 0.35 * pulse),
                                blurRadius: 30 + 30 * pulse,
                                spreadRadius: 4 + 8 * pulse,
                              ),
                              BoxShadow(
                                color: cPink.withOpacity(0.25 * pulse),
                                blurRadius: 60,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              kMyImage,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.65),
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF12142B),
                                child: Icon(
                                  Icons.person,
                                  size: imgSize * .6,
                                  color: cCyan,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: base * 0.22),
                    Opacity(
                      opacity: fade,
                      child: ShaderMask(
                        shaderCallback: (r) => LinearGradient(
                          colors: const [cCyan, cViolet, cPink],
                          transform: GradientRotation(t * 2 * pi),
                        ).createShader(r),
                        child: Text(
                          'VIP ASSISTANT',
                          style: TextStyle(
                            fontSize: base * 0.075,
                            fontWeight: FontWeight.w800,
                            letterSpacing: base * 0.014,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Opacity(
                      opacity: fade * (0.5 + 0.5 * pulse),
                      child: Text(
                        'Listening to your world...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: base * 0.035,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Particle {
  final double a, r, speed, size, spin;
  final Color c;
  _Particle(Random r)
    : a = r.nextDouble() * 2 * pi,
      r = r.nextDouble(),
      speed = (1 + r.nextInt(2)).toDouble(),
      size = 1 + r.nextDouble() * 2.5,
      spin = (r.nextBool() ? 1 : -1) * (0.1 + r.nextDouble() * 0.2),
      c = [cCyan, cViolet, cPink, Colors.white][r.nextInt(4)];
}

class _FxPainter extends CustomPainter {
  final double t, pulse, intro;
  final List<_Particle> ps;
  _FxPainter(this.t, this.ps, this.pulse, this.intro);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2 - s.shortestSide * 0.06);
    final m = s.shortestSide;
    canvas.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF1A1040).withOpacity(0.9),
            const Color(0xFF05060F),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: s.longestSide * .7)),
    );

    // glow halo
    canvas.drawCircle(
      c,
      m * (0.3 + 0.05 * pulse),
      Paint()
        ..color = cViolet.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );

    // particles flowing outward
    for (final p in ps) {
      final k = (p.r + t * p.speed) % 1.0;
      final ang = p.a + t * 2 * pi * p.spin;
      final rad = m * 0.2 + k * m * 0.85;
      final o = c + Offset(cos(ang), sin(ang)) * rad;
      canvas.drawCircle(
        o,
        p.size * (1 - k * .5),
        Paint()..color = p.c.withOpacity((1 - k) * 0.9 * intro),
      );
    }

    // rotating rings
    final rings = [
      (0.27, 1, cCyan, 4.0),
      (0.34, -2, cPink, 3.0),
      (0.42, 1, cViolet, 2.5),
    ];
    for (final r in rings) {
      final rect = Rect.fromCircle(center: c, radius: m * r.$1 * intro);
      final rot = t * 2 * pi * r.$2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.$4
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [r.$3.withOpacity(0), r.$3],
          transform: GradientRotation(rot),
        ).createShader(rect);
      canvas.drawArc(rect, rot, pi * 1.5, false, paint);
      canvas.drawArc(
        rect,
        rot,
        pi * 1.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.$4 * 3
          ..color = r.$3.withOpacity(0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // dotted ring
    final dr = m * 0.48 * intro;
    for (int i = 0; i < 48; i++) {
      final a = i / 48 * 2 * pi + t * 2 * pi * -0.5;
      final on = ((i + (t * 48).floor()) % 6 == 0);
      canvas.drawCircle(
        c + Offset(cos(a), sin(a)) * dr,
        on ? 3 : 1.4,
        Paint()..color = (on ? cCyan : Colors.white24),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter o) => true;
}
