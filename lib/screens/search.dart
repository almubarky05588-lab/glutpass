import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';
import 'details.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _c = TextEditingController();
  String _q = '';
  bool _safe = false;
  late Future<List<Place>> _f;
  String? _tip;

  @override
  void initState() {
    super.initState();
    _f = _load();
    _loadTip();
  }

  Future<void> _loadTip() async {
    try {
      final r = await Supabase.instance.client
          .from('community_tips')
          .select('body_ar')
          .eq('is_active', true)
          .limit(1);
      if ((r as List).isNotEmpty && mounted) {
        setState(() => _tip = r.first['body_ar'] as String);
      }
    } catch (_) {}
  }

  Future<List<Place>> _load() async {
    var q = Supabase.instance.client
        .from('places')
        .select(Place.cols)
        .eq('status', 'published');
    final s = _q.trim();
    if (s.isNotEmpty) {
      q = q.or('name_ar.ilike.%$s%,name_en.ilike.%$s%,'
          'cuisine.ilike.%$s%,short_note.ilike.%$s%');
    }
    if (_safe) q = q.eq('effective_safety_status', 'SEPARATE_PREP');
    final r = await q.order('safety_votes_count', ascending: false);
    return (r as List)
        .map((e) => Place.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  void _run() => setState(() => _f = _load());

  void _open(Place p) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => DetailsScreen(p)));

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              SizedBox(
                  width: 40,
                  child: IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.arrow_back_ios,
                          size: 18, color: cDark))),
              const Expanded(
                  child: Text('البحث',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: cDark))),
              const SizedBox(width: 40),
            ]),
          ),
          Container(
            height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cGreen, width: 1.4)),
            child: Row(children: [
              const Icon(Icons.search, size: 20, color: cGreen),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _c,
                  textAlign: TextAlign.start,
                  onChanged: (v) {
                    _q = v;
                    _run();
                  },
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'ابحث عن مطعم أو طبق...',
                      hintStyle: TextStyle(color: cGrey, fontSize: 14)),
                  style: const TextStyle(fontSize: 15, color: cDark),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _chip('الأعلى تصويتاً', !_safe, () {
                  _safe = false;
                  _run();
                }),
                const SizedBox(width: 8),
                _chip('آمن للسيلياك', _safe, () {
                  _safe = true;
                  _run();
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: FutureBuilder<List<Place>>(
              future: _f,
              builder: (ctx, s) {
                if (s.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: cGreen));
                }
                final ps = s.data ?? [];
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Row(children: [
                      Text('${ps.length} نتيجة',
                          style: const TextStyle(color: cGrey, fontSize: 13)),
                    ]),
                    const SizedBox(height: 10),
                    if (ps.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(40),
                          child: Text('لا توجد نتائج مطابقة',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cGrey))),
                    ...ps.map(_card),
                    if (_tip != null) _tipBox(_tip!),
                    const SizedBox(height: 30),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String t, bool on, VoidCallback tap) => GestureDetector(
        onTap: tap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
              color: on ? cGreen : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: on ? cGreen : cBorder)),
          child: Text(t,
              style: TextStyle(
                  color: on ? Colors.white : cDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      );

  Widget _card(Place p) => GestureDetector(
        onTap: () => _open(p),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cBorder)),
          child: Column(children: [
            Row(children: [
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
                            style:
                                const TextStyle(fontSize: 11, color: cGrey)),
                      const SizedBox(height: 3),
                      Text(p.note ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: cGrey)),
                    ]),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [SafetyBadge(p), const Spacer(), RatingRow(p)]),
          ]),
        ),
      );

  Widget _tipBox(String t) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: cSafeBg, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('نصيحة المجتمع',
              style: TextStyle(
                  color: cDark, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(t,
              textAlign: TextAlign.start,
              style: const TextStyle(color: cDark, fontSize: 12, height: 1.5)),
        ]),
      );
}
