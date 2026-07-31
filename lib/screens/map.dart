import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';
import 'details.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mc = MapController();
  late Future<List<_Pin>> _f;
  String _city = 'الكل';
  _Pin? _sel;

  static const _riyadh = LatLng(24.7136, 46.6753);

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<List<_Pin>> _load() async {
    var q = Supabase.instance.client
        .from('places')
        .select('${Place.cols},lat,lng')
        .eq('status', 'published')
        .not('lat', 'is', null);
    if (_city != 'الكل') q = q.eq('city', _city);
    final r = await q;
    return (r as List)
        .map((e) => e as Map<String, dynamic>)
        .where((m) => m['lat'] != null && m['lng'] != null)
        .map((m) => _Pin(
              Place.fromMap(m),
              LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()),
            ))
        .toList();
  }

  void _pick(String c) {
    setState(() {
      _city = c;
      _sel = null;
      _f = _load();
    });
  }

  void _fit(List<_Pin> pins) {
    if (pins.isEmpty) return;
    if (pins.length == 1) {
      _mc.move(pins.first.at, 14);
      return;
    }
    double minLa = 90, maxLa = -90, minLo = 180, maxLo = -180;
    for (final p in pins) {
      minLa = p.at.latitude < minLa ? p.at.latitude : minLa;
      maxLa = p.at.latitude > maxLa ? p.at.latitude : maxLa;
      minLo = p.at.longitude < minLo ? p.at.longitude : minLo;
      maxLo = p.at.longitude > maxLo ? p.at.longitude : maxLo;
    }
    _mc.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds(LatLng(minLa, minLo), LatLng(maxLa, maxLo)),
      padding: const EdgeInsets.fromLTRB(50, 120, 50, 190),
    ));
  }

  @override
  Widget build(BuildContext ctx) {
    return FutureBuilder<List<_Pin>>(
      future: _f,
      builder: (ctx, s) {
        final pins = s.data ?? [];
        final loading = s.connectionState == ConnectionState.waiting;
        return Stack(children: [
          FlutterMap(
            mapController: _mc,
            options: MapOptions(
              initialCenter: pins.isEmpty ? _riyadh : pins.first.at,
              initialZoom: 11,
              minZoom: 4,
              maxZoom: 18,
              onTap: (_, __) => setState(() => _sel = null),
              onMapReady: () => _fit(pins),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.glutpass.glutpass',
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: pins
                    .map((p) => Marker(
                          point: p.at,
                          width: 54,
                          height: 62,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => setState(() => _sel = p),
                            child: _marker(p, _sel?.place.id == p.place.id),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
          Positioned(
            top: 10,
            right: 0,
            left: 0,
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 1 + Cities.all.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = i == 0 ? 'الكل' : Cities.all[i - 1];
                  final on = c == _city;
                  return GestureDetector(
                    onTap: () => _pick(c),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: on ? cGreen : Colors.white,
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: on ? cGreen : cBorder),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ],
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
            ),
          ),
          if (loading)
            const Positioned(
              top: 60,
              right: 0,
              left: 0,
              child: Center(
                child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        color: cGreen, strokeWidth: 2.6)),
              ),
            ),
          if (!loading && pins.isEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cBorder)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.location_off_outlined,
                      color: cGrey, size: 32),
                  const SizedBox(height: 10),
                  Text(
                      _city == 'الكل'
                          ? 'لا توجد أماكن محدّدة على الخريطة بعد'
                          : 'لا توجد أماكن محدّدة في $_city',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: cDark, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('الأماكن التي حُدّد موقعها فقط تظهر هنا',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cGrey, fontSize: 11)),
                ]),
              ),
            ),
          Positioned(
            bottom: 4,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.white70,
              child: const Text('© OpenStreetMap',
                  style: TextStyle(fontSize: 9, color: cGrey)),
            ),
          ),
          if (_sel != null)
            Positioned(
              bottom: 92,
              right: 14,
              left: 14,
              child: _card(ctx, _sel!),
            ),
        ]);
      },
    );
  }

  Widget _marker(_Pin p, bool on) {
    final c = p.place.badgeFg;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: on ? 48 : 40,
        height: on ? 48 : 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Container(
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          padding: const EdgeInsets.all(1.5),
          child: PlaceAvatar(p.place, size: on ? 38 : 30),
        ),
      ),
      Transform.translate(
        offset: const Offset(0, -3),
        child: Icon(Icons.arrow_drop_down, color: c, size: 20),
      ),
    ]);
  }

  Widget _card(BuildContext ctx, _Pin p) => GestureDetector(
        onTap: () async {
          await Navigator.push(ctx,
              MaterialPageRoute(builder: (_) => DetailsScreen(p.place)));
          if (mounted) setState(() => _f = _load());
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(children: [
            PlaceAvatar(p.place, size: 50),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.place.nameAr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: cDark)),
                    Text('${p.place.cuisine ?? ''} · ${p.place.branch ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: cGrey)),
                    const SizedBox(height: 5),
                    SafetyBadge(p.place),
                  ]),
            ),
            const Icon(Icons.arrow_back_ios, size: 15, color: cGrey),
          ]),
        ),
      );
}

class _Pin {
  final Place place;
  final LatLng at;
  _Pin(this.place, this.at);
}
