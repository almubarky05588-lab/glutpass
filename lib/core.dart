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
