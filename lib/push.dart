import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// إعدادات Firebase مكتوبة في الكود بدل ملف GoogleService-Info.plist،
/// لأن مجلد ios يُولَّد من الصفر في كل بناء فيضيع أي ملف نضعه فيه.
const _fbOptions = FirebaseOptions(
  apiKey: 'AIzaSyAUHAOeFeCO3szvYWe1oitVziU6LMhjpAw',
  appId: '1:897505460808:ios:cee925d7c6f7a1fed80e7d',
  messagingSenderId: '897505460808',
  projectId: 'glutpass',
  storageBucket: 'glutpass.firebasestorage.app',
  iosBundleId: 'com.glutpass.glutpass',
);

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage m) async {
  // النظام يعرض الإشعار بنفسه
}

class Push {
  // ــــ حالة تشخيصية تُعرض في التطبيق، لأننا نعمل بلا سجلات الجهاز ــــ
  static bool fbReady = false;
  static bool permission = false;
  static String? apns;
  static String? fcm;
  static bool saved = false;
  static String? lastError;
  static String step = 'لم يبدأ';

  static Future<void> init() async {
    try {
      step = 'تهيئة Firebase';
      await Firebase.initializeApp(options: _fbOptions);
      fbReady = true;
      FirebaseMessaging.onBackgroundMessage(_bgHandler);

      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        fcm = t;
        _save(t);
      });

      Supabase.instance.client.auth.onAuthStateChange.listen((e) async {
        if (e.event == AuthChangeEvent.signedOut) {
          await unregister();
        } else if (e.session != null) {
          await ensure();
        }
      });

      step = 'جاهز';
      if (Supabase.instance.client.auth.currentUser != null) {
        await ensure();
      }
    } catch (e) {
      lastError = 'init: $e';
      step = 'فشل التهيئة';
    }
  }

  /// يحاول إكمال ما نقص: الإذن ثم الرمز ثم الحفظ.
  /// آمن للنداء المتكرر.
  static Future<void> ensure() async {
    if (!fbReady) return;
    try {
      final fm = FirebaseMessaging.instance;

      step = 'فحص الإذن';
      var s = await fm.getNotificationSettings();
      if (s.authorizationStatus != AuthorizationStatus.authorized &&
          s.authorizationStatus != AuthorizationStatus.provisional) {
        step = 'طلب الإذن';
        s = await fm.requestPermission(alert: true, badge: true, sound: true);
      }
      permission = s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
      if (!permission) {
        step = 'الإذن مرفوض';
        return;
      }

      // على iOS لا يصدر Firebase رمزه قبل أن تصل موافقة آبل.
      // ننتظر حتى ٣٠ ثانية بدل ٦.
      step = 'انتظار رمز آبل';
      for (var i = 0; i < 30; i++) {
        try {
          apns = await fm.getAPNSToken();
        } catch (e) {
          lastError = 'apns: $e';
        }
        if (apns != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }

      step = 'طلب رمز Firebase';
      for (var i = 0; i < 3; i++) {
        try {
          fcm = await fm.getToken();
        } catch (e) {
          lastError = 'getToken: $e';
        }
        if (fcm != null) break;
        await Future.delayed(const Duration(seconds: 2));
      }

      if (fcm == null) {
        step = apns == null
            ? 'لم يصل رمز آبل — تحقّق من الاتصال ثم أعد المحاولة'
            : 'لم يصل رمز Firebase';
        return;
      }

      step = 'حفظ الرمز';
      await _save(fcm!);
      step = saved ? 'مكتمل' : 'فشل الحفظ';
    } catch (e) {
      lastError = 'ensure: $e';
      step = 'خطأ';
    }
  }

  static Future<void> _save(String token) async {
    try {
      final c = Supabase.instance.client;
      if (c.auth.currentUser == null) {
        lastError = 'save: غير مسجّل دخول';
        return;
      }
      await c.rpc('register_device', params: {
        'p_token': token,
        'p_platform':
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'p_locale': 'ar',
      });
      saved = true;
      lastError = null;
    } catch (e) {
      saved = false;
      lastError = 'save: $e';
    }
  }

  static Future<void> unregister() async {
    if (!fbReady) return;
    try {
      if (fcm == null) return;
      await Supabase.instance.client
          .from('device_tokens')
          .update({'is_active': false}).eq('token', fcm!);
      saved = false;
    } catch (e) {
      lastError = 'unregister: $e';
    }
  }

  static Future<bool> isEnabled() async {
    if (!fbReady) return false;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      permission = s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
      return permission;
    } catch (_) {
      return false;
    }
  }

  /// تقرير مقروء يُعرض في شاشة الحساب
  static String report() {
    final b = StringBuffer();
    b.writeln('Firebase: ${fbReady ? "مهيّأ ✓" : "غير مهيّأ ✗"}');
    b.writeln('الإذن: ${permission ? "ممنوح ✓" : "غير ممنوح ✗"}');
    b.writeln('رمز آبل: ${apns == null ? "لم يصل ✗" : "وصل ✓"}');
    b.writeln('رمز Firebase: ${fcm == null ? "لم يصل ✗" : "وصل ✓"}');
    b.writeln('الحفظ في القاعدة: ${saved ? "تم ✓" : "لم يتم ✗"}');
    b.writeln('المرحلة: $step');
    if (lastError != null) {
      b.writeln('');
      b.writeln('آخر خطأ:');
      b.writeln(lastError);
    }
    return b.toString();
  }
}
