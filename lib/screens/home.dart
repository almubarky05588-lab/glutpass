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
          const SizedBox(height: 16),
          _pad(Row(children: [
            _stat('${ps.length}', 'مطعم'),
            const SizedBox(width: 10),
            _stat('$nd', 'طبق'),
            const SizedBox(width: 10),
            _stat('$nv', 'تجربة')
          ])),
          const SizedBox(height: 16),
          _pad(_note(cSafeBg, cGreen, Icons.check,
              'منطقة تحضير منفصلة — آمنة للسيلياك')),
          const SizedBox(height: 6),
          _pad(_note(cAmberBg, cAmber, Icons.warning_amber_rounded,
              'مشتركة / غير معروفة — تحقّق قبل الطلب')),
          const SizedBox(height: 16),
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

  Widget _stat(String n, String l) => Expanded(
        child: Container(
          height: 52,
          decoration: BoxDecoration(
              color: cSafeBg, borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(n,
                style: const TextStyle(
                    color: cGreen, fontSize: 15, fontWeight: FontWeight.w700)),
            Text(l, style: const TextStyle(color: cGreen, fontSize: 11)),
          ]),
        ),
      );

  Widget _note(Color bg, Color fg, IconData ic, String t) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(ic, color: fg, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 12)),
          ),
        ]),
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
