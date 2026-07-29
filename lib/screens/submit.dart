import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';

class SubmitScreen extends StatefulWidget {
  const SubmitScreen({super.key});
  @override
  State<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> {
  final _name = TextEditingController();
  final _dishes = TextEditingController();
  final _note = TextEditingController();
  String _city = 'الرياض';
  String _type = 'restaurant';
  String _safety = 'UNKNOWN';
  bool _busy = false;
  bool _done = false;
  String? _msg;

  static const types = {
    'restaurant': 'مطعم',
    'cafe': 'مقهى',
    'bakery': 'مخبز',
  };

  static const levels = {
    'SEPARATE_PREP': 'منطقة تحضير منفصلة — آمنة للسيلياك',
    'SHARED_PREP': 'منطقة مشتركة — احتمال تلوث متبادل',
    'UNKNOWN': 'غير معروف — يحتاج تأكيد المجتمع',
  };

  Color _lvColor(String k) => k == 'SEPARATE_PREP'
      ? cGreen
      : k == 'SHARED_PREP'
          ? cAmber
          : cGrey;

  Future<void> _send() async {
    final u = Supabase.instance.client.auth.currentUser;
    if (u == null) {
      setState(() => _msg = 'سجّل الدخول من تبويب «حسابي» أولاً');
      return;
    }
    if (_name.text.trim().isEmpty) {
      setState(() => _msg = 'اكتب اسم المكان');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final list = _dishes.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await Supabase.instance.client.from('place_submissions').insert({
        'name': _name.text.trim(),
        'city': _city,
        'place_type': _type,
        'claimed_safety': _safety,
        'suggested_dishes': list.isEmpty ? null : list,
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'submitted_by': u.id,
      });
      setState(() => _done = true);
    } catch (e) {
      setState(() => _msg = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
