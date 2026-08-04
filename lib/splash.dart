import 'dart:math' as math;
import 'package:flutter/material.dart';

/// شاشة البداية المتحرّكة.
///
/// تستخدم **نفس** صورتَي شاشة البداية الثابتة التي يرسمها النظام،
/// بنفس المقاسات وطريقة العرض. فالانتقال بينهما غير مرئي بحكم البناء
/// لا بحكم التقدير — ولا نعيد رسم الشعار أو النصوص فتختلف.
class AnimatedSplash extends StatefulWidget {
  final Future<void> Function() work;
  final VoidCallback onDone;
  const AnimatedSplash({super.key, required this.work, required this.onDone});

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _finished = false;

  // مدة الحركة أطول من مدة العرض عمداً: العناصر لا تكمل سقوطها
  // فتبدو مستمرة لا مقطوعة، والشاشة تخرج وهي في منتصف الحركة.
  static const _spin = Duration(milliseconds: 2800);
  static const _minShow = Duration(milliseconds: 2400);

  /// مقاس صورة الشعار بالنقاط — الصورة مصدَّرة بكثافة ٤×
  /// والنظام يعرضها مقسومة على ٤، فنطابقه تماماً.
  static const _artWidth = 1040 / 4;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _spin)..forward();
    _run();
  }

  /// ننتظر التحميل والحد الأدنى للعرض معاً — أيّهما أطول.
  /// فشل التحميل لا يحبس المستخدم في الشاشة.
  Future<void> _run() async {
    final started = DateTime.now();
    try {
      await widget.work();
    } catch (_) {}
    final left = _minShow - DateTime.now().difference(started);
    if (left > Duration.zero) await Future<void>.delayed(left);
    if (!mounted || _finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final size = MediaQuery.of(ctx).size;
    return Scaffold(
      backgroundColor: const Color(0xFF146C43),
      body: Stack(fit: StackFit.expand, children: [
        // الخلفية — نفس ملف الصورة الثابتة، وفيها التدرّج والبصمة ورقم الإصدار
        Image.asset('assets/brand/background.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0E5A37), Color(0xFF146C43)],
                    ),
                  ),
                )),
        // المأكولات تسقط بين الخلفية والشعار
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Stack(
            children:
                _items.map((it) => _positioned(it, _c.value, size)).toList(),
          ),
        ),
        // الشعار والنصوص — نفس الملف الذي يعرضه النظام، موسّطاً كما يوسّطه
        Center(
          child: Image.asset('assets/brand/splash.png',
              width: _artWidth,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      ]),
    );
  }

  Widget _positioned(_Falling it, double p, Size size) {
    // كل عنصر يبدأ في وقته وينتهي في وقته — التفاوت يجعل السقوط طبيعياً
    final t = ((p - it.delay) / it.span).clamp(0.0, 1.0);
    if (t <= 0) return const SizedBox.shrink();
    final y = -it.size + (size.height + it.size * 2) * t;
    // تلاشٍ عند الطرفين حتى لا تظهر أو تختفي فجأة
    final fade = t < 0.14
        ? t / 0.14
        : t > 0.86
            ? (1 - t) / 0.14
            : 1.0;
    return Positioned(
      left: it.x * size.width - it.size / 2,
      top: y - it.size / 2,
      child: Opacity(
        opacity: 0.20 * fade,
        child: Transform.rotate(
          angle: it.spin * t * 2 * math.pi,
          child: SizedBox(
            width: it.size,
            height: it.size,
            child: CustomPaint(painter: _FoodPainter(it.kind)),
          ),
        ),
      ),
    );
  }

  // الأعمدة متباعدة والأحجام متفاوتة، والمدد طويلة حتى تُميَّز الأشكال
  static const _items = <_Falling>[
    _Falling(0, 0.15, 76, 0.00, 0.86, 0.22),
    _Falling(1, 0.80, 66, 0.05, 0.80, -0.18),
    _Falling(2, 0.45, 58, 0.11, 0.84, 0.16),
    _Falling(3, 0.92, 70, 0.16, 0.78, -0.24),
    _Falling(1, 0.30, 54, 0.21, 0.82, 0.20),
    _Falling(0, 0.65, 62, 0.25, 0.76, -0.14),
    _Falling(3, 0.06, 56, 0.29, 0.80, 0.18),
    _Falling(2, 0.88, 60, 0.33, 0.75, -0.20),
  ];
}

class _Falling {
  final int kind; // ٠ برجر · ١ بيتزا · ٢ تشيز كيك · ٣ فخذ دجاج
  final double x, size, delay, span, spin;
  const _Falling(this.kind, this.x, this.size, this.delay, this.span, this.spin);
}

