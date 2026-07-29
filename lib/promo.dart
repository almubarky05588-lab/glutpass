import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core.dart';
import 'screens/details.dart';

/// الشريط الإعلاني المتحرك أعلى الشاشة الرئيسية.
/// يقرأ من جدول banners — وسياسات الحماية تُظهر النشط ضمن فترته فقط.
class PromoBanner extends StatefulWidget {
  const PromoBanner({super.key});
  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  final _pc = PageController();
  List<Map<String, dynamic>> _b = [];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Supabase.instance.client
          .from('banners')
          .select('id,title_ar,image_url,place_id')
          .order('sort_order', ascending: true);
      if (!mounted) return;
      setState(() => _b = (r as List).cast<Map<String, dynamic>>());
      if (_b.length > 1) {
        _timer = Timer.periodic(const Duration(seconds: 5), (_) {
          if (!mounted || !_pc.hasClients) return;
          _pc.animateToPage((_i + 1) % _b.length,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOut);
        });
      }
    } catch (_) {
      // لا بنرات أو فشل شبكة — لا يظهر شيء ولا ينكسر شيء
    }
  }

  Future<void> _open(String? placeId) async {
    if (placeId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('places')
          .select(Place.cols)
          .eq('id', placeId)
          .single();
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DetailsScreen(Place.fromMap(row))));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_b.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      SizedBox(
        height: 132,
        child: PageView.builder(
          controller: _pc,
          itemCount: _b.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) {
            final b = _b[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => _open(b['place_id'] as String?),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    b['image_url'] as String,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (_, child, p) =>
                        p == null ? child : Container(color: cBorder),
                    errorBuilder: (_, __, ___) => Container(
                      color: cGreen,
                      alignment: Alignment.center,
                      child: Text(b['title_ar'] as String? ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      if (_b.length > 1) ...[
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _b.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _i ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                  color: i == _i ? cGreen : cBorder,
                  borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ),
      ],
    ]);
  }
}
