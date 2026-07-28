import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kUrl = 'https://sreabyhmxetaynqqhlwe.supabase.co';
const kKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNyZWFieWhteGV0YXlucXFobHdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUyNzA3MjgsImV4cCI6MjEwMDg0NjcyOH0.a-5aEWl7FY9Q0CTK7AJVYvLCrW2MXNybfFFqh23xxN0';

const cGreen = Color(0xFF146C43);
const cDark = Color(0xFF152018);
const cGrey = Color(0xFF9AA79E);
const cBorder = Color(0xFFE5EAE5);
const cBg = Color(0xFFF4F6F4);
const cSafeBg = Color(0xFFE8F3E4);
const cAmber = Color(0xFFC2770F);
const cAmberBg = Color(0xFFFDF0E0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kUrl, anonKey: kKey);
  runApp(const GlutPassApp());
}

class GlutPassApp extends StatelessWidget {
  const GlutPassApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true, scaffoldBackgroundColor: cBg);
    return MaterialApp(
      title: 'GlutPass',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: base.copyWith(
        textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
      ),
      builder: (_, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const HomeScreen(),
    );
  }
}

class Place {
  final String id, nameAr, safety;
  final String? nameEn, cuisine, branch, logoLetter, logoColor;
  final double? pct;
  final int votes, dishes;

  Place.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        nameAr = m['name_ar'] as String,
        nameEn = m['name_en'] as String?,
        cuisine = m['cuisine'] as String?,
        branch = m['branch_label'] as String?,
        logoLetter = m['logo_letter'] as String?,
        logoColor = m['logo_color'] as String?,
        safety = m['effective_safety_status'] as String,
        pct = (m['safe_experience_pct'] as num?)?.toDouble(),
        votes = (m['safety_votes_count'] as num?)?.toInt() ?? 0,
        dishes = (m['dishes_count'] as num?)?.toInt() ?? 0;

  bool get isSafe => safety == 'SEPARATE_PREP';
  String get badgeText => isSafe ? 'آمن للسيلياك' : 'تحقّق قبل الطلب';
  Color get badgeBg => isSafe ? cSafeBg : cAmberBg;
  Color get badgeFg => isSafe ? cGreen : cAmber;

  Color get avatarColor {
    final h = logoColor?.replaceAll('#', '');
    if (h == null || h.length != 6) return cGreen;
    return Color(int.parse('FF$h', radix: 16));
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Place>> _future;
  String _city = 'الكل';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Place>> _load() async {
    var q = Supabase.instance.client
        .from('places')
        .select('id,name_ar,name_en,cuisine,branch_label,logo_letter,'
            'logo_color,effective_safety_status,safe_experience_pct,'
            'safety_votes_count,dishes_count')
        .eq('status', 'published');
    if (_city != 'الكل') q = q.eq('city', _city);
    final rows = await q.order('safety_votes_count', ascending: false);
    return (rows as List)
        .map((e) => Place.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<Place>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: cGreen));
            }
            if (snap.hasError) {
              return _ErrorBox(error: '${snap.error}', onRetry: _refresh);
            }
            final places = snap.data ?? [];
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                const _Header(),
                const SizedBox(height: 12),
                const _SearchBar(),
                const SizedBox(height: 16),
                _Stats(places: places),
                const SizedBox(height: 16),
                const _Legend(),
                const SizedBox(height: 16),
                _CityChips(
                  selected: _city,
                  onSelect: (c) {
                    setState(() => _city = c);
                    _refresh();
                  },
                ),
                const SizedBox(height: 20),
                const _SectionTitle(),
                const SizedBox(height: 10),
                if (places.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('لا توجد أماكن في هذه المدينة بعد',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cGrey)),
                  ),
                ...places.map((p) => _PlaceCard(place: p)),
                const SizedBox(height: 28),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      color: cGreen,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(14)),
            child:
                const Icon(Icons.person_outline, color: Colors.white, size: 22),
          ),
          const Spacer(),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('GlutPass',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text('مجتمع خالي من الجلوتين',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.eco, color: cGreen, size: 26),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cBorder)),
      child: const Row(
        children: [
          Expanded(
            child: Text('ابحث عن مطعم أو طبق...',
                style: TextStyle(color: cGrey, fontSize: 14)),
          ),
          Icon(Icons.search, color: cGrey, size: 20),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final List<Place> places;
  const _Stats({required this.places});

  @override
  Widget build(BuildContext context) {
    final dishes = places.fold<int>(0, (s, p) => s + p.dishes);
    final votes = places.fold<int>(0, (s, p) => s + p.votes);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _stat('$votes', 'تجربة'),
          const SizedBox(width: 10),
          _stat('$dishes', 'طبق'),
          const SizedBox(width: 10),
          _stat('${places.length}', 'مطعم'),
        ],
      ),
    );
  }

  Widget _stat(String n, String label) => Expanded(
        child: Container(
          height: 52,
          decoration: BoxDecoration(
              color: cSafeBg, borderRadius: BorderRadius.circular(14)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(n,
                  style: const TextStyle(
                      color: cGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text(label, style: const TextStyle(color: cGreen, fontSize: 11)),
            ],
          ),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(cSafeBg, cGreen, Icons.check,
            'منطقة تحضير منفصلة — آمنة للسيلياك'),
        const SizedBox(height: 6),
        _row(cAmberBg, cAmber, Icons.warning_amber_rounded,
            'مشتركة / غير معروفة — تحقّق قبل الطلب'),
      ],
    );
  }

  Widget _row(Color bg, Color fg, IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(text, style: TextStyle(color: fg, fontSize: 12)),
              const SizedBox(width: 6),
              Icon(icon, color: fg, size: 14),
            ],
          ),
        ),
      );
}

