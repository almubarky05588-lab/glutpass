import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'content.dart';
import 'core.dart';
import 'screens/onboarding.dart';

/// شاشة البداية المتحرّكة — تُعرض داخل التطبيق مباشرةً بعد الصورة الثابتة
/// التي يرسمها النظام. تخطيطها مطابق لها تماماً فلا يرى المستخدم انتقالاً،
/// ثم تدبّ فيها الحركة. وتستغل وقت التحميل بدل أن يضيع في شاشة جامدة.
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

  static const _minShow = Duration(milliseconds: 2000);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _minShow)..forward();
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
      body: Stack(children: [
        // الخلفية — نفس تدرّج الصورة الثابتة
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0E5A37), Color(0xFF146C43)],
            ),
          ),
        ),
        // البصمة المائية أسفل يسار — كما في الصورة الثابتة
        Positioned(
          right: -60,
          top: size.height * 0.57,
          child: Opacity(
            opacity: 0.07,
            child: GlutMark(width: 300, color: Colors.white),
          ),
        ),
        // المأكولات المتساقطة
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Stack(
            children: _items
                .map((it) => _positioned(it, _c.value, size))
                .toList(),
          ),
        ),
        // الكتلة الوسطى — مزاحة ٤٣ نقطة للأعلى لتطابق موضعها في الصورة الثابتة
        Center(
          child: Transform.translate(
            offset: const Offset(0, -43),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 156,
                height: 156,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(44)),
                child: const GlutMark(width: 92),
              ),
              const SizedBox(height: 40),
              const Text('GlutPass',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(Content.t('splash.tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFCFE6D8), fontSize: 13)),
            ]),
          ),
        ),
        Positioned(
          bottom: 26,
          right: 0,
          left: 0,
          child: Text('الإصدار ١٫٠',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
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
    final fade = t < 0.12
        ? t / 0.12
        : t > 0.88
            ? (1 - t) / 0.12
            : 1.0;
    return Positioned(
      left: it.x * size.width - it.size / 2,
      top: y - it.size / 2,
      child: Opacity(
        opacity: 0.16 * fade,
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

  // ترتيب مدروس: لا يتزاحمان في عمود واحد، والأحجام متفاوتة
  static const _items = <_Falling>[
    _Falling(0, 0.16, 62, 0.00, 0.72, 0.35),
    _Falling(1, 0.78, 54, 0.06, 0.66, -0.30),
    _Falling(2, 0.42, 46, 0.14, 0.70, 0.24),
    _Falling(3, 0.90, 58, 0.20, 0.62, -0.40),
    _Falling(1, 0.28, 42, 0.30, 0.58, 0.28),
    _Falling(0, 0.62, 50, 0.36, 0.60, -0.22),
    _Falling(3, 0.08, 44, 0.44, 0.54, 0.32),
    _Falling(2, 0.86, 48, 0.52, 0.48, -0.26),
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
    // الخبزة العليا
    final top = Path()
      ..moveTo(14 * s, 42 * s)
      ..cubicTo(14 * s, 20 * s, 86 * s, 20 * s, 86 * s, 42 * s);
    c.drawPath(top, p);
    // حبات السمسم
    final dot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    c.drawCircle(Offset(38 * s, 31 * s), 2.4 * s, dot);
    c.drawCircle(Offset(52 * s, 27 * s), 2.4 * s, dot);
    c.drawCircle(Offset(64 * s, 33 * s), 2.4 * s, dot);
    // الخس
    final lettuce = Path()
      ..moveTo(14 * s, 46 * s)
      ..lineTo(24 * s, 53 * s)
      ..lineTo(38 * s, 46 * s)
      ..lineTo(52 * s, 53 * s)
      ..lineTo(66 * s, 46 * s)
      ..lineTo(78 * s, 53 * s)
      ..lineTo(86 * s, 46 * s);
    c.drawPath(lettuce, p);
    // قطعة اللحم
    c.drawRRect(
        RRect.fromLTRBR(16 * s, 57 * s, 84 * s, 68 * s, Radius.circular(5 * s)),
        p);
    // الخبزة السفلى
    final bot = Path()
      ..moveTo(14 * s, 72 * s)
      ..lineTo(14 * s, 76 * s)
      ..cubicTo(14 * s, 86 * s, 86 * s, 86 * s, 86 * s, 76 * s)
      ..lineTo(86 * s, 72 * s);
    c.drawPath(bot, p);
  }

  void _pizza(Canvas c, double s, Paint p) {
    // المثلث
    final tri = Path()
      ..moveTo(50 * s, 88 * s)
      ..lineTo(20 * s, 30 * s)
      ..lineTo(80 * s, 30 * s)
      ..close();
    c.drawPath(tri, p);
    // القشرة
    final crust = Path()
      ..moveTo(20 * s, 30 * s)
      ..cubicTo(30 * s, 16 * s, 70 * s, 16 * s, 80 * s, 30 * s);
    c.drawPath(crust, p);
    // شرائح البيبروني
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    c.drawCircle(Offset(40 * s, 45 * s), 4.2 * s, fill);
    c.drawCircle(Offset(60 * s, 44 * s), 4.2 * s, fill);
    c.drawCircle(Offset(50 * s, 63 * s), 4.2 * s, fill);
  }

  void _cake(Canvas c, double s, Paint p) {
    // شريحة من الجانب
    final wedge = Path()
      ..moveTo(20 * s, 74 * s)
      ..lineTo(20 * s, 44 * s)
      ..lineTo(80 * s, 30 * s)
      ..lineTo(80 * s, 60 * s)
      ..close();
    c.drawPath(wedge, p);
    // خط القاعدة البسكويتية
    final base = Path()
      ..moveTo(20 * s, 65 * s)
      ..lineTo(80 * s, 51 * s);
    c.drawPath(base, p);
    // حبة الكرز
    c.drawCircle(Offset(64 * s, 27 * s), 5 * s, p);
    final stem = Path()
      ..moveTo(64 * s, 22 * s)
      ..cubicTo(66 * s, 14 * s, 72 * s, 13 * s, 74 * s, 15 * s);
    c.drawPath(stem, p);
  }

  void _drum(Canvas c, double s, Paint p) {
    // اللحم
    final meat = Path()
      ..moveTo(30 * s, 20 * s)
      ..cubicTo(52 * s, 10 * s, 70 * s, 26 * s, 62 * s, 46 * s)
      ..cubicTo(56 * s, 60 * s, 34 * s, 62 * s, 24 * s, 50 * s)
      ..cubicTo(16 * s, 40 * s, 18 * s, 26 * s, 30 * s, 20 * s)
      ..close();
    c.drawPath(meat, p);
    // العظم
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