/// المأكولات مرسومة بالخطوط — لا صور، فلا تزيد حجم التطبيق ولا تتشوّه.
class _FoodPainter extends CustomPainter {
  final int kind;
  const _FoodPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.6 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (kind) {
      case 0:
        _burger(canvas, s, p);
        break;
      case 1:
        _pizza(canvas, s, p);
        break;
      case 2:
        _cake(canvas, s, p);
        break;
      default:
        _drum(canvas, s, p);
    }
  }

  void _burger(Canvas c, double s, Paint p) {
    final top = Path()
      ..moveTo(14 * s, 42 * s)
      ..cubicTo(14 * s, 20 * s, 86 * s, 20 * s, 86 * s, 42 * s);
    c.drawPath(top, p);
    final dot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    c.drawCircle(Offset(38 * s, 31 * s), 2.4 * s, dot);
    c.drawCircle(Offset(52 * s, 27 * s), 2.4 * s, dot);
    c.drawCircle(Offset(64 * s, 33 * s), 2.4 * s, dot);
    final lettuce = Path()
      ..moveTo(14 * s, 46 * s)
      ..lineTo(24 * s, 53 * s)
      ..lineTo(38 * s, 46 * s)
      ..lineTo(52 * s, 53 * s)
      ..lineTo(66 * s, 46 * s)
      ..lineTo(78 * s, 53 * s)
      ..lineTo(86 * s, 46 * s);
    c.drawPath(lettuce, p);
    c.drawRRect(
        RRect.fromLTRBR(16 * s, 57 * s, 84 * s, 68 * s, Radius.circular(5 * s)),
        p);
    final bot = Path()
      ..moveTo(14 * s, 72 * s)
      ..lineTo(14 * s, 76 * s)
      ..cubicTo(14 * s, 86 * s, 86 * s, 86 * s, 86 * s, 76 * s)
      ..lineTo(86 * s, 72 * s);
    c.drawPath(bot, p);
  }

  void _pizza(Canvas c, double s, Paint p) {
    final tri = Path()
      ..moveTo(50 * s, 88 * s)
      ..lineTo(20 * s, 30 * s)
      ..lineTo(80 * s, 30 * s)
      ..close();
    c.drawPath(tri, p);
    final crust = Path()
      ..moveTo(20 * s, 30 * s)
      ..cubicTo(30 * s, 16 * s, 70 * s, 16 * s, 80 * s, 30 * s);
    c.drawPath(crust, p);
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    c.drawCircle(Offset(40 * s, 45 * s), 4.2 * s, fill);
    c.drawCircle(Offset(60 * s, 44 * s), 4.2 * s, fill);
    c.drawCircle(Offset(50 * s, 63 * s), 4.2 * s, fill);
  }

  void _cake(Canvas c, double s, Paint p) {
    final wedge = Path()
      ..moveTo(20 * s, 74 * s)
      ..lineTo(20 * s, 44 * s)
      ..lineTo(80 * s, 30 * s)
      ..lineTo(80 * s, 60 * s)
      ..close();
    c.drawPath(wedge, p);
    final base = Path()
      ..moveTo(20 * s, 65 * s)
      ..lineTo(80 * s, 51 * s);
    c.drawPath(base, p);
    c.drawCircle(Offset(64 * s, 27 * s), 5 * s, p);
    final stem = Path()
      ..moveTo(64 * s, 22 * s)
      ..cubicTo(66 * s, 14 * s, 72 * s, 13 * s, 74 * s, 15 * s);
    c.drawPath(stem, p);
  }

  void _drum(Canvas c, double s, Paint p) {
    final meat = Path()
      ..moveTo(30 * s, 20 * s)
      ..cubicTo(52 * s, 10 * s, 70 * s, 26 * s, 62 * s, 46 * s)
      ..cubicTo(56 * s, 60 * s, 34 * s, 62 * s, 24 * s, 50 * s)
      ..cubicTo(16 * s, 40 * s, 18 * s, 26 * s, 30 * s, 20 * s)
      ..close();
    c.drawPath(meat, p);
    final bone = Path()
      ..moveTo(50 * s, 54 * s)
      ..lineTo(68 * s, 72 * s);
    c.drawPath(bone, p);
    c.drawCircle(Offset(74 * s, 72 * s), 6.5 * s, p);
    c.drawCircle(Offset(68 * s, 79 * s), 6.5 * s, p);
  }

  @override
  bool shouldRepaint(covariant _FoodPainter old) => old.kind != kind;
}
