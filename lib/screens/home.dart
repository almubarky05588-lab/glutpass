import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';
import '../promo.dart';
import 'search.dart';
import 'details.dart';

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
            _stat('$nv', 'تجربة'),
            const SizedBox(width: 10),
            _stat('$nd', 'طبق'),
            const SizedBox(width: 10),
            _stat('${ps.length}', 'مطعم')
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
            Text('عرض الكل', style: TextStyle(color: cGreen, fontSize: 13)),
            Spacer(),
            Text('الأكثر تصويتاً',
                style: TextStyle(
                    color: cDark, fontSize: 17, fontWeight: FontWeight.w700))
          ])),
          const SizedBox(height: 10),
          if (ps.isEmpty)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Text('لا توجد أماكن في هذه المدينة بعد',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cGrey))),
          ...ps.map(_card),
          const SizedBox(height: 100),
        ]);
      },
    );
  }

  Widget _pad(Widget w) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: w);
}
