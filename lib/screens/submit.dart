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
              child: const Icon(Icons.send_rounded, color: cGreen, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('وصلت مساهمتك',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: cDark)),
            const SizedBox(height: 8),
            const Text(
                'سيراجعها فريق الإشراف قبل إضافتها للدليل، ونخبرك بالنتيجة.',
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
          const SizedBox(height: 22),
          _label('اسم المكان'),
          _input(_name, 'مثال: مطعم لوسين'),
          const SizedBox(height: 16),
          _label('المدينة'),
          _pills(
              ['الرياض', 'جدة', 'الدمام'], _city, (v) => setState(() => _city = v)),
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
                : const Text('إضافة المكان',
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
