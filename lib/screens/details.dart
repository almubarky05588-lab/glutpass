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
  bool _saved = false;

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
    };
  }

  Future<void> _toggleSave() async {
    final c = Supabase.instance.client;
    final u = c.auth.currentUser;
    if (u == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('سجّل الدخول من تبويب «حسابي» أولاً')));
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _vote() async {
    final ok = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => VoteScreen(_p)));
    if (ok == true && mounted) setState(() => _f = _load());
  }
}
