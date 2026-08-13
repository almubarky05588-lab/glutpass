import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';
import '../promo.dart';
import 'search.dart';
import 'details.dart';
import 'onboarding.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Place>> _f;
  String _city = 'الكل';

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<List<Place>> _load() async {
    var q = Supabase.instance.client
        .from('places')
        .select(Place.cols)
        .eq('status', 'published');
    if (_city != 'الكل') q = q.eq('city', _city);
    final r = await q.order('safety_votes_count', ascending: false);
    return (r as List)
        .map((e) => Place.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  void _pick(String c) {
    setState(() {
      _city = c;
      _f = _load();
    });
  }

  void _open(Place p) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => DetailsScreen(p)));

  @override
  Widget build(BuildContext ctx) {
    return FutureBuilder<List<Place>>(
      future: _f,
      builder: (ctx, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: cGreen));
        }
        if (s.hasError) {
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text('تعذّر الاتصال بقاعدة البيانات\n${s.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: cGrey, fontSize: 12))));
        }
        final ps = s.data ?? [];
        final nd = ps.fold<int>(0, (a, p) => a + p.dishes);
        final nv = ps.fold<int>(0, (a, p) => a + p.votes);
        return ListView(padding: EdgeInsets.zero, children: [
          _header(),
          const SizedBox(height: 12),
          _bar(ctx),
          const SizedBox(height: 16),
          const PromoBanner(),
          const SizedBox(height: 18),
          _pad(_stats('${ps.length}', '$nd', '$nv')),
          const SizedBox(height: 12),
          _pad(_legend()),
          const SizedBox(height: 18),
          _chips(),
          const SizedBox(height: 20),
          _pad(const Row(children: [
            Text('الأكثر تصويتاً',
                style: TextStyle(
                    color: cDark, fontSize: 17, fontWeight: FontWeight.w700)),
          ])),
          const SizedBox(height: 10),
          if (ps.isEmpty)
            Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                    _city == 'الكل'
                        ? 'لا توجد أماكن بعد'
                        : 'لا توجد أماكن في $_city بعد',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: cGrey))),
          ...ps.map(_card),
          const SizedBox(height: 100),
        ]);
      },
    );
  }

  Widget _pad(Widget w) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: w);

  Widget _header() => Container(
        height: 96,
        color: cGreen,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14)),
              child: const Center(child: GlutMark(width: 24))),
          const SizedBox(width: 10),
          const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('GlutPass',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('مجتمع خالي من الجلوتين',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
        ]),
      );

  Widget _bar(BuildContext ctx) => GestureDetector(
        onTap: () => Navigator.push(
            ctx, MaterialPageRoute(builder: (_) => const SearchScreen())),
        child: Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cBorder)),
          child: const Row(children: [
            Expanded(
                child: Text('ابحث عن مطعم أو طبق...',
                    style: TextStyle(color: cGrey, fontSize: 14))),
            Icon(Icons.search, color: cGrey, size: 20),
          ]),
        ),
      );

  /// الإحصاءات — بطاقة بيضاء واحدة بأيقونات ثنائية الطبقة.
  /// الأخضر محجوز لشارات الأمان، فلا نستخدمه هنا زينةً.
  Widget _stats(String places, String dishes, String votes) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cBorder)),
        child: Row(children: [
          _statCell(const _DomeIcon(), places, 'مطعم', cGreen, cSafeBg),
          _statDivider(),
          _statCell(const _BowlIcon(), dishes, 'طبق', const Color(0xFF5CA733),
              const Color(0xFFEDF6E6)),
          _statDivider(),
          _statCell(const _BubbleIcon(), votes, 'تجربة', cAmber, cAmberBg),
        ]),
      );

  Widget _statDivider() =>
      Container(width: 1, height: 54, color: cBorder);

  Widget _statCell(
          Widget icon, String n, String label, Color fg, Color bg) =>
      Expanded(
        child: Column(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(13)),
            child: icon,
          ),
          const SizedBox(height: 9),
          Text(n,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cDark,
                  height: 1.1)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 11, color: cGrey)),
        ]),
      );

  /// دليل الألوان — سطر واحد مضغوط بدل شريطين يشرحان نفس المعنى مرتين
  Widget _legend() => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cBorder)),
        child: Row(children: [
          _legendItem(cGreen, 'آمنة'),
          Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: cBorder),
          _legendItem(cAmber, 'تحقّق'),
          const Spacer(),
          const Text('دليل الألوان',
              style: TextStyle(fontSize: 11, color: cGrey)),
        ]),
      );

  Widget _legendItem(Color c, String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(t,
              style: TextStyle(
                  fontSize: 12, color: c, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _chips() {
    final list = ['الكل', ...Cities.all];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = list[i];
          final on = c == _city;
          return GestureDetector(
            onTap: () => _pick(c),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                  color: on ? cGreen : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: on ? cGreen : cBorder)),
              child: Text(c,
                  style: TextStyle(
                      color: on ? Colors.white : cDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  Widget _card(Place p) => GestureDetector(
        onTap: () => _open(p),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cBorder)),
          child: Row(children: [
            PlaceAvatar(p),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nameAr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cDark)),
                    if (p.nameEn != null)
                      Text(p.nameEn!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: cGrey)),
                    const SizedBox(height: 2),
                    Text('${p.cuisine ?? ''} · ${p.branch ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: cGrey)),
                    const SizedBox(height: 5),
                    RatingRow(p),
                  ]),
            ),
            const SizedBox(width: 8),
            SafetyBadge(p),
          ]),
        ),
      );
}

