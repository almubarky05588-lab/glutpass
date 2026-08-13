import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'content.dart';

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
const cStar = Color(0xFFC7CFC9);

/// المدن — تُدار من لوحة التحكم ويضيفها المستخدمون.
///
/// نفس فلسفة Content: نسخة مدمجة تعمل بلا شبكة،
/// والخادم يستبدلها عند نجاح الجلب فقط.
class Cities {
  static const List<String> _bundled = ['الرياض', 'جدة', 'الدمام'];
  static List<String> _live = [];

  static List<String> get all => _live.isEmpty ? _bundled : _live;

  /// يُستدعى عند الإقلاع. لا يرمي استثناءً أبداً.
  static Future<void> load() async {
    try {
      final rows = await Supabase.instance.client
          .from('cities')
          .select('name_ar')
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('name_ar', ascending: true);
      final l = (rows as List).map((e) => e['name_ar'] as String).toList();
      if (l.isNotEmpty) _live = l;
    } catch (_) {
      // فشل الشبكة — نبقى على النسخة المدمجة
    }
  }

  /// يضيف مدينة. يُرجع null عند النجاح، أو نص الخطأ عند الفشل.
  /// التكرار يمنعه فهرس فريد على الاسم المعياري في القاعدة.
  static Future<String?> add(String name) async {
    final n = name.trim();
    if (n.isEmpty) return 'اكتب اسم المدينة';
    if (n.length < 2) return 'الاسم قصير جداً';
    try {
      await Supabase.instance.client.from('cities').insert({'name_ar': n});
      await load();
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return 'المدينة مضافة مسبقاً';
      return e.message;
    } catch (e) {
      return '$e';
    }
  }

  /// إحداثيات تقريبية لمدن السعودية — تُستخدم لاختيار أقرب مدينة من القائمة.
  /// أي مدينة غير مذكورة هنا تبقى قابلة للاختيار يدوياً بلا مشكلة.
  static const Map<String, List<double>> _coords = {
    'الرياض': [24.7136, 46.6753],
    'جدة': [21.4858, 39.1925],
    'مكة': [21.3891, 39.8579],
    'مكه': [21.3891, 39.8579],
    'مكة المكرمة': [21.3891, 39.8579],
    'المدينة': [24.5247, 39.5692],
    'المدينة المنورة': [24.5247, 39.5692],
    'الدمام': [26.4207, 50.0888],
    'الخبر': [26.2794, 50.2083],
    'الظهران': [26.2361, 50.0393],
    'الأحساء': [25.3833, 49.5833],
    'الهفوف': [25.3647, 49.5872],
    'القطيف': [26.5196, 50.0115],
    'الجبيل': [27.0174, 49.6225],
    'الطائف': [21.2703, 40.4158],
    'بريدة': [26.3260, 43.9750],
    'عنيزة': [26.0844, 43.9935],
    'تبوك': [28.3835, 36.5662],
    'أبها': [18.2164, 42.5053],
    'خميس مشيط': [18.3000, 42.7300],
    'حائل': [27.5114, 41.7208],
    'نجران': [17.4924, 44.1277],
    'جازان': [16.8892, 42.5511],
    'ينبع': [24.0895, 38.0618],
    'حفر الباطن': [28.4342, 45.9636],
    'عرعر': [30.9753, 41.0381],
    'سكاكا': [29.9697, 40.2064],
    'الباحة': [20.0129, 41.4677],
    'الخرج': [24.1483, 47.3050],
  };

  /// أقرب مدينة منشورة إلى إحداثيات المستخدم.
  /// تُرجع null إن كان أقرب موجود أبعد من ١٥٠ كم — فلا نخمّن مدينة خاطئة،
  /// وتُرجع null أيضاً إن لم تكن أي مدينة في القائمة معروفة الإحداثيات.
  static String? nearest(double lat, double lng) {
    String? best;
    double bestKm = double.infinity;
    for (final city in all) {
      final c = _coords[city.trim()];
      if (c == null) continue;
      // تقريب مستوٍ يكفي على هذا النطاق — لا داعي لحساب كروي كامل
      final dLat = (c[0] - lat) * 111.0;
      final dLng = (c[1] - lng) * 111.0 * 0.9;
      final km = math.sqrt(dLat * dLat + dLng * dLng);
      if (km < bestKm) {
        bestKm = km;
        best = city;
      }
    }
    return bestKm <= 150 ? best : null;
  }
}

class Place {
  final String id, nameAr, safety;
  final String? nameEn, cuisine, branch, note, logoLetter, logoColor, logoUrl;
  final double? pct;
  final int votes, dishes;

  Place.fromMap(Map<String, dynamic> m)
      : id = m['id'] as String,
        nameAr = m['name_ar'] as String,
        nameEn = m['name_en'] as String?,
        cuisine = m['cuisine'] as String?,
        branch = m['branch_label'] as String?,
        note = m['short_note'] as String?,
        logoLetter = m['logo_letter'] as String?,
        logoColor = m['logo_color'] as String?,
        logoUrl = m['logo_url'] as String?,
        safety = m['effective_safety_status'] as String,
        pct = (m['safe_experience_pct'] as num?)?.toDouble(),
        votes = (m['safety_votes_count'] as num?)?.toInt() ?? 0,
        dishes = (m['dishes_count'] as num?)?.toInt() ?? 0;

  static const cols =
      'id,name_ar,name_en,cuisine,branch_label,short_note,logo_letter,'
      'logo_color,logo_url,effective_safety_status,safe_experience_pct,'
      'safety_votes_count,dishes_count';

  bool get isSafe => safety == 'SEPARATE_PREP';

  String get badgeText => isSafe
      ? Content.t('safety.separate_prep.label')
      : safety == 'SHARED_PREP'
          ? Content.t('safety.shared_prep.label')
          : Content.t('safety.unknown.label');

  Color get badgeBg => isSafe ? cSafeBg : cAmberBg;
  Color get badgeFg => isSafe ? cGreen : cAmber;
  IconData get badgeIcon => isSafe ? Icons.check : Icons.info_outline;

  String get safetyLine => pct == null
      ? Content.t('safety.low_sample_notice')
      : '${pct!.toStringAsFixed(0)}٪ بلا أعراض · $votes تجربة';

  Color get avatarColor {
    final h = logoColor?.replaceAll('#', '');
    if (h == null || h.length != 6) return cGreen;
    return Color(int.parse('FF$h', radix: 16));
  }
}

class SafetyBadge extends StatelessWidget {
  final Place place;
  const SafetyBadge(this.place, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: place.badgeBg, borderRadius: BorderRadius.circular(13)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(place.badgeIcon, color: place.badgeFg, size: 12),
          const SizedBox(width: 4),
          Text(place.badgeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: place.badgeFg,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class RatingRow extends StatelessWidget {
  final Place place;
  const RatingRow(this.place, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(place.safetyLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: place.badgeFg)),
        ),
        const SizedBox(width: 6),
        ...List.generate(
            5,
            (_) => const Padding(
                  padding: EdgeInsetsDirectional.only(end: 1),
                  child: Icon(Icons.star, size: 10, color: cStar),
                )),
      ],
    );
  }
}

class PlaceAvatar extends StatelessWidget {
  final Place place;
  final double size;
  const PlaceAvatar(this.place, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final url = place.logoUrl;
    if (url != null && url.trim().isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cBg,
          border: Border.all(color: cBorder),
          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: place.avatarColor, shape: BoxShape.circle),
      child: Text(place.logoLetter ?? '؟',
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700)),
    );
  }
}
