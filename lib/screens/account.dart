import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';
import '../push.dart';
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
  bool _pushBusy = false;
  String? _msg;
  Map<String, dynamic>? _me;
  List<Place> _saved = [];

  @override
  void initState() {
    super.initState();
    _city = Cities.all.isNotEmpty ? Cities.all.first : 'الرياض';
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
          .select('full_name,city,is_celiac,gender,avatar_url')
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
            'gender': p?['gender'],
            'avatar': p?['avatar_url'],
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

  void _toast(String t, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t, style: const TextStyle(fontSize: 13)),
      backgroundColor: ok ? cGreen : cAmber,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ــــــــ الإشعارات ــــــــ

  Future<void> _pushTap() async {
    setState(() => _pushBusy = true);
    await Push.ensure();
    if (!mounted) return;
    setState(() => _pushBusy = false);
    if (Push.saved) {
      _toast('الإشعارات جاهزة', ok: true);
    } else {
      _showDiag();
    }
  }

  void _showDiag() {
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('تشخيص الإشعارات',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: SelectableText(
            Push.report(),
            textAlign: TextAlign.start,
            style: const TextStyle(
                fontSize: 12.5, color: cDark, height: 1.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: Push.report()));
              Navigator.pop(dctx);
              _toast('نُسخ التقرير', ok: true);
            },
            child: const Text('نسخ', style: TextStyle(color: cGreen)),
          ),
          TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('إغلاق', style: TextStyle(color: cGrey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cGreen),
            onPressed: () {
              Navigator.pop(dctx);
              _pushTap();
            },
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  // ــــــــ إعدادات الحساب ــــــــ

  Future<void> _pickAvatar(ImageSource src) async {
    final c = Supabase.instance.client;
    final u = c.auth.currentUser;
    if (u == null) return;
    try {
      final x = await ImagePicker()
          .pickImage(source: src, maxWidth: 720, imageQuality: 82);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        _toast('الصورة أكبر من ٢ ميجابايت');
        return;
      }
      final path = '${u.id}/avatar.jpg';
      await c.storage.from('avatars').uploadBinary(path, bytes,
          fileOptions: const FileOptions(
              upsert: true, contentType: 'image/jpeg'));
      final base = c.storage.from('avatars').getPublicUrl(path);
      final url = '$base?v=${DateTime.now().millisecondsSinceEpoch}';
      await c.from('profiles').update({'avatar_url': url}).eq('id', u.id);
      await _load();
      _toast('تم تحديث الصورة', ok: true);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _removeAvatar() async {
    final c = Supabase.instance.client;
    final u = c.auth.currentUser;
    if (u == null) return;
    try {
      await c.storage.from('avatars').remove(['${u.id}/avatar.jpg']);
    } catch (_) {}
    try {
      await c.from('profiles').update({'avatar_url': null}).eq('id', u.id);
      await _load();
      _toast('حُذفت الصورة', ok: true);
    } catch (e) {
      _toast('$e');
    }
  }

  void _avatarSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                  color: cBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: cGreen),
            title: const Text('اختيار من الصور',
                style: TextStyle(fontSize: 14, color: cDark)),
            onTap: () {
              Navigator.pop(sctx);
              _pickAvatar(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: cGreen),
            title: const Text('التقاط صورة',
                style: TextStyle(fontSize: 14, color: cDark)),
            onTap: () {
              Navigator.pop(sctx);
              _pickAvatar(ImageSource.camera);
            },
          ),
          if (_me?['avatar'] != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: cAmber),
              title: const Text('حذف الصورة',
                  style: TextStyle(fontSize: 14, color: cAmber)),
              onTap: () {
                Navigator.pop(sctx);
                _removeAvatar();
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _setField(String key, dynamic val) async {
    final c = Supabase.instance.client;
    final u = c.auth.currentUser;
    if (u == null) return;
    try {
      await c.from('profiles').update({key: val}).eq('id', u.id);
      await _load();
      _toast('تم الحفظ', ok: true);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _editName() async {
    final ctl = TextEditingController(text: _me?['name'] as String? ?? '');
    final v = await _prompt('الاسم الكامل', ctl, 'اكتب اسمك');
    if (v == null || v.trim().isEmpty) return;
    await _setField('full_name', v.trim());
  }

  Future<void> _changeEmail() async {
    final ctl = TextEditingController();
    final v = await _prompt('البريد الجديد', ctl, 'example@email.com',
        note: 'سيصلك رابط تأكيد على البريدين القديم والجديد. '
            'لا يتغيّر البريد حتى تضغط الرابط.');
    if (v == null || v.trim().isEmpty) return;
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(email: v.trim()));
      _toast('أُرسل رابط التأكيد — راجع بريدك', ok: true);
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('$e');
    }
  }

  Future<String?> _prompt(String title, TextEditingController ctl, String hint,
      {String? note}) {
    return showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctl,
            autofocus: true,
            textAlign: TextAlign.start,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: cGrey, fontSize: 13),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: cBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: cGreen)),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 12),
            Text(note,
                style: const TextStyle(
                    color: cGrey, fontSize: 11.5, height: 1.6)),
          ],
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('إلغاء', style: TextStyle(color: cGrey))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cGreen),
            onPressed: () => Navigator.pop(dctx, ctl.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext ctx) => _me == null ? _form() : _profile(ctx);

  Widget _avatar() {
    final url = _me?['avatar'] as String?;
    return GestureDetector(
      onTap: _avatarSheet,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 92,
          height: 92,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: cGreen,
              shape: BoxShape.circle,
              image: url == null
                  ? null
                  : DecorationImage(
                      image: NetworkImage(url), fit: BoxFit.cover)),
          child: url == null
              ? const Icon(Icons.person, color: Colors.white, size: 42)
              : null,
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: cBorder)),
            child: const Icon(Icons.photo_camera_outlined,
                size: 16, color: cGreen),
          ),
        ),
      ]),
    );
  }

  Widget _profile(BuildContext ctx) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),
          Center(child: _avatar()),
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
            Text('إعدادات الحساب',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: cDark)),
          ]),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cBorder)),
            child: Column(children: [
              _tile(Icons.person_outline, 'الاسم',
                  _me!['name'] as String, _editName),
              _sep(),
              _tile(Icons.mail_outline, 'البريد الإلكتروني',
                  _me!['email'] as String, _changeEmail),
              _sep(),
              _pushRow(),
              _sep(),
              _genderRow(),
              _sep(),
              _cityRow(),
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

  Widget _sep() =>
      const Divider(height: 1, color: cBorder, indent: 14, endIndent: 14);

  Widget _tile(IconData ic, String label, String val, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Icon(ic, size: 19, color: cGrey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(fontSize: 11, color: cGrey)),
                    const SizedBox(height: 2),
                    Text(val,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5,
                            color: cDark,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
            const Icon(Icons.edit_outlined, size: 16, color: cGreen),
          ]),
        ),
      );

  Widget _pushRow() {
    final ok = Push.saved;
    return InkWell(
      onTap: _pushBusy ? null : _pushTap,
      onLongPress: _showDiag,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Icon(ok ? Icons.notifications_active : Icons.notifications_off,
              size: 19, color: ok ? cGreen : cGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الإشعارات',
                      style: TextStyle(fontSize: 11, color: cGrey)),
                  const SizedBox(height: 2),
                  Text(
                      ok
                          ? 'مفعّلة — جهازك مسجّل'
                          : _pushBusy
                              ? 'جارِ التسجيل…'
                              : 'غير مكتملة — اضغط للمحاولة',
                      style: TextStyle(
                          fontSize: 13.5,
                          color: ok ? cGreen : cDark,
                          fontWeight: FontWeight.w600)),
                  if (!ok && !_pushBusy) ...[
                    const SizedBox(height: 2),
                    Text(Push.step,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: cAmber)),
                  ],
                ]),
          ),
          if (_pushBusy)
            const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(color: cGreen, strokeWidth: 2))
          else if (ok)
            const Icon(Icons.check_circle, size: 18, color: cGreen)
          else
            const Icon(Icons.refresh, size: 18, color: cGrey),
        ]),
      ),
    );
  }

  Widget _genderRow() {
    final g = _me?['gender'] as String?;
    Widget opt(String key, String label, IconData ic) {
      final on = g == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setField('gender', key),
          child: Container(
            margin: const EdgeInsetsDirectional.only(end: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: on ? cSafeBg : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on ? cGreen : cBorder)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ic, size: 16, color: on ? cGreen : cGrey),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      color: on ? cGreen : cDark,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.wc_outlined, size: 19, color: cGrey),
              SizedBox(width: 10),
              Text('الجنس', style: TextStyle(fontSize: 11, color: cGrey)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              opt('male', 'ذكر', Icons.male),
              opt('female', 'أنثى', Icons.female),
            ]),
          ]),
    );
  }

  Widget _cityRow() {
    final city = (_me?['city'] as String?) ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.location_city_outlined, size: 19, color: cGrey),
              SizedBox(width: 10),
              Text('مدينتي', style: TextStyle(fontSize: 11, color: cGrey)),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Cities.all.map((c) {
                final on = c == city;
                return GestureDetector(
                  onTap: () => _setField('city', c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                        color: on ? cGreen : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: on ? cGreen : cBorder)),
                    child: Text(c,
                        style: TextStyle(
                            color: on ? Colors.white : cDark, fontSize: 12.5)),
                  ),
                );
              }).toList(),
            ),
          ]),
    );
  }

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Cities.all.map((c) {
                final on = c == _city;
                return GestureDetector(
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
                );
              }).toList(),
            ),
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
