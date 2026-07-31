import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core.dart';

const kOnboardingSeenKey = 'onboarding_seen_v1';

const _cBody = Color(0xFF6B7A70);
const _cDotOff = Color(0xFFCCD6CE);
const _cLeaf = Color(0xFF5CA733);

/// شعار GlutPass مرسوماً بالمسارات — مطابق لهندسة فيجما تماماً
class GlutMark extends StatelessWidget {
  final double width;
  final Color color;
  const GlutMark({super.key, this.width = 110, this.color = _cLeaf});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: width * 600.0 / 480.0,
        child: CustomPaint(painter: const _MarkPainter(_cLeaf)),
      );
}

class _MarkPainter extends CustomPainter {
  final Color color;
  const _MarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 480.0;
    final double sy = size.height / 600.0;
    final Path path = Path();

    // الأشرطة الثلاثة العلوية
    for (final double o in const [0.0, 116.0, 232.0]) {
      path.moveTo(0.0, o * sy);
      path.cubicTo(113.333 * sx, (o + 10.6667) * sy, 193.333 * sx,
          (o + 44.0) * sy, 240.0 * sx, (o + 100.0) * sy);
      path.cubicTo(286.667 * sx, (o + 44.0) * sy, 366.667 * sx,
          (o + 10.6667) * sy, 480.0 * sx, o * sy);
      path.lineTo(480.0 * sx, (o + 92.0) * sy);
      path.cubicTo(366.667 * sx, (o + 102.667) * sy, 286.667 * sx,
          (o + 136.0) * sy, 240.0 * sx, (o + 192.0) * sy);
      path.cubicTo(193.333 * sx, (o + 136.0) * sy, 113.333 * sx,
          (o + 102.667) * sy, 0.0, (o + 92.0) * sy);
      path.close();
    }

    // القاعدة
    path.moveTo(0.0, 348.0 * sy);
    path.cubicTo(113.333 * sx, 358.667 * sy, 193.333 * sx, 392.0 * sy,
        240.0 * sx, 448.0 * sy);
    path.cubicTo(286.667 * sx, 392.0 * sy, 366.667 * sx, 358.667 * sy,
        480.0 * sx, 348.0 * sy);
    path.lineTo(480.0 * sx, 404.0 * sy);
    path.cubicTo(
        480.0 * sx, 544.0 * sy, 374.0 * sx, 600.0 * sy, 240.0 * sx, 600.0 * sy);
    path.cubicTo(106.0 * sx, 600.0 * sy, 0.0, 544.0 * sy, 0.0, 404.0 * sy);
    path.close();

    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.color != color;
}

class _Page {
  final String title, body, cta;
  const _Page(this.title, this.body, this.cta);
}

const List<_Page> _pages = [
  _Page(
    'اكتشف الأماكن الآمنة',
    'دليل متكامل للمطاعم والأطباق الخالية من الجلوتين في مدن المملكة، '
        'مع توضيح مستوى الأمان لمرضى السيلياك قبل الطلب.',
    'التالي',
  ),
  _Page(
    'صوّت وساعد غيرك',
    'أضف الأماكن والأطباق التي جرّبتها وقيّمها، فتجربتك الصادقة هي مرجع '
        'يعتمد عليه مجتمع كامل من مرضى حساسية الجلوتين.',
    'ابدأ الآن',
  ),
];

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _i = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(kOnboardingSeenKey, true);
    } catch (_) {
      // فشل الحفظ لا يحبس المستخدم خارج التطبيق
    }
    widget.onFinish();
  }

  void _next() {
    if (_i < _pages.length - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: GestureDetector(
                  onTap: _finish,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: Text('تخطي',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: _cBody)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _pages.length,
                onPageChanged: (v) => setState(() => _i = v),
                itemBuilder: (_, i) => _PageBody(_pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final bool on = i == _i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3.5),
                  width: on ? 24.0 : 9.0,
                  height: 9.0,
                  decoration: BoxDecoration(
                      color: on ? cGreen : _cDotOff,
                      borderRadius: BorderRadius.circular(4.5)),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 27, 20, 22),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_pages[_i].cta,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  final _Page page;
  const _PageBody(this.page, {super.key});

  @override
  Widget build(BuildContext ctx) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(36, 12, 36, 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 300,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: cSafeBg, borderRadius: BorderRadius.circular(28)),
            child: const GlutMark(width: 110),
          ),
          const SizedBox(height: 46),
          Text(page.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, color: cDark)),
          const SizedBox(height: 16),
          Text(page.body,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 15, height: 1.75, color: _cBody)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
