import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
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
  late String _city;
  String _type = 'restaurant';
  String _safety = 'UNKNOWN';
  bool _busy = false;
  bool _done = false;
  bool _upLogo = false;
  String? _msg;
  String? _logoUrl;
  Uint8List? _logoPreview;
  LatLng? _at;

  @override
  void initState() {
    super.initState();
    _city = Cities.all.isNotEmpty ? Cities.all.first : 'الرياض';
  }

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

  Future<void> _pickLogo(ImageSource src) async {
    final c = Supabase.instance.client;
    final u = c.auth.currentUser;
    if (u == null) {
      setState(() => _msg = 'سجّل الدخول من تبويب «حسابي» أولاً');
      return;
    }
    try {
      final x = await ImagePicker()
          .pickImage(source: src, maxWidth: 600, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        setState(() => _msg = 'الصورة أكبر من ٢ ميجابايت');
        return;
      }
      setState(() {
        _logoPreview = bytes;
        _upLogo = true;
        _msg = null;
      });
      final path =
          'submissions/${u.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await c.storage.from('places').uploadBinary(path, bytes,
          fileOptions: const FileOptions(
              upsert: true, contentType: 'image/jpeg'));
      final url = c.storage.from('places').getPublicUrl(path);
      if (mounted) {
        setState(() {
          _logoUrl = url;
          _upLogo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _upLogo = false;
          _logoPreview = null;
          _msg = '$e';
        });
      }
    }
  }

  void _logoSheet() {
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
              _pickLogo(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: cGreen),
            title: const Text('التقاط صورة',
                style: TextStyle(fontSize: 14, color: cDark)),
            onTap: () {
              Navigator.pop(sctx);
              _pickLogo(ImageSource.camera);
            },
          ),
          if (_logoPreview != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: cAmber),
              title: const Text('حذف الشعار',
                  style: TextStyle(fontSize: 14, color: cAmber)),
              onTap: () {
                Navigator.pop(sctx);
                setState(() {
                  _logoPreview = null;
                  _logoUrl = null;
                });
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pickLocation() async {
    final r = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
          builder: (_) => LocationPicker(initial: _at, query: _name.text)),
    );
    if (r != null && mounted) setState(() => _at = r);
  }

  Future<void> _addCity() async {
    final ctl = TextEditingController();
    String? err;
    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('إضافة مدينة',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctl,
              autofocus: true,
              textAlign: TextAlign.start,
              decoration: InputDecoration(
                hintText: 'اسم المدينة',
                hintStyle: const TextStyle(color: cGrey, fontSize: 13),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: cBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: cGreen)),
              ),
            ),
            if (err != null) ...[
              const SizedBox(height: 10),
              Text(err!,
                  style: const TextStyle(color: cAmber, fontSize: 12)),
            ],
            const SizedBox(height: 10),
            const Text('تُضاف للجميع — تأكّد من الإملاء',
                style: TextStyle(color: cGrey, fontSize: 11)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: const Text('إلغاء',
                    style: TextStyle(color: cGrey))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cGreen),
              onPressed: () async {
                final e = await Cities.add(ctl.text);
                if (e != null) {
                  setD(() => err = e);
                  return;
                }
                if (dctx.mounted) Navigator.pop(dctx);
                if (mounted) setState(() => _city = ctl.text.trim());
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

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
    if (_upLogo) {
      setState(() => _msg = 'انتظر اكتمال رفع الشعار');
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
        'logo_url': _logoUrl,
        'lat': _at?.latitude,
        'lng': _at?.longitude,
        'submitted_by': u.id,
      });
      setState(() => _done = true);
    } catch (e) {
      setState(() => _msg = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(child: _done ? _thanks(ctx) : _form(ctx)),
    );
  }

  Widget _thanks(BuildContext ctx) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 90,
              height: 90,
              alignment: Alignment.center,
              decoration:
                  const BoxDecoration(color: cSafeBg, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: cGreen, size: 46),
            ),
            const SizedBox(height: 20),
            const Text('نُشر المكان',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: cDark)),
            const SizedBox(height: 8),
            const Text(
                'ظهر في الدليل مباشرةً. شكراً لمساهمتك — '
                'وتصنيف الأمان يتحدّث تلقائياً كلما صوّت أحد على تجربته.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cGrey, height: 1.6)),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                  backgroundColor: cGreen,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text('رجوع'),
            ),
          ]),
        ),
      );

  Widget _logoPicker() => Center(
        child: GestureDetector(
          onTap: _logoSheet,
          child: Column(children: [
            Stack(alignment: Alignment.center, children: [
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: cBorder, width: 1.5),
                  image: _logoPreview == null
                      ? null
                      : DecorationImage(
                          image: MemoryImage(_logoPreview!),
                          fit: BoxFit.cover),
                ),
                child: _logoPreview == null
                    ? const Icon(Icons.storefront_outlined,
                        color: cGrey, size: 34)
                    : null,
              ),
              if (_upLogo)
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.35)),
                  child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.4)),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: cGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
                _logoPreview == null
                    ? 'أضف شعار المكان (اختياري)'
                    : _upLogo
                        ? 'جارِ الرفع…'
                        : 'اضغط لتغيير الشعار',
                style: const TextStyle(fontSize: 12, color: cGrey)),
          ]),
        ),
      );

  Widget _locBox() => GestureDetector(
        onTap: _pickLocation,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _at == null ? Colors.white : cSafeBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _at == null ? cBorder : cGreen)),
          child: Row(children: [
            Icon(_at == null ? Icons.add_location_alt_outlined : Icons.place,
                color: _at == null ? cGrey : cGreen, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_at == null ? 'حدّد موقع المكان' : 'الموقع محدّد',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _at == null ? cDark : cGreen)),
                    const SizedBox(height: 2),
                    Text(
                        _at == null
                            ? 'ابحث بالاسم أو ضع الدبوس يدوياً — لن يظهر على الخريطة بدونه'
                            : '${_at!.latitude.toStringAsFixed(5)} , ${_at!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11, color: cGrey)),
                  ]),
            ),
            const Icon(Icons.arrow_back_ios, size: 14, color: cGrey),
          ]),
        ),
      );

  Widget _form(BuildContext ctx) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.arrow_back_ios, size: 18, color: cDark)),
            const Spacer(),
            const Text('إضافة مكان جديد',
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w700, color: cDark)),
            const Spacer(),
            const SizedBox(width: 44),
          ]),
          const SizedBox(height: 4),
          const Text('ساهم في إثراء الدليل — أضف مكاناً جرّبته',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cGrey)),
          const SizedBox(height: 20),
          _logoPicker(),
          const SizedBox(height: 22),
          _label('اسم المكان'),
          _input(_name, 'مثال: مطعم لوسين'),
          const SizedBox(height: 16),
          _label('الموقع'),
          _locBox(),
          const SizedBox(height: 16),
          Row(children: [
            const Text('المدينة',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: cDark)),
            const Spacer(),
            GestureDetector(
              onTap: _addCity,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 15, color: cGreen),
                SizedBox(width: 3),
                Text('مدينة جديدة',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: cGreen,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          _cityWrap(),
          const SizedBox(height: 16),
          _label('نوع المكان'),
          _pills(types.keys.toList(), _type, (v) => setState(() => _type = v),
              labels: types),
          const SizedBox(height: 18),
          _label('مستوى الأمان (حسب تجربتك)'),
          const SizedBox(height: 2),
          ...levels.entries.map((e) {
            final on = _safety == e.key;
            final c = _lvColor(e.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => setState(() => _safety = e.key),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                      color: on ? c.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: on ? c : cBorder, width: on ? 1.5 : 1)),
                  child: Row(children: [
                    Icon(
                        on
                            ? Icons.radio_button_checked
                            : Icons.circle_outlined,
                        color: on ? c : cGrey,
                        size: 19),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.value,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  on ? FontWeight.w700 : FontWeight.w500,
                              color: on ? c : cDark)),
                    ),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          _label('أطباق آمنة مقترحة'),
          _input(_dishes, 'افصل بين الأطباق بفاصلة'),
          const SizedBox(height: 16),
          _label('ملاحظات (اختياري)'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cBorder)),
            child: TextField(
              controller: _note,
              maxLines: 3,
              textAlign: TextAlign.start,
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'الفرع، وما لاحظته عن التحضير...',
                  hintStyle: TextStyle(color: cGrey, fontSize: 13)),
              style: const TextStyle(fontSize: 14, color: cDark),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _send,
            style: FilledButton.styleFrom(
                backgroundColor: cGreen,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('نشر المكان',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 12),
            Text(_msg!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: cAmber, fontSize: 12)),
          ],
          const SizedBox(height: 40),
        ],
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Text(t,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: cDark)),
        ]),
      );

  Widget _input(TextEditingController c, String hint) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cBorder)),
        child: TextField(
          controller: c,
          textAlign: TextAlign.start,
          decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(color: cGrey, fontSize: 13)),
          style: const TextStyle(fontSize: 15, color: cDark),
        ),
      );

  Widget _cityWrap() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: Cities.all.map((c) {
          final on = c == _city;
          return GestureDetector(
            onTap: () => setState(() => _city = c),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                  color: on ? cGreen : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: on ? cGreen : cBorder)),
              child: Text(c,
                  style: TextStyle(
                      color: on ? Colors.white : cDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          );
        }).toList(),
      );

  Widget _pills(List<String> keys, String sel, ValueChanged<String> onTap,
          {Map<String, String>? labels}) =>
      Row(
          children: keys.map((k) {
        final on = k == sel;
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: GestureDetector(
            onTap: () => onTap(k),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                  color: on ? cGreen : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: on ? cGreen : cBorder)),
              child: Text(labels?[k] ?? k,
                  style: TextStyle(
                      color: on ? Colors.white : cDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        );
      }).toList());
}

