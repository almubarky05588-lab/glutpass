import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core.dart';
import 'vote.dart';

class Dish {
  final String id, nameAr, safety;
  final String? nameEn;
  final double? price, pct, rating;
  final int votes, ratingsCount;
  final bool rec;

  Dish.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        nameAr = m['name_ar'] as String,
        nameEn = m['name_en'] as String?,
        safety = m['dish_safety_status'] as String,
        price = (m['price'] as num?)?.toDouble(),
        pct = (m['safe_experience_pct'] as num?)?.toDouble(),
        rating = (m['avg_rating'] as num?)?.toDouble(),
        votes = (m['safety_votes_count'] as num?)?.toInt() ?? 0,
        ratingsCount = (m['ratings_count'] as num?)?.toInt() ?? 0,
        rec = (m['is_recommended'] as bool?) ?? false;

  bool get isSafe => safety == 'SEPARATE_PREP';
  String get tag => isSafe ? 'آمن' : 'تحقّق';
  Color get fg => isSafe ? cGreen : cAmber;
  Color get bg => isSafe ? cSafeBg : cAmberBg;
  IconData get icon => isSafe ? Icons.check : Icons.info_outline;

  static const cols = 'id,name_ar,name_en,price,dish_safety_status,'
      'safe_experience_pct,safety_votes_count,avg_rating,ratings_count,'
      'is_recommended';
}

/// تجربة منشورة — تُقرأ من نافذة place_reviews الآمنة
class Review {
  final String id, name, exp;
  final String? comment, avatar, dishName;
  final int? stars;
  final bool celiac;
  final DateTime? visited;

  Review.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        name = (m['reviewer_name'] as String?) ?? 'مستخدم',
        avatar = m['reviewer_avatar'] as String?,
        celiac = (m['reviewer_is_celiac'] as bool?) ?? false,
        exp = (m['safety_experience'] as String?) ?? '',
        stars = (m['star_rating'] as num?)?.toInt(),
        comment = m['comment'] as String?,
        dishName = m['dish_name'] as String?,
        visited = m['visited_at'] == null
            ? null
            : DateTime.tryParse(m['visited_at'] as String);

  bool get isSafe => exp == 'SAFE_NO_SYMPTOMS';
  bool get isMild => exp == 'MILD_SYMPTOMS';

  String get label => isSafe
      ? 'آمن — بلا أعراض'
      : isMild
          ? 'أعراض خفيفة'
          : 'غير آمن';

  Color get fg => isSafe
      ? cGreen
      : isMild
          ? cAmber
          : const Color(0xFFC0392B);

  Color get bg => isSafe
      ? cSafeBg
      : isMild
          ? cAmberBg
          : const Color(0xFFFBECEA);

  IconData get icon => isSafe
      ? Icons.check_circle
      : isMild
          ? Icons.warning_amber_rounded
          : Icons.report_gmailerrorred;
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
  bool _saved = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _p = widget.place;
    _f = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final c = Supabase.instance.client;
    final row =
        await c.from('places').select(Place.cols).eq('id', _p.id).single();
    final extra = await c
        .from('places')
        .select('avg_rating,ratings_count,address,lat,lng')
        .eq('id', _p.id)
        .single();
    final d = await c
        .from('dishes')
        .select(Dish.cols)
        .eq('place_id', _p.id)
        .eq('status', 'published')
        .order('safety_votes_count', ascending: false);

    // التجارب — من النافذة الآمنة، ولا توقف الشاشة إن فشلت
    List<Review> reviews = [];
    try {
      final r = await c
          .from('place_reviews')
          .select()
          .eq('place_id', _p.id)
          .order('created_at', ascending: false)
          .limit(50);
      reviews = (r as List)
          .map((e) => Review.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}

    final u = c.auth.currentUser;
    if (u != null) {
      final s = await c
          .from('saved_places')
          .select('place_id')
          .eq('user_id', u.id)
          .eq('place_id', _p.id)
          .maybeSingle();
      _saved = s != null;
    }
    _p = Place.fromMap(row);
    return {
      'x': extra,
      'd': (d as List)
          .map((e) => Dish.fromMap(e as Map<String, dynamic>))
          .toList(),
      'r': reviews,
    };
  }

