import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // ── الفلاتر ──
  // النوع ظاهر دائماً، والمدينة والأمان داخل ورقة التصفية
  String _type = 'all'; // all | restaurant | cafe | bakery
  String _city = 'الكل';
  bool _safeOnly = false;

  _Pin? _sel;
  LatLng? _me;
  bool _locating = false;
  bool _mapReady = false;

  static const _riyadh = LatLng(24.7136, 46.6753);

  static const _types = [
    ['all', 'الكل'],
    ['restaurant', 'مطاعم'],
    ['cafe', 'مقاهي'],
    ['bakery', 'مخابز'],
  ];

  int get _activeFilters =>
      (_city == 'الكل' ? 0 : 1) + (_safeOnly ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _f = _load();
    // نطلب الموقع بهدوء عند الفتح — الرفض لا يعطّل شيئاً
    _locate(silent: true);
  }

  Future<List<_Pin>> _load() async {
    var q = Supabase.instance.client
        .from('places')
        .select('${Place.cols},lat,lng,address,place_type')
        .eq('status', 'published')
        .not('lat', 'is', null);
    if (_type != 'all') q = q.eq('place_type', _type);
    if (_city != 'الكل') q = q.eq('city', _city);
    if (_safeOnly) q = q.eq('effective_safety_status', 'SEPARATE_PREP');
    final r = await q;
    return (r as List)
        .map((e) => e as Map<String, dynamic>)
        .where((m) => m['lat'] != null && m['lng'] != null)
        .map((m) => _Pin(
              Place.fromMap(m),
              LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()),
              m['address'] as String?,
            ))
        .toList();
  }

  void _apply() {
    setState(() {
      _sel = null;
      _f = _load();
    });
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t, style: const TextStyle(fontSize: 13)),
      backgroundColor: cAmber,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// يحدّد موقع المستخدم. عند silent لا يزعجه برسائل إن رفض الإذن.
  Future<void> _locate({bool silent = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!silent) _snack('خدمة الموقع مغلقة في جهازك');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!silent) {
          _snack('أذن بالوصول للموقع من إعدادات الجهاز لعرض موقعك');
        }
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      final at = LatLng(p.latitude, p.longitude);
      setState(() => _me = at);
      // التحريك للموقع يدوي فقط — لا نخطف الخريطة من المستخدم عند الفتح
      if (!silent && _mapReady) _mc.move(at, 14);
    } catch (_) {
      if (!silent) _snack('تعذّر تحديد موقعك — حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// المسافة بخط مستقيم بالكيلومتر — تقريبية وتكفي للاسترشاد
  String? _distance(LatLng to) {
    final me = _me;
    if (me == null) return null;
    const r = 6371.0;
    final dLat = (to.latitude - me.latitude) * math.pi / 180;
    final dLng = (to.longitude - me.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(me.latitude * math.pi / 180) *
            math.cos(to.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final km = r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    if (km < 1) return 'يبعد ${(km * 1000).round()} م';
    return 'يبعد ${km.toStringAsFixed(1)} كم';
  }

  Future<void> _directions(_Pin p) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1'
        '&destination=${p.at.latitude},${p.at.longitude}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack('تعذّر فتح تطبيق الخرائط');
    } catch (_) {
      _snack('تعذّر فتح تطبيق الخرائط');
    }
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
      padding: const EdgeInsets.fromLTRB(50, 120, 50, 240),
    ));
  }

  // ─────────── ورقة التصفية ───────────

  void _filterSheet() {
    String city = _city;
    bool safe = _safeOnly;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sctx) => StatefulBuilder(
        builder: (sctx, setS) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                      color: cBorder,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(
                  child: Text('تصفية',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: cDark)),
                ),
                GestureDetector(
                  onTap: () => setS(() {
                    city = 'الكل';
                    safe = false;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: const Text('إعادة تعيين',
                      style: TextStyle(fontSize: 12.5, color: cGrey)),
                ),
              ]),
              const SizedBox(height: 20),

              // ── الأمان ──
              const Row(children: [
                Text('الأمان',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cDark)),
              ]),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setS(() => safe = !safe),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                      color: safe ? cSafeBg : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: safe ? cGreen : cBorder,
                          width: safe ? 1.6 : 1)),
                  child: Row(children: [
                    Icon(safe ? Icons.check_circle : Icons.circle_outlined,
                        color: safe ? cGreen : cGrey, size: 21),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الآمنة للسيلياك فقط',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: safe ? cGreen : cDark)),
                            const SizedBox(height: 2),
                            const Text('أماكن بمنطقة تحضير منفصلة',
                                style:
                                    TextStyle(fontSize: 11.5, color: cGrey)),
                          ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 22),

              // ── المدينة ──
              const Row(children: [
                Text('المدينة',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cDark)),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['الكل', ...Cities.all].map((c) {
                  final on = c == city;
                  return GestureDetector(
                    onTap: () => setS(() => city = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                          color: on ? cGreen : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: on ? cGreen : cBorder)),
                      child: Text(c,
                          style: TextStyle(
                              color: on ? Colors.white : cDark,
                              fontSize: 13,
                              fontWeight: on
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(sctx);
                    _city = city;
                    _safeOnly = safe;
                    _apply();
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: cGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  child: const Text('عرض النتائج',
                      style: TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                  onPressed: () => Navigator.pop(sctx),
                  child: const Text('إلغاء',
                      style: TextStyle(color: cGrey, fontSize: 13.5))),
            ]),
          ),
        ),
      ),
    );
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
              onMapReady: () {
                _mapReady = true;
                _fit(pins);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.glutpass.glutpass',
                maxNativeZoom: 19,
              ),
              if (_me != null)
                MarkerLayer(markers: [
                  Marker(
                      point: _me!, width: 26, height: 26, child: _meDot()),
                ]),
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

          // ── شريط الفلاتر: النوع + زر تصفية ──
          Positioned(
            top: 10,
            right: 0,
            left: 0,
            child: SizedBox(
              height: 40,
              child: Row(children: [
                const SizedBox(width: 12),
                _filterButton(),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _types.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final t = _types[i];
                      final on = t[0] == _type;
                      return GestureDetector(
                        onTap: () {
                          _type = t[0];
                          _apply();
                        },
                        child: Container(
                          alignment: Alignment.center,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 17),
                          decoration: BoxDecoration(
                            color: on ? cGreen : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: on ? cGreen : cBorder),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: Text(t[1],
                              style: TextStyle(
                                  color: on ? Colors.white : cDark,
                                  fontSize: 13,
                                  fontWeight: on
                                      ? FontWeight.w700
                                      : FontWeight.w600)),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),

          if (loading)
            const Positioned(
              top: 62,
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
                margin: const EdgeInsets.symmetric(horizontal: 36),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cBorder)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.filter_alt_off_outlined,
                      color: cGrey, size: 32),
                  const SizedBox(height: 12),
                  const Text('لا توجد أماكن بهذه التصفية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: cDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('جرّب توسيع الخيارات',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cGrey, fontSize: 12)),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      _type = 'all';
                      _city = 'الكل';
                      _safeOnly = false;
                      _apply();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                          color: cSafeBg,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Text('إزالة كل الفلاتر',
                          style: TextStyle(
                              color: cGreen,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            ),

          // زر تحديد موقعي — يرتفع فوق البطاقة عند ظهورها
          Positioned(
            bottom: _sel == null ? 100 : 262,
            left: 16,
            child: GestureDetector(
              onTap: () => _locate(),
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: cBorder),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: cGreen, strokeWidth: 2.2))
                    : Icon(
                        _me == null
                            ? Icons.my_location_outlined
                            : Icons.my_location,
                        color: cGreen,
                        size: 22),
              ),
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
                bottom: 92, right: 12, left: 12, child: _card(ctx, _sel!)),
        ]);
      },
    );
  }

  /// زر التصفية — يحمل عدّاداً بعدد الفلاتر المفعّلة
  Widget _filterButton() {
    final n = _activeFilters;
    final on = n > 0;
    return GestureDetector(
      onTap: _filterSheet,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on ? cGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? cGreen : cBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.tune, size: 16, color: on ? Colors.white : cDark),
          const SizedBox(width: 5),
          Text('تصفية',
              style: TextStyle(
                  color: on ? Colors.white : cDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          if (on) ...[
            const SizedBox(width: 5),
            Container(
              width: 17,
              height: 17,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Text('$n',
                  style: const TextStyle(
                      color: cGreen,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }

  /// نقطة زرقاء لموقع المستخدم مع هالة — تمييزها عن دبابيس المطاعم مقصود
  Widget _meDot() => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A73E8).withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF1A73E8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.4),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4)
              ],
            ),
          ),
        ),
      );

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

  /// بطاقة المطعم — مطابقة للتصميم: معلومات كاملة وزرّان أسفلها
  Widget _card(BuildContext ctx, _Pin p) {
    final pl = p.place;
    final dist = _distance(p.at);
    final sub = [
      if (pl.cuisine != null && pl.cuisine!.trim().isNotEmpty) pl.cuisine,
      if (pl.branch != null && pl.branch!.trim().isNotEmpty) pl.branch,
      if (dist != null) dist,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          PlaceAvatar(pl, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(pl.nameAr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: cDark)),
                    ),
                    if (pl.nameEn != null &&
                        pl.nameEn!.trim().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(pl.nameEn!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: cGrey)),
                      ),
                    ],
                  ]),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: cGrey)),
                  ],
                  const SizedBox(height: 7),
                  RatingRow(pl),
                ]),
          ),
        ]),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SafetyBadge(pl),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: () async {
                  await Navigator.push(ctx,
                      MaterialPageRoute(builder: (_) => DetailsScreen(pl)));
                  if (mounted) setState(() => _f = _load());
                },
                style: FilledButton.styleFrom(
                    backgroundColor: cGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('عرض التفاصيل',
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => _directions(p),
                style: OutlinedButton.styleFrom(
                    foregroundColor: cGreen,
                    side: const BorderSide(color: cGreen, width: 1.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: const Text('الاتجاهات',
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _Pin {
  final Place place;
  final LatLng at;
  final String? address;
  _Pin(this.place, this.at, [this.address]);
}