/// شاشة تحديد الموقع — بحث بالاسم أو دبوس يدوي
class LocationPicker extends StatefulWidget {
  final LatLng? initial;
  final String query;
  const LocationPicker({super.key, this.initial, this.query = ''});
  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _mc = MapController();
  final _q = TextEditingController();
  LatLng _at = const LatLng(24.7136, 46.6753);
  List<Map<String, dynamic>> _hits = [];
  bool _searching = false;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _at = widget.initial!;
    _q.text = widget.query.trim();
  }

  Future<void> _search() async {
    final q = _q.text.trim();
    if (q.length < 2) return;
    setState(() {
      _searching = true;
      _open = true;
    });
    try {
      final r = await Supabase.instance.client.functions.invoke(
        'place-search',
        body: {'q': q, 'lat': _at.latitude, 'lng': _at.longitude},
      );
      final data = r.data;
      final list = (data is Map && data['results'] is List)
          ? (data['results'] as List).cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _hits = list);
    } catch (_) {
      if (mounted) setState(() => _hits = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _goto(Map<String, dynamic> h) {
    final p = LatLng((h['lat'] as num).toDouble(), (h['lng'] as num).toDouble());
    setState(() {
      _at = p;
      _open = false;
      _hits = [];
    });
    _mc.move(p, 16);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(children: [
              IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.arrow_back_ios,
                      size: 18, color: cDark)),
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cBorder)),
                  child: Row(children: [
                    const Icon(Icons.search, size: 19, color: cGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _q,
                        textAlign: TextAlign.start,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: 'ابحث باسم المطعم أو الحي…',
                            hintStyle:
                                TextStyle(color: cGrey, fontSize: 13)),
                        style: const TextStyle(fontSize: 14, color: cDark),
                      ),
                    ),
                    if (_searching)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: cGreen, strokeWidth: 2))
                    else
                      GestureDetector(
                        onTap: _search,
                        child: const Text('بحث',
                            style: TextStyle(
                                color: cGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(
            child: Stack(children: [
              FlutterMap(
                mapController: _mc,
                options: MapOptions(
                  initialCenter: _at,
                  initialZoom: widget.initial == null ? 11 : 16,
                  minZoom: 4,
                  maxZoom: 18,
                  onPositionChanged: (pos, _) {
                    _at = pos.center;
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.glutpass.glutpass',
                    maxNativeZoom: 19,
                  ),
                ],
              ),
              // الدبوس ثابت في المنتصف — الخريطة هي التي تتحرك تحته
              IgnorePointer(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: const Icon(Icons.location_on,
                        color: cGreen, size: 44),
                  ),
                ),
              ),
              if (_open && _hits.isNotEmpty)
                Positioned(
                  top: 0,
                  right: 10,
                  left: 10,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cBorder),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12)
                        ]),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _hits.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1, color: cBorder, indent: 12, endIndent: 12),
                      itemBuilder: (_, i) {
                        final h = _hits[i];
                        return ListTile(
                          dense: true,
                          leading:
                              const Icon(Icons.place_outlined, color: cGreen),
                          title: Text('${h['name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: cDark)),
                          subtitle: Text('${h['detail'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: cGrey)),
                          onTap: () => _goto(h),
                        );
                      },
                    ),
                  ),
                ),
              if (_open && !_searching && _hits.isEmpty)
                Positioned(
                  top: 0,
                  right: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cBorder)),
                    child: const Text(
                        'لا نتائج — حرّك الخريطة وضع الدبوس على الموقع يدوياً',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: cGrey)),
                  ),
                ),
              Positioned(
                bottom: 2,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: Colors.white70,
                  child: const Text('© OpenStreetMap',
                      style: TextStyle(fontSize: 9, color: cGrey)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(children: [
              const Text('ضع الدبوس على مدخل المكان بدقة',
                  style: TextStyle(fontSize: 11.5, color: cGrey)),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, _at),
                style: FilledButton.styleFrom(
                    backgroundColor: cGreen,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                child: const Text('تأكيد الموقع',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