  void _refresh() => setState(() => _f = _load());

  Future<void> _toggleSave() async {
    final c = Supabase.instance.client;
    final u = c.auth.currentUser;
    if (u == null) {
      _snack('سجّل الدخول من تبويب «حسابي» أولاً');
      return;
    }
    try {
      if (_saved) {
        await c
            .from('saved_places')
            .delete()
            .eq('user_id', u.id)
            .eq('place_id', _p.id);
      } else {
        await c
            .from('saved_places')
            .insert({'user_id': u.id, 'place_id': _p.id});
      }
      setState(() => _saved = !_saved);
    } catch (e) {
      _snack('$e');
    }
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _vote({Dish? dish}) async {
    final ok = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => VoteScreen(_p, dish: dish)));
    if (ok == true && mounted) _refresh();
  }

  /// يفتح الاتجاهات في تطبيق الخرائط. الرابط عام ويعمل على iOS وأندرويد.
  Future<void> _directions(Map<String, dynamic> x) async {
    final lat = (x['lat'] as num?)?.toDouble();
    final lng = (x['lng'] as num?)?.toDouble();
    final addr = (x['address'] as String?)?.trim();

    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    } else if (addr != null && addr.isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query='
          '${Uri.encodeComponent('$addr ${_p.nameAr}')}');
    } else {
      _snack('لم يُحدَّد موقع هذا المكان بعد');
      return;
    }
    try {
      final ok =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack('تعذّر فتح تطبيق الخرائط');
    } catch (_) {
      _snack('تعذّر فتح تطبيق الخرائط');
    }
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
          final x = (s.data?['x'] ?? <String, dynamic>{})
              as Map<String, dynamic>;
          final dishes = (s.data?['d'] ?? <Dish>[]) as List<Dish>;
          final reviews = (s.data?['r'] ?? <Review>[]) as List<Review>;
          final rating = (x['avg_rating'] as num?)?.toDouble();
          final rc = (x['ratings_count'] as num?)?.toInt() ?? 0;

          return ListView(padding: EdgeInsets.zero, children: [
            _hero(ctx, x),
            const SizedBox(height: 14),
            _flags(),
            const SizedBox(height: 14),
            _blocks(rating, rc),
            const SizedBox(height: 18),
            _tabs(dishes.length, reviews.length),
            const SizedBox(height: 14),
            if (_tab == 0) ..._dishesTab(dishes),
            if (_tab == 1) ..._reviewsTab(reviews),
            if (_tab == 2) ..._locationTab(x),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _vote(),
                  style: FilledButton.styleFrom(
                      backgroundColor: cGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: const Text('أضف تصويتك وتجربتك',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ]);
        },
      ),
    );
  }

  // ─────────── الترويسة ───────────

  Widget _hero(BuildContext ctx, Map<String, dynamic> x) => Container(
        color: cGreen,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            Row(children: [
              IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.arrow_back_ios,
                      size: 18, color: Colors.white)),
              const Spacer(),
              const Text('تفاصيل المطعم',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                onPressed: _toggleSave,
                icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border,
                    size: 22, color: Colors.white),
              ),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                PlaceAvatar(_p, size: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_p.nameAr,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: cDark)),
                        if (_p.nameEn != null)
                          Text(_p.nameEn!,
                              style: const TextStyle(
                                  fontSize: 12, color: cGrey)),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: cGrey),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                                x['address'] as String? ?? _p.branch ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: cGrey)),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        SafetyBadge(_p),
                      ]),
                ),
              ]),
            ),
          ]),
        ),
      );

  /// الشارتان تحت الترويسة — تظهران للأماكن الآمنة فقط
  Widget _flags() {
    if (!_p.isSafe) return const SizedBox.shrink();
    Widget one(String t) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: cSafeBg, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.check, size: 14, color: cGreen),
            const SizedBox(width: 6),
            Expanded(
                child: Text(t,
                    style: const TextStyle(color: cGreen, fontSize: 12))),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        one('قائمة معتمدة خالية من الجلوتين'),
        one('منطقة تحضير منفصلة آمنة للسيلياك'),
      ]),
    );
  }

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
                  const Icon(Icons.star, size: 15, color: Color(0xFFF2B01E)),
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

  // ─────────── التبويبات ───────────

  Widget _tabs(int nd, int nr) {
    Widget seg(int i, String label) {
      final on = _tab == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: on ? Border.all(color: cBorder) : null,
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    color: on ? cDark : cGrey)),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFFEDF1ED),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        seg(0, nd == 0 ? 'الأطباق' : 'الأطباق ($nd)'),
        seg(1, nr == 0 ? 'التقييمات' : 'التقييمات ($nr)'),
        seg(2, 'الموقع'),
      ]),
    );
  }

  // ─────────── تبويب الأطباق ───────────

  List<Widget> _dishesTab(List<Dish> dishes) {
    if (dishes.isEmpty) {
      return [_empty(Icons.restaurant_menu, 'لا توجد أطباق مسجّلة بعد')];
    }
    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(children: [
          Text('أطباق موصى بها من المجتمع',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: cDark)),
        ]),
      ),
      ...dishes.map(_dishCard),
    ];
  }

  Widget _dishCard(Dish d) => GestureDetector(
        onTap: () => _openDish(d),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cBorder)),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.nameAr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: cDark)),
                    if (d.nameEn != null && d.nameEn!.trim().isNotEmpty)
                      Text(d.nameEn!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 11, color: cGrey)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                            color: d.bg,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(d.icon, size: 11, color: d.fg),
                          const SizedBox(width: 3),
                          Text(d.tag,
                              style: TextStyle(
                                  color: d.fg,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      Text('${d.price?.toStringAsFixed(0) ?? '—'} ريال',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cGreen)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('· ${d.votes} تجربة',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5, color: cGrey)),
                      ),
                    ]),
                  ]),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios, size: 14, color: cGrey),
          ]),
        ),
      );

  /// ورقة تفاصيل الطبق — تفتح عند الضغط، ومنها يُقيَّم الطبق
  void _openDish(Dish d) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: cBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 18),
            Text(d.nameAr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: cDark)),
            if (d.nameEn != null && d.nameEn!.trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(d.nameEn!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: cGrey)),
            ],
            const SizedBox(height: 4),
            Text(_p.nameAr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: cGrey)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: d.bg, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(d.icon, size: 17, color: d.fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      d.isSafe
                          ? 'يُحضَّر في منطقة منفصلة — آمن للسيلياك'
                          : 'قد يُحضَّر في منطقة مشتركة — تحقّق قبل الطلب',
                      style: TextStyle(
                          color: d.fg,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.5)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color: cBg, borderRadius: BorderRadius.circular(14)),
              child: IntrinsicHeight(
                child: Row(children: [
                  _dishStat(
                      'السعر',
                      d.price == null
                          ? '—'
                          : '${d.price!.toStringAsFixed(0)} ريال'),
                  const VerticalDivider(width: 1, color: cBorder),
                  _dishStat(
                      'بلا أعراض',
                      d.pct == null
                          ? 'تجارب قليلة'
                          : '${d.pct!.toStringAsFixed(0)}٪'),
                  const VerticalDivider(width: 1, color: cBorder),
                  _dishStat('التجارب', '${d.votes}'),
                ]),
              ),
            ),
            if (d.rating != null) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ...List.generate(5, (i) {
                  final full = d.rating! >= i + 1;
                  return Icon(full ? Icons.star : Icons.star_border,
                      size: 18,
                      color: full ? const Color(0xFFF2B01E) : cStar);
                }),
                const SizedBox(width: 8),
                Text('${d.rating!.toStringAsFixed(1)} · ${d.ratingsCount} تقييم',
                    style: const TextStyle(fontSize: 12, color: cGrey)),
              ]),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(sctx);
                  _vote(dish: d);
                },
                style: FilledButton.styleFrom(
                    backgroundColor: cGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                child: const Text('قيّم هذا الطبق',
                    style:
                        TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () => Navigator.pop(sctx),
                child: const Text('إغلاق',
                    style: TextStyle(color: cGrey, fontSize: 13.5))),
          ]),
        ),
      ),
    );
  }

  Widget _dishStat(String label, String val) => Expanded(
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 11, color: cGrey)),
          const SizedBox(height: 5),
          Text(val,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: cDark)),
        ]),
      );

  // ─────────── تبويب التقييمات ───────────

  List<Widget> _reviewsTab(List<Review> rs) {
    if (rs.isEmpty) {
      return [
        _empty(Icons.rate_review_outlined,
            'لا توجد تجارب منشورة بعد — كن أول من يشارك تجربته')
      ];
    }
    return rs.map(_reviewCard).toList();
  }

  Widget _reviewCard(Review r) {
    final av = r.avatar;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cSafeBg,
              image: (av != null && av.trim().isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(av), fit: BoxFit.cover)
                  : null,
            ),
            child: (av != null && av.trim().isNotEmpty)
                ? null
                : Text(r.name.characters.first,
                    style: const TextStyle(
                        color: cGreen,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: cDark)),
                    ),
                    if (r.celiac) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified, size: 13, color: cGreen),
                    ],
                  ]),
                  if (r.visited != null)
                    Text(_ago(r.visited!),
                        style:
                            const TextStyle(fontSize: 11, color: cGrey)),
                ]),
          ),
          if (r.stars != null)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star, size: 13, color: Color(0xFFF2B01E)),
              const SizedBox(width: 3),
              Text('${r.stars}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cDark)),
            ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
                color: r.bg, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(r.icon, size: 12, color: r.fg),
              const SizedBox(width: 4),
              Text(r.label,
                  style: TextStyle(
                      color: r.fg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          if (r.dishName != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text('· ${r.dishName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: cGrey)),
            ),
          ],
        ]),
        if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(r.comment!.trim(),
              textAlign: TextAlign.start,
              style: const TextStyle(
                  fontSize: 13, color: cDark, height: 1.65)),
        ],
      ]),
    );
  }

  String _ago(DateTime d) {
    final n = DateTime.now().difference(d).inDays;
    if (n <= 0) return 'اليوم';
    if (n == 1) return 'أمس';
    if (n < 30) return 'قبل $n يوماً';
    final m = (n / 30).floor();
    if (m < 12) return m == 1 ? 'قبل شهر' : 'قبل $m أشهر';
    final y = (m / 12).floor();
    return y == 1 ? 'قبل سنة' : 'قبل $y سنوات';
  }

  // ─────────── تبويب الموقع ───────────

  List<Widget> _locationTab(Map<String, dynamic> x) {
    final addr = (x['address'] as String?)?.trim();
    final hasPin = x['lat'] != null && x['lng'] != null;
    return [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 18, color: cGreen),
            const SizedBox(width: 8),
            const Text('العنوان',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cDark)),
          ]),
          const SizedBox(height: 8),
          Text(
              (addr != null && addr.isNotEmpty)
                  ? addr
                  : (_p.branch ?? 'لم يُسجَّل عنوان لهذا المكان بعد'),
              textAlign: TextAlign.start,
              style: const TextStyle(
                  fontSize: 13.5, color: cDark, height: 1.7)),
          if (!hasPin) ...[
            const SizedBox(height: 10),
            const Text('لم يُحدَّد موقع دقيق — سيفتح البحث بالاسم والعنوان',
                style: TextStyle(fontSize: 11.5, color: cGrey)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _directions(x),
              icon: const Icon(Icons.directions_outlined, size: 19),
              label: const Text('الاتجاهات',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: cGreen,
                  side: const BorderSide(color: cGreen, width: 1.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
            ),
          ),
        ]),
      ),
    ];
  }

  Widget _empty(IconData ic, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(40, 24, 40, 10),
        child: Column(children: [
          Icon(ic, size: 34, color: cGrey),
          const SizedBox(height: 12),
          Text(t,
              textAlign: TextAlign.center,
              style: const TextStyle(color: cGrey, fontSize: 13, height: 1.6)),
        ]),
      );
}
