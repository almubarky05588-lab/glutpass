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
      ..strokeWidth = 5 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    switch (kind) {
      case 0:
        _burger(canvas, s, p, fill);
        break;
      case 1:
        _pizza(canvas, s, p, fill);
        break;
      case 2:
        _cake(canvas, s, p);
        break;
      default:
        _drum(canvas, s, p);
    }
  }

  void _burger(Canvas c, double s, Paint p, Paint f) {
    // الخبزة العليا
    final top = Path()
      ..moveTo(18 * s, 40 * s)
      ..cubicTo(18 * s, 24 * s, 82 * s, 24 * s, 82 * s, 40 * s)
      ..close();
    c.drawPath(top, p);
    // السمسم
    c.drawCircle(Offset(40 * s, 33 * s), 2.6 * s, f);
    c.drawCircle(Offset(52 * s, 30 * s), 2.6 * s, f);
    c.drawCircle(Offset(63 * s, 34 * s), 2.6 * s, f);
    // الخس
    final lettuce = Path()
      ..moveTo(18 * s, 47 * s)
      ..cubicTo(26 * s, 42 * s, 34 * s, 52 * s, 42 * s, 47 * s)
      ..cubicTo(50 * s, 42 * s, 58 * s, 52 * s, 66 * s, 47 * s)
      ..cubicTo(74 * s, 42 * s, 78 * s, 50 * s, 82 * s, 47 * s);
    c.drawPath(lettuce, p);
    // اللحم
    c.drawRRect(
        RRect.fromLTRBR(19 * s, 55 * s, 81 * s, 67 * s, Radius.circular(6 * s)),
        p);
    // الخبزة السفلى
    final bot = Path()
      ..moveTo(18 * s, 73 * s)
      ..cubicTo(18 * s, 85 * s, 82 * s, 85 * s, 82 * s, 73 * s)
      ..close();
    c.drawPath(bot, p);
  }

  void _pizza(Canvas c, double s, Paint p, Paint f) {
    // الشريحة
    final tri = Path()
      ..moveTo(50 * s, 86 * s)
      ..lineTo(22 * s, 32 * s)
      ..cubicTo(40 * s, 24 * s, 60 * s, 24 * s, 78 * s, 32 * s)
      ..close();
    c.drawPath(tri, p);
    // القشرة
    final crust = Path()
      ..moveTo(22 * s, 32 * s)
      ..cubicTo(40 * s, 22 * s, 60 * s, 22 * s, 78 * s, 32 * s);
    c.drawPath(crust, p);
    // البيبروني
    c.drawCircle(Offset(42 * s, 46 * s), 4.5 * s, f);
    c.drawCircle(Offset(60 * s, 48 * s), 4.5 * s, f);
    c.drawCircle(Offset(50 * s, 64 * s), 4.5 * s, f);
  }

  void _cake(Canvas c, double s, Paint p) {
    // الوجه الأمامي
    final body = Path()
      ..moveTo(26 * s, 74 * s)
      ..lineTo(26 * s, 46 * s)
      ..lineTo(74 * s, 34 * s)
      ..lineTo(74 * s, 62 * s)
      ..close();
    c.drawPath(body, p);
    // القشدة المتموّجة أعلاه
    final cream = Path()
      ..moveTo(26 * s, 46 * s)
      ..cubicTo(34 * s, 40 * s, 40 * s, 50 * s, 48 * s, 44 * s)
      ..cubicTo(56 * s, 38 * s, 62 * s, 46 * s, 74 * s, 34 * s);
    c.drawPath(cream, p);
    // خط الطبقة السفلى
    final layer = Path()
      ..moveTo(26 * s, 62 * s)
      ..lineTo(74 * s, 50 * s);
    c.drawPath(layer, p);
    // الكرزة
    c.drawCircle(Offset(62 * s, 30 * s), 5 * s, p);
  }

  void _drum(Canvas c, double s, Paint p) {
    // مسار واحد متصل — اللحم يضيق إلى العظم ثم فصّا طرفه
    final leg = Path()
      ..moveTo(30 * s, 74 * s)
      ..cubicTo(22 * s, 78 * s, 23 * s, 88 * s, 32 * s, 86 * s)
      ..cubicTo(35 * s, 93 * s, 45 * s, 90 * s, 43 * s, 83 * s)
      ..lineTo(56 * s, 62 * s)
      ..cubicTo(66 * s, 70 * s, 80 * s, 62 * s, 81 * s, 46 * s)
      ..cubicTo(82 * s, 28 * s, 66 * s, 16 * s, 51 * s, 21 * s)
      ..cubicTo(36 * s, 26 * s, 31 * s, 42 * s, 39 * s, 54 * s)
      ..close();
    c.drawPath(leg, p..strokeWidth = 4.5 * s);
  }

  @override
  bool shouldRepaint(covariant _FoodPainter old) => old.kind != kind;
}
