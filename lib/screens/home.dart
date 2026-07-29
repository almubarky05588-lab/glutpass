import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';
import 'search.dart';

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
        .select(Place.cols)
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
    return FutureBuilder<List<Place>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: cGreen));
        }
        if (snap.hasError) {
          return _Error(msg: '${snap.error}', onRetry: _refresh);
        }
        final places = snap.data ?? [];
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            const _Header(),
            const SizedBox(height: 12),
            _SearchBar(onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()));
            }),
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
                }),
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
            ...places.map((p) => _Card(place: p)),
            const SizedBox(height: 100),
          ],
        );
      },
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
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 
