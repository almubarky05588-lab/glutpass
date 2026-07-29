import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';
import 'vote.dart';

class Dish {
  final String id, nameAr, safety;
  final double? price, pct;
  final int votes;
  final bool rec;

  Dish.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        nameAr = m['name_ar'] as String,
        safety = m['dish_safety_status'] as String,
        price = (m['price'] as num?)?.toDouble(),
        pct = (m['safe_experience_pct'] as num?)?.toDouble(),
        votes = (m['safety_votes_count'] as num?)?.toInt() ?? 0,
        rec = (m['is_recommended'] as bool?) ?? false;

  bool get isSafe => safety == 'SEPARATE_PREP';
  String get tag => isSafe ? 'آمن' : 'تحقّق';
  Color get fg => isSafe ? cGreen : cAmber;
  Color get bg => isSafe ? cSafeBg : cAmberBg;
}

class DetailsScreen extends StatefulWidget {
  final Place place;
  const DetailsScreen(this.place, {super.key});
  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  late Future<Map<String, dynamic>> _f;
  late Place _p;

  @override
  void initState() {
    super.initState();
    _p = widget.place;
    _f = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final c = Supabase.instance.client;
    final row = await c
        .from('places')
        .select(Place.cols)
        .eq('id', _p.id)
        .single();
    final extra = await c
        .from('places')
        .select('avg_rating,ratings_count,address')
        .eq('id', _p.id)
        .single();
    final d = await c
        .from('dishes')
        .select('id,name_ar,price,dish_safety_status,'
            'safe_experience_pct,safety_votes_count,is_recommended')
        .eq('place_id', _p.id)
        .eq('status', 'published')
        .order('safety_votes_count', ascending: false);
    _p = Place.fromMap(row);
    return {
      'x': extra,
      'd': (d as List)
          .map((e) => Dish.fromMap(e as Map<String, dynamic>))
          .toList(),
    };
  }

  Future<void> _vote() async {
    final ok = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => VoteScreen(_p)));
    if (ok == true && mounted) setState(() => _f = _load());
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: cBg,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (ctx, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: cGreen));
          }
          final x = (s.data?['x'] ?? {}) as Map<String, dynamic>;
          final dishes = (s.data?['d'] ?? <Dish>[]) as List<Dish>;
          final rating = (x['avg_rating'] as num?)?.toDouble();
          final rc = (x['ratings_count'] as num?)?.toInt() ?? 0;
          return ListView(padding: EdgeInsets.zero, children: [
            _hero(ctx, x),
            const SizedBox(height: 16),
            _blocks(rating, rc),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: const [
                Spacer(),
                Text('أطباق موصى بها من المجتمع',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cDark)),
              ]),
            ),
            const SizedBox(height: 10),
            if (dishes.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('لا توجد أطباق مسجّلة بعد',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cGrey))),
            ...dishes.map(_dish),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _vote,
                  style: FilledButton.styleFrom(
                      backgroundColor: cGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: const Text('أضف تصويتك وتجربتك',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ]);
        },
      ),
    );
  }

  Widget _hero(BuildContext ctx, Map<String, dynamic> x) => Container(
        color: cGreen,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            Row(children: [
              IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.arrow_forward_ios,
                      size: 18, color: Colors.white)),
              const Spacer(),
              const Text('تفاصيل المطعم',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              const SizedBox(width: 44),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_p.nameAr,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: cDark)),
                  if (_p.nameEn != null)
                    Text(_p.nameEn!,
                        style: const TextStyle(fontSize: 12, color: cGrey)),
                  const SizedBox(height: 6),
                  Text(x['address'] as String? ?? _p.branch ?? '',
                      style: const TextStyle(fontSize: 12, color: cGrey)),
                  const SizedBox(height: 8),
                  SafetyBadge(_p),
                ]),
                const SizedBox(width: 12),
                PlaceAvatar(_p, size: 64),
              ]),
            ),
          ]),
        ),
      );

  Widget _blocks(double? rating, int rc) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cBorder)),
        child: IntrinsicHeight(
          child: Row(children: [
            Expanded(
              child: Column(children: [
                const Text('التقييم العام',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cDark)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.star, size: 15, color: cStar),
                  const SizedBox(width: 5),
                  Text(rating?.toStringAsFixed(1) ?? '—',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: cDark)),
                ]),
                const SizedBox(height: 5),
                Text('$rc تقييم',
                    style: const TextStyle(fontSize: 11, color: cGrey)),
              ]),
            ),
            const VerticalDivider(
                width: 1, color: cBorder, indent: 6, endIndent: 6),
            Expanded(
              child: Column(children: [
                const Text('تجارب الأمان',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cDark)),
                const SizedBox(height: 8),
                Text(
                    _p.pct == null
                        ? 'تجارب قليلة'
                        : '${_p.pct!.toStringAsFixed(0)}٪ بلا أعراض',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _p.badgeFg)),
                const SizedBox(height: 5),
                Text('من ${_p.votes} تجربة',
                    style: const TextStyle(fontSize: 11, color: cGrey)),
              ]),
            ),
          ]),
        ),
      );

  Widget _dish(Dish d) => Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cBorder)),
        child: Column(children: [
          Row(children: [
            const Spacer(),
            Text(d.nameAr,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: cDark)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: d.bg, borderRadius: BorderRadius.circular(12)),
              child: Text(d.tag,
                  style: TextStyle(
                      color: d.fg, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text('· ${d.votes} تجربة',
                style: const TextStyle(fontSize: 11.5, color: cGrey)),
            const SizedBox(width: 10),
            Text('${d.price?.toStringAsFixed(0) ?? '—'} ريال',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: cGreen)),
          ]),
        ]),
      );
}

