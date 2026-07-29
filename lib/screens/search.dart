import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _c = TextEditingController();
  String _q = '';
  bool _safeOnly = false;
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
    if (_q.trim().isNotEmpty) {
      final s = _q.trim();
      q = q.or('name_ar.ilike.%$s%,name_en.ilike.%$s%,'
          'cuisine.ilike.%$s%,short_note.ilike.%$s%');
    }
    if (_safeOnly) q = q.eq('effective_safety_status', 'SEPARATE_PREP');
    final r = await q.order('safety_votes_count', ascending: false);
    return (r as List)
        .map((e) => Place.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  void _run() => setState(() => _f = _load());

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              const SizedBox(width: 40),
              const Expanded(
                  child: Text('البحث',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: cDark))),
              SizedBox(
                width: 40,
                child: IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.arrow_forward_ios,
                        size: 18, color: cDark)),
              ),
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
              if (_q.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _c.clear();
                    _q = '';
                    _run();
                  },
                  child: const Icon(Icons.close, size: 18, color: cGrey),
                ),
              Expanded(
                child: TextField(
                  controller: _c,
                  textAlign: TextAlign.right,
                  textInputAction: TextInputAction.search,
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
              const Icon(Icons.search, size: 20, color: cGreen),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _chip('الأعلى تصويتاً', !_safeOnly, () {
                  _safeOnly = false;
                  _run();
                }),
                const SizedBox(width: 8),
                _chip('آمن للسيلياك', _safeOnly, () {
                  _safeOnly = true;
                  _run();
                }),
                const SizedBox(width: 8),
                _chip('الأقرب لك', false, () {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('يحتاج تفعيل الموقع — قريباً')));
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
                if (s.hasError) {
                  return Center(
                      child: Text('${s.error}',
                          style: const TextStyle
