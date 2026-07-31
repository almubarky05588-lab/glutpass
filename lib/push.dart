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

/// معالج الرسائل والتطبيق مغلق تماماً — لازم يكون دالة عليا.
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage m) async {
  // لا نفعل شيئاً؛ النظام يعرض الإشعار بنفسه.
}

class Push {
  static bool ready = false;

  /// يُستدعى عند الإقلاع. لا يرمي استثناءً أبداً —
  /// فشل الإشعارات يجب ألّا يمنع التطبيق من العمل.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp(options: _fbOptions);
      FirebaseMessaging.onBackgroundMessage(_bgHandler);
      ready = true;

      // إن كان مسجّلاً دخوله مسبقاً، سجّل جهازه
      if (Supabase.instance.client.auth.currentUser != null) {
        await register();
      }

      // عند تسجيل الدخول أو الخروج
      Supabase.instance.client.auth.onAuthStateChange.listen((e) async {
        if (e.event == AuthChangeEvent.signedIn) {
          await register();
        } else if (e.event == AuthChangeEvent.signedOut) {
          await unregister();
        }
      });

      // تجديد الرمز يحدث تلقائياً من حين لآخر
      FirebaseMessaging.instance.onTokenRefresh.listen((t) => _save(t));
    } catch (e) {
      debugPrint('Push.init: $e');
    }
  }

  /// يطلب الإذن ثم يحفظ رمز الجهاز.
  /// يُرجع true إن مُنح الإذن.
  static Future<bool> register() async {
    if (!ready) return false;
    try {
      final fm = FirebaseMessaging.instance;
      final s = await fm.requestPermission(alert: true, badge: true, sound: true);
      final granted =
          s.authorizationStatus == AuthorizationStatus.authorized ||
              s.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return false;

      // على iOS لا يصل رمز FCM قبل وصول رمز APNs
      for (var i = 0; i < 10; i++) {
        final apns = await fm.getAPNSToken();
        if (apns != null) break;
        await Future.delayed(const Duration(milliseconds: 600));
      }

      final t = await fm.getToken();
      if (t != null) await _save(t);
      return true;
    } catch (e) {
      debugPrint('Push.register: $e');
      return false;
    }
  }

  static Future<void> _save(String token) async {
    try {
      final c = Supabase.instance.client;
      if (c.auth.currentUser == null) return;
      await c.rpc('register_device', params: {
        'p_token': token,
        'p_platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'p_locale': 'ar',
      });
    } catch (e) {
      debugPrint('Push._save: $e');
    }
  }

  /// عند تسجيل الخروج — نوقف الرمز حتى لا تصل إشعارات لحساب آخر
  static Future<void> unregister() async {
    if (!ready) return;
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t == null) return;
      await Supabase.instance.client
          .from('device_tokens')
          .update({'is_active': false}).eq('token', t);
    } catch (e) {
      debugPrint('Push.unregister: $e');
    }
  }

  /// حالة الإذن الحالية — لعرضها في شاشة الحساب
  static Future<bool> isEnabled() async {
    if (!ready) return false;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }
}
