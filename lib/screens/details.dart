import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';

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

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final c = Supabase.instance.client;
    final p = await c
        .from('places')
        .select('avg_rating,ratings_count,address,has_certified_gf_menu')
        .eq('id', widget.place.id)
        .single();
    final d = await c
        .from('dishes')
        .select('id,name_ar,price,dish_safety_status,'
            'safe_experience_pct,safety_votes_count,is_recommended')
        .eq('place_id', widget.place.id)
        .eq('status', 'published')
        .order('safety_votes_count', ascending: false);
    return {
      'p': p,
      'd': (d as List).map((e) => Dish.fromMap(e as Map<String, dynamic>)).toList(),
    };
  }
}
