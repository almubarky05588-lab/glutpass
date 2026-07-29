import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';
import 'details.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String _city = 'الرياض';
  bool _celiac = false;
  bool _signup = false;
  bool _busy = false;
  String? _msg;
  Map<String, dynamic>? _me;
  List<Place> _saved = [];

  @override
  void initState() {
    super.initState();
    _load();
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final c = Supabase.instance.client;
    final u = c.auth.currentUser;
    if (u == null) {
      if (mounted) setState(() { _me = null; _saved = []; });
      return;
    }
    try {
      final p = await c
          .from('profiles')
          .select('full_name,city,is_celiac')
          .eq('id', u.id)
          .maybeSingle();
      final v = await c.from('votes').select('id').eq('user_id', u.id);
      final subs =
          await c.from('place_submissions').select('id').eq('submitted_by', u.id);
      final sv = await c
          .from('saved_places')
          .select('places(${Place.cols})')
          .eq('user_id', u.id)
          .order('created_at', ascending: false);
      final list = (sv as List)
          .map((e) => e['places'])
          .whereType<Map<String, dynamic>>()
          .map(Place.fromMap)
          .toList();
      if (mounted) {
        setState(() {
          _saved = list;
          _me = {
            'name': p?['full_name'] ?? 'مستخدم',
            'city': p?['city'] ?? '',
            'celiac': p?['is_celiac'] ?? false,
            'votes': (v as List).length,
            'subs': (subs as List).length,
            'email': u.email ?? '',
          };
        });
      }
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    }
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _msg = null; });
    try {
      final a = Supabase.instance.client.auth;
      if (_signup) {
        final r = await a.signUp(
          email: _email.text.trim(),
          password: _pass.text,
          data: {
            'full_name': _name.text.trim(),
            'city': _city,
            'is_celiac': _celiac,
          },
        );
        if (r.session == null) {
          setState(() => _msg = 'تحقّق من بريدك لتأكيد الحساب');
        }
      } else {
        await a.signInWithPassword(
            email: _email.text.trim(), password: _pass.text);
      }
      await _load();
    } on AuthException catch (e) {
      setState(() => _msg = e.message);
    } catch (e) {
      setState(() => _msg = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _out() async {
    await Supabase.instance.client.auth.signOut();
    _email.clear();
    _pass.clear();
    _name.clear();
    await _load();
  }
}
