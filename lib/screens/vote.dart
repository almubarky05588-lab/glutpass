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
              child: const Icon(Icons.check_circle, color: cGreen, size: 50),
            ),
            const SizedBox(height: 20),
            const Text('شكراً لمساهمتك',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: cDark)),
            const SizedBox(height: 8),
            const Text(
                'تجربتك أُضيفت، وأُعيد حساب تصنيف الأمان لهذا المكان تلقائياً.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cGrey, height: 1.6)),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
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
            const SizedBox(width: 44),
            const Spacer(),
            const Text('قيّم تجربتك',
                style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w700, color: cDark)),
            const Spacer(),
            IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.arrow_forward_ios,
                    size: 18, color: cDark)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cBorder)),
            child: Row(children: [
              PlaceAvatar(widget.place, size: 46),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(widget.dish?.nameAr ?? widget.place.nameAr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: cDark)),
                      const SizedBox(height: 2),
                      Text(
                          widget.dish == null
                              ? (widget.place.branch ?? '')
                              : widget.place.nameAr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: cGrey)),
                    ]),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          const Row(children: [
            Text('هل كان آمناً عليك؟',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: cDark)),
          ]),
          const SizedBox(height: 10),
          ...opts.map((o) {
            final k = o[0];
            final on = _exp == k;
            final c = _color(k);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => setState(() {
                  _exp = k;
                  _msg = null;
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                      color: on ? c.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: on ? c : cBorder, width: on ? 1.6 : 1)),
                  child: Row(children: [
                    Icon(_icon(k), color: on ? c : cGrey, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(o[1],
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  on ? FontWeight.w700 : FontWeight.w500,
                              color: on ? c : cDark)),
                    ),
                    Icon(
                        on
                            ? Icons.radio_button_checked
                            : Icons.circle_outlined,
                        color: on ? c : cGrey,
                        size: 20),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 18),
          const Row(children: [
            Text('تقييمك العام (اختياري)',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: cDark)),
          ]),
          const SizedBox(height: 4),
          const Row(children: [
            Text('للطعم والخدمة — منفصل عن الأمان',
                style: TextStyle(fontSize: 11.5, color: cGrey)),
          ]),
          const SizedBox(height: 10),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final n = 5 - i;
                return IconButton(
                  onPressed: () => setState(() => _stars = n),
                  icon: Icon(_stars >= n ? Icons.star : Icons.star_border,
                      color: _stars >= n ? const Color(0xFFF2B01E) : cStar,
                      size: 34),
                );
              })),
          const SizedBox(height: 14),
          const Row(children: [
            Text('أضف تعليقاً (اختياري)',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: cDark)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cBorder)),
            child: TextField(
              controller: _comment,
              maxLines: 4,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'اكتب تفاصيل تجربتك...',
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
                : const Text('إرسال التقييم',
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
}