class _CityChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _CityChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const cities = ['الكل', 'الرياض', 'جدة', 'الدمام'];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: cities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = cities[i];
          final on = c == selected;
          return GestureDetector(
            onTap: () => onSelect(c),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: on ? cGreen : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: on ? cGreen : cBorder),
              ),
              child: Text(c,
                  style: TextStyle(
                      color: on ? Colors.white : cDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text('عرض الكل', style: TextStyle(color: cGreen, fontSize: 13)),
          Spacer(),
          Text('الأكثر تصويتا',
              style: TextStyle(
                  color: cDark, fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final Place place;
  const _PlaceCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: place.badgeBg, borderRadius: BorderRadius.circular(13)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(place.badgeText,
                    style: TextStyle(
                        color: place.badgeFg,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(place.isSafe ? Icons.check : Icons.info_outline,
                    color: place.badgeFg, size: 12),
              ],
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(place.nameAr,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cDark)),
              if (place.nameEn != null)
                Text(place.nameEn!,
                    style: const TextStyle(fontSize: 11, color: cGrey)),
              const SizedBox(height: 2),
              Text('${place.cuisine ?? ''} · ${place.branch ?? ''}',
                  style: const TextStyle(fontSize: 12, color: cGrey)),
              const SizedBox(height: 5),
              Row(
                children: [
                  ...List.generate(
                      5,
                      (i) => const Padding(
                            padding: EdgeInsets.only(left: 1),
                            child: Icon(Icons.star,
                                size: 10, color: Color(0xFFC7CFC9)),
                          )),
                  const SizedBox(width: 6),
                  Text(
                    place.pct == null
                        ? 'تجارب قليلة — يحتاج تأكيد'
                        : '${place.pct!.toStringAsFixed(0)}٪ بلا أعراض · ${place.votes} تجربة',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: place.badgeFg),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: place.avatarColor, shape: BoxShape.circle),
            child: Text(place.logoLetter ?? '؟',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBox({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: cGrey, size: 40),
            const SizedBox(height: 12),
            const Text('تعذّر الاتصال بقاعدة البيانات',
                style: TextStyle(fontWeight: FontWeight.w700, color: cDark)),
            const SizedBox(height: 6),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: cGrey)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: cGreen),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
