import 'package:supabase_flutter/supabase_flutter.dart';

/// طبقة النصوص القابلة للتحرير من لوحة التحكم.
///
/// القاعدة الحاكمة: التطبيق يُشحن ومعه نسخة مدمجة كاملة.
/// ما يأتي من الخادم يستبدلها فقط عند نجاح الجلب.
/// إن فشلت الشبكة تبقى النسخة المدمجة — ولا يُعرض نص فارغ أبداً.
class Content {
  static const Map<String, String> _bundled = {
    'splash.tagline': 'دليلك الموثوق للحياة الخالية من الجلوتين',
    'onboarding.1.title': 'اكتشف الأماكن الآمنة',
    'onboarding.1.body':
        'دليل متكامل للمطاعم والأطباق الخالية من الجلوتين في مدن المملكة، '
        'مع توضيح مستوى الأمان لمرضى السيلياك قبل الطلب.',
    'onboarding.2.title': 'صوّت وساعد غيرك',
    'onboarding.2.body':
        'أضف الأماكن والأطباق التي جرّبتها وقيّمها، فتجربتك الصادقة هي '
        'مرجع يعتمد عليه مجتمع كامل من مرضى حساسية الجلوتين.',
    'auth.signup.celiac_label': 'أنا مصاب بحساسية القمح (السيلياك)',
    'safety.separate_prep.label': 'آمن للسيلياك',
    'safety.shared_prep.label': 'تحقّق قبل الطلب',
    'safety.unknown.label': 'تحقّق قبل الطلب',
    'safety.low_sample_notice': 'تجارب قليلة — يحتاج تأكيد',
    'vote.question': 'هل كان آمناً عليك؟',
    'vote.option.safe': 'آمن تماماً، لا أعراض',
    'vote.option.mild': 'أعراض خفيفة',
    'vote.option.unsafe': 'غير آمن',
    'about.body':
        'GlutPass هو الدليل الأول في المملكة للأماكن والأطباق الخالية من '
        'الجلوتين. يبنيه المجتمع بالتجربة والتصويت، ليصبح الخروج للأكل '
        'تجربة آمنة ومطمئنة لكل مصابي حساسية القمح.',
    'legal.terms': 'شروط الاستخدام',
    'legal.privacy': 'سياسة الخصوصية',
  };

  static Map<String, String> _live = {};

  /// النص المطلوب — من الخادم إن توفّر، وإلا من النسخة المدمجة.
  static String t(String key) => _live[key] ?? _bundled[key] ?? '';

  /// يُستدعى عند إقلاع التطبيق. لا يرمي استثناءً أبداً.
  static Future<void> load() async {
    try {
      final rows = await Supabase.instance.client
          .from('content_values')
          .select('key,value,version')
          .eq('locale', 'ar')
          .eq('status', 'published')
          .order('version', ascending: true);
      final m = <String, String>{};
      for (final r in (rows as List)) {
        // الإصدار الأحدث يغلب لأن الترتيب تصاعدي
        m[r['key'] as String] = r['value'] as String;
      }
      if (m.isNotEmpty) _live = m;
    } catch (_) {
      // فشل الشبكة — نبقى على النسخة المدمجة
    }
  }
}