// ═══════════ الأيقونات ═══════════
// مرسومة بالمسارات بأسلوب ثنائي الطبقة: شكل ممتلئ خافت وخط حاد فوقه.
// لا صور ولا مكتبة خارجية — فلا تزيد حجم التطبيق ولا تتشوّه عند التكبير.

class _DomeIcon extends StatelessWidget {
  const _DomeIcon();
  @override
  Widget build(BuildContext c) =>
      const SizedBox(width: 24, height: 24, child: CustomPaint(painter: _Dome()));
}

class _Dome extends CustomPainter {
  const _Dome();
  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 24;
    final line = Paint()
      ..color = cGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = cGreen.withValues(alpha: 0.16)
      ..isAntiAlias = true;

    final dome = Path()
      ..moveTo(3.6 * u, 17 * u)
      ..arcToPoint(Offset(20.4 * u, 17 * u),
          radius: Radius.circular(8.4 * u), clockwise: true)
      ..close();
    c.drawPath(dome, fill);
    c.drawPath(dome, line);
    c.drawLine(Offset(2 * u, 17 * u), Offset(22 * u, 17 * u), line);
    c.drawLine(Offset(12 * u, 8.6 * u), Offset(12 * u, 6.6 * u), line);
    c.drawCircle(Offset(12 * u, 5.2 * u),
        1.5 * u, Paint()..color = cGreen..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _Dome old) => false;
}

class _BowlIcon extends StatelessWidget {
  const _BowlIcon();
  @override
  Widget build(BuildContext c) =>
      const SizedBox(width: 24, height: 24, child: CustomPaint(painter: _Bowl()));
}

class _Bowl extends CustomPainter {
  const _Bowl();
  static const _leaf = Color(0xFF5CA733);
  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 24;
    final line = Paint()
      ..color = _leaf
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = _leaf.withValues(alpha: 0.18)
      ..isAntiAlias = true;

    final bowl = Path()
      ..moveTo(3 * u, 12.4 * u)
      ..lineTo(21 * u, 12.4 * u)
      ..arcToPoint(Offset(3 * u, 12.4 * u),
          radius: Radius.circular(9 * u), clockwise: true)
      ..close();
    c.drawPath(bowl, fill);
    c.drawPath(bowl, line);
    c.drawLine(Offset(2 * u, 21.4 * u), Offset(22 * u, 21.4 * u), line);
    // بخار
    final steam1 = Path()
      ..moveTo(9.4 * u, 8 * u)
      ..cubicTo(9.4 * u, 6.6 * u, 10.7 * u, 6.6 * u, 10.7 * u, 5 * u);
    final steam2 = Path()
      ..moveTo(13.6 * u, 8 * u)
      ..cubicTo(13.6 * u, 6.6 * u, 14.9 * u, 6.6 * u, 14.9 * u, 5 * u);
    c.drawPath(steam1, line);
    c.drawPath(steam2, line);
  }

  @override
  bool shouldRepaint(covariant _Bowl old) => false;
}

class _BubbleIcon extends StatelessWidget {
  const _BubbleIcon();
  @override
  Widget build(BuildContext c) => const SizedBox(
      width: 24, height: 24, child: CustomPaint(painter: _Bubble()));
}

class _Bubble extends CustomPainter {
  const _Bubble();
  @override
  void paint(Canvas c, Size s) {
    final u = s.width / 24;
    final line = Paint()
      ..color = cAmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = cAmber.withValues(alpha: 0.16)
      ..isAntiAlias = true;

    final r = Radius.circular(3.2 * u);
    final bubble = Path()
      ..addRRect(RRect.fromLTRBR(3 * u, 4 * u, 21 * u, 16.6 * u, r))
      ..moveTo(7.4 * u, 16.6 * u)
      ..lineTo(7.4 * u, 20.8 * u)
      ..lineTo(11.8 * u, 16.6 * u)
      ..close();
    c.drawPath(bubble, fill);
    c.drawPath(bubble, line);
    // علامة صح
    final tick = Path()
      ..moveTo(8.6 * u, 10.4 * u)
      ..lineTo(11 * u, 12.8 * u)
      ..lineTo(15.6 * u, 8.2 * u);
    c.drawPath(tick, line);
  }

  @override
  bool shouldRepaint(covariant _Bubble old) => false;
}
