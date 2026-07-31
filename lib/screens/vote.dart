import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';
import 'details.dart';

class VoteScreen extends StatefulWidget {
  final Place place;
  final Dish? dish;
  const VoteScreen(this.place, {super.key, this.dish});
  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> {
  final _comment = TextEditingController();
  String? _exp;
  int _stars = 0;
  bool _busy = false;
  String? _msg;
  bool _done = false;

  static const opts = [
    ['SAFE_NO_SYMPTOMS', 'آمن تماماً، لا أعراض'],
    ['MILD_SYMPTOMS', 'أعراض خفيفة'],
    ['NOT_SAFE', 'غير آمن'],
  ];

  IconData _icon(String k) => k == 'SAFE_NO_SYMPTOMS'
      ? Icons.sentiment_satisfied_alt
      : k == 'MILD_SYMPTOMS'
          ? Icons.sentiment_neutral
          : Icons.sentiment_very_dissatisfied;

  Color _color(String k) => k == 'SAFE_NO_SYMPTOMS'
      ? cGreen
      : k == 'MILD_SYMPTOMS'
          ? cAmber
          : const Color(0xFFC0392B);

  Future<void> _send() async {
    final c = Supabase.instance.client;
    final u = c.auth.currentUser;
    if (u == null) {
      setState(() => _msg = 'سجّل الدخول من تبويب «حسابي» أولاً');
      return;
    }
    if (_exp == null) {
      setState(() => _msg = 'اختر تجربتك مع الأمان');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final data = {
        'user_id': u.id,
        'place_id': widget.place.id,
        'dish_id': widget.dish?.id,
        'safety_experience': _exp,
        'star_rating': _stars == 0 ? null : _stars,
        'comment': _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        'visited_at': DateTime.now().toIso8601String().substring(0, 10),
      };
      await c.from('votes').upsert(data, onConflict: 'user_id,place_id,dish_id');
      setState(() => _done = true);
    } catch (e) {
      setState(() => _msg = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
