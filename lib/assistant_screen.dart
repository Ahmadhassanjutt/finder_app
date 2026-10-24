import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'command_service.dart';
import 'splash_screen.dart' show cCyan, cViolet, cPink;

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen>
    with SingleTickerProviderStateMixin {
  final _speech = SpeechToText();
  final _svc = CommandService();
  final _ctrl = TextEditingController();
  late final AnimationController _anim =
  AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat();
  bool _ready = false, _listening = false;
  String _heard = 'Mic dabayein aur bolein', _reply = '';
  String _locale = 'en_US';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _svc.loadApps();
    final st = await Permission.microphone.request();
    if (st.isGranted) {
      try {
        _ready = await _speech.initialize(
            onStatus: (s) {
              if (s == 'done' || s == 'notListening') {
                if (mounted) setState(() => _listening = false);
              }
            },
            onError: (e) {
              if (mounted) setState(() => _listening = false);
            });
      } catch (_) {
        _ready = false;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    if (!_ready) {
      setState(() => _reply = 'Mic permission ya speech service available nahi. Text se command likhein.');
      return;
    }
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() {
      _listening = true;
      _heard = 'Sun raha hoon...';
    });
    await _speech.listen(
      localeId: _locale,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      onResult: (r) {
        setState(() => _heard = r.recognizedWords);
        if (r.finalResult) _execute(r.recognizedWords);
      },
    );
  }

  Future<void> _execute(String text) async {
    final r = await _svc.run(text);
    if (mounted) setState(() => _reply = r);
  }

  @override
  void dispose() {
    _anim.dispose();
    _ctrl.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size;
    final base = min(w.width, w.height);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF14103A), Color(0xFF05060F)])),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: base * 0.06, vertical: 16),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('VIP Assistant',
                          style: TextStyle(fontSize: base * 0.055, fontWeight: FontWeight.w800)),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                        segments: const [
                          ButtonSegment(value: 'en_US', label: Text('EN')),
                          ButtonSegment(value: 'ur_PK', label: Text('اردو')),
                        ],
                        selected: {_locale},
                        onSelectionChanged: (s) => setState(() => _locale = s.first),
                      ),
                    ]),
                    SizedBox(height: base * 0.08),
                    GestureDetector(
                      onTap: _toggle,
                      child: SizedBox(
                        width: base * 0.7,
                        height: base * 0.7,
                        child: AnimatedBuilder(
                          animation: _anim,
                          builder: (_, __) => CustomPaint(
                            painter: _OrbPainter(_anim.value, _listening),
                            child: Center(
                                child: Icon(_listening ? Icons.graphic_eq : Icons.mic,
                                    size: base * 0.16, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: base * 0.06),
                    Text(_heard,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: base * 0.048, fontWeight: FontWeight.w600)),
                    if (_reply.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: cCyan.withOpacity(.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cCyan.withOpacity(.4))),
                        child: Text(_reply, style: TextStyle(fontSize: base * 0.04, color: Colors.white)),
                      ),
                    ],
                    SizedBox(height: base * 0.08),
                    TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (v) {
                        setState(() => _heard = v);
                        _execute(v);
                        _ctrl.clear();
                      },
                      decoration: InputDecoration(
                        hintText: 'Ya yahan command likhein...',
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send, color: cCyan),
                          onPressed: () {
                            final v = _ctrl.text;
                            setState(() => _heard = v);
                            _execute(v);
                            _ctrl.clear();
                          },
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  final bool active;
  _OrbPainter(this.t, this.active);
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    for (int i = 0; i < 3; i++) {
      final k = (t + i / 3) % 1;
      canvas.drawCircle(
          c,
          r * (0.45 + (active ? 0.55 : 0.25) * k),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = cCyan.withOpacity((1 - k) * (active ? .8 : .35)));
    }
    final core = Rect.fromCircle(center: c, radius: r * 0.42);
    canvas.drawCircle(
        c,
        r * 0.42,
        Paint()
          ..color = (active ? cPink : cViolet).withOpacity(.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    canvas.drawCircle(
        c,
        r * 0.38,
        Paint()
          ..shader = SweepGradient(
              colors: const [cCyan, cViolet, cPink, cCyan],
              transform: GradientRotation(t * 2 * pi))
              .createShader(core));
  }

  @override
  bool shouldRepaint(covariant _OrbPainter o) => true;
}