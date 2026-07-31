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
      if (mounted) {
        setState(() {
          _me = null;
          _saved = [];
        });
      }
      return;
    }
    try {
      final p = await c
          .from('profiles')
          .select('full_name,city,is_celiac')
          .eq('id', u.id)
          .maybeSingle();
      final v = await c.from('votes').select('id').eq('user_id', u.id);
      final subs = await c
          .from('place_submissions')
          .select('id')
          .eq('submitted_by', u.id);
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
    setState(() {
      _busy = true;
      _msg = null;
    });
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

  @override
  Widget build(BuildContext ctx) => _me == null ? _form() : _profile(ctx);

  Widget _profile(BuildContext ctx) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: cGreen, shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 14),
          Text(_me!['name'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: cDark)),
          const SizedBox(height: 4),
          Text(_me!['email'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: cGrey)),
          const SizedBox(height: 20),
          Row(children: [
            _stat('${_me!['votes']}', 'تصويت'),
            const SizedBox(width: 10),
            _stat('${_me!['subs']}', 'أضفتها'),
            const SizedBox(width: 10),
            _stat('${_saved.length}', 'محفوظة'),
          ]),
          const SizedBox(height: 14),
          if (_me!['celiac'] == true)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: cSafeBg, borderRadius: BorderRadius.circular(14)),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: cGreen, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text('مصاب بحساسية القمح — أصواتك بوزن مضاعف',
                          style: TextStyle(color: cGreen, fontSize: 12)),
                    ),
                  ]),
            ),
          const SizedBox(height: 24),
          const Row(children: [
            Text('أماكني المحفوظة',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: cDark)),
          ]),
          const SizedBox(height: 10),
          if (_saved.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('لم تحفظ أي مكان بعد — اضغط 🔖 في صفحة المطعم',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cGrey, fontSize: 12)),
            ),
          ..._saved.map((p) => GestureDetector(
                onTap: () async {
                  await Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => DetailsScreen(p)));
                  _load();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cBorder)),
                  child: Row(children: [
                    PlaceAvatar(p, size: 44),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.nameAr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: cDark)),
                            Text('${p.cuisine ?? ''} · ${p.branch ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: cGrey)),
                          ]),
                    ),
                    const SizedBox(width: 8),
                    SafetyBadge(p),
                  ]),
                ),
              )),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _out,
            style: OutlinedButton.styleFrom(
                foregroundColor: cAmber,
                side: const BorderSide(color: cBorder),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: const Text('تسجيل الخروج'),
          ),
          const SizedBox(height: 90),
        ],
      );

  Widget _stat(String a, String b) => Expanded(
        child: Container(
          height: 62,
          decoration: BoxDecoration(
              color: cSafeBg, borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(a,
                style: const TextStyle(
                    color: cGreen, fontSize: 17, fontWeight: FontWeight.w700)),
            Text(b, style: const TextStyle(color: cGreen, fontSize: 11)),
          ]),
        ),
      );

  Widget _form() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.eco, color: cGreen, size: 52),
          const SizedBox(height: 12),
          Text(_signup ? 'انضم إلى مجتمع GlutPass' : 'مرحباً بعودتك',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w700, color: cDark)),
          const SizedBox(height: 6),
          Text(
              _signup
                  ? 'أنشئ حسابك وابدأ بالمساهمة خلال دقيقة'
                  : 'سجّل دخولك لمتابعة مساهماتك في المجتمع',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: cGrey)),
          const SizedBox(height: 24),
          if (_signup) ...[
            _field(_name, 'الاسم الكامل', 'اكتب اسمك'),
            const SizedBox(height: 14),
          ],
          _field(_email, 'البريد الإلكتروني', 'example@email.com'),
          const SizedBox(height: 14),
          _field(_pass, 'كلمة المرور', '٦ أحرف على الأقل', hide: true),
          if (_signup) ...[
            const SizedBox(height: 14),
            const Row(children: [
              Text('المدينة',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cDark)),
            ]),
            const SizedBox(height: 6),
            Row(
                children: ['الرياض', 'جدة', 'الدمام'].map((c) {
              final on = c == _city;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _city = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: on ? cGreen : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: on ? cGreen : cBorder)),
                    child: Text(c,
                        style: TextStyle(
                            color: on ? Colors.white : cDark, fontSize: 13)),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => setState(() => _celiac = !_celiac),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _celiac ? cSafeBg : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _celiac ? cGreen : cBorder)),
                child: Row(children: [
                  Icon(
                      _celiac
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: _celiac ? cGreen : cGrey,
                      size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('أنا مصاب بحساسية القمح (السيلياك)',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cDark)),
                          Text('لعرض تنبيهات الأمان بشكل أوضح',
                              style: TextStyle(fontSize: 11, color: cGrey)),
                        ]),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
                backgroundColor: cGreen,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(_signup ? 'إنشاء الحساب' : 'تسجيل الدخول',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 12),
            Text(_msg!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: cAmber, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {
              _signup = !_signup;
              _msg = null;
            }),
            child: Text(
                _signup
                    ? 'لديك حساب؟ سجّل الدخول'
                    : 'ليس لديك حساب؟ أنشئ حساباً جديداً',
                style: const TextStyle(
                    color: cGreen, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 60),
        ],
      );

  Widget _field(TextEditingController c, String label, String hint,
          {bool hide = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: cDark)),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cBorder)),
          child: TextField(
            controller: c,
            obscureText: hide,
            textAlign: TextAlign.start,
            keyboardType:
                hide ? TextInputType.text : TextInputType.emailAddress,
            decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: cGrey, fontSize: 13)),
            style: const TextStyle(fontSize: 15, color: cDark),
          ),
        ),
      ]);
}
