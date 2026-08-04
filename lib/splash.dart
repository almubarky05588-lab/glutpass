import 'package:flutter/material.dart';

/// شاشة البداية المتحرّكة.
///
/// تستخدم **نفس** صورتَي شاشة البداية الثابتة التي يرسمها النظام،
/// بنفس المقاسات وطريقة العرض، فالانتقال بينهما غير مرئي بحكم البناء.
/// الحركة على الكتلة كاملة لأن الاسم مطبوع داخل الصورة مع الشعار —
/// ولو فصلناه لأعدنا رسمه فاختلف عن الثابت وظهرت القفزة.
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
  late final Animation<double> _rise;
  bool _finished = false;

  static const _dur = Duration(milliseconds: 1500);
  static const _minShow = Duration(milliseconds: 1700);

  /// مقاس صورة الشعار بالنقاط — الصورة مصدَّرة بكثافة ٤×
  /// والنظام يعرضها مقسومة على ٤، فنطابقه تماماً.
  static const _artWidth = 1040 / 4;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _dur);
    _rise = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _c.forward();
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
        // الشعار والاسم — نفس الملف الذي يعرضه النظام، بحركة صعود وتكبير هادئة
        Center(
          child: AnimatedBuilder(
            animation: _rise,
            builder: (_, child) {
              final t = _rise.value;
              return Transform.translate(
                // يبدأ من موضع الصورة الثابتة تماماً ثم يصعد ١٤ نقطة
                offset: Offset(0, 14 * (1 - t)),
                child: Transform.scale(
                  // تكبير طفيف جداً — يُحسّ ولا يُلاحظ
                  scale: 0.965 + 0.035 * t,
                  child: child,
                ),
              );
            },
            child: Image.asset('assets/brand/splash.png',
                width: _artWidth,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ),
      ]),
    );
  }
}
