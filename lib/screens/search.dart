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
}
