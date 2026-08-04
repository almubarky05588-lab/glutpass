import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core.dart';
import 'content.dart';
import 'push.dart';
import 'screens/home.dart';
import 'screens/account.dart';
import 'screens/submit.dart';
import 'screens/map.dart';
import 'screens/onboarding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kUrl, anonKey: kKey);
  // الثلاثة تفشل بصمت ولا توقف الإقلاع
  await Content.load();
  await Cities.load();
  await Push.init();

  // عند فشل القراءة نفترض أنه رآها — تكرارها كل إقلاع أسوأ من تخطّيها
  bool seen = true;
  try {
    final p = await SharedPreferences.getInstance();
    seen = p.getBool(kOnboardingSeenKey) ?? false;
  } catch (_) {}

  runApp(App(showOnboarding: !seen));
}

class App extends StatefulWidget {
  final bool showOnboarding;
  const App({super.key, required this.showOnboarding});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late bool _onboarding = widget.showOnboarding;

  @override
  Widget build(BuildContext ctx) {
    final b = ThemeData(useMaterial3: true, scaffoldBackgroundColor: cBg);
    return MaterialApp(
      title: 'GlutPass',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: b.copyWith(textTheme: GoogleFonts.tajawalTextTheme(b.textTheme)),
      builder: (_, c) =>
          Directionality(textDirection: TextDirection.rtl, child: c!),
      home: _onboarding
          ? OnboardingScreen(
              onFinish: () => setState(() => _onboarding = false))
          : const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _i, children: const [
          HomeScreen(),
          MapScreen(),
          AccountScreen(),
          AboutScreen(),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            ctx, MaterialPageRoute(builder: (_) => const SubmitScreen())),
        backgroundColor: cGreen,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        height: 66,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _tab(0, Icons.home_outlined, 'الرئيسية'),
            _tab(1, Icons.map_outlined, 'الخريطة'),
            const SizedBox(width: 50),
            _tab(2, Icons.person_outline, 'حسابي'),
            _tab(3, Icons.info_outline, 'عن التطبيق'),
          ],
        ),
      ),
    );
  }

  Widget _tab(int i, IconData ic, String t) {
    final on = _i == i;
    return GestureDetector(
      onTap: () => setState(() => _i = i),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 66,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, size: 21, color: on ? cGreen : cGrey),
          const SizedBox(height: 3),
          Text(t,
              style: TextStyle(
                  fontSize: 10.5,
                  color: on ? cGreen : cGrey,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    );
  }
}

/// شاشة نص قانوني — تقرأ من لوحة التحكم
class LegalScreen extends StatelessWidget {
  final String title, bodyKey;
  const LegalScreen(this.title, this.bodyKey, {super.key});

  @override
  Widget build(BuildContext ctx) {
    final body = Content.t(bodyKey);
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              SizedBox(
                  width: 40,
                  child: IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.arrow_back_ios,
                          size: 18, color: cDark))),
              Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cDark))),
              const SizedBox(width: 40),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cBorder)),
                  child: Text(
                      body.trim().isEmpty ? 'لم يُنشر هذا النص بعد.' : body,
                      textAlign: TextAlign.start,
                      style: const TextStyle(
                          fontSize: 14, color: cDark, height: 1.9)),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _snack(BuildContext ctx, String t) => ScaffoldMessenger.of(ctx)
      .showSnackBar(SnackBar(content: Text(t, style: const TextStyle(fontSize: 13))));

  Future<void> _open(BuildContext ctx, Uri uri, String fail) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && ctx.mounted) _snack(ctx, fail);
    } catch (_) {
      if (ctx.mounted) _snack(ctx, fail);
    }
  }

  /// صفحة التقييم في آبل. رقم التطبيق يُضبط من لوحة التحكم.
  Future<void> _rate(BuildContext ctx) async {
    final id = Content.t('app.ios_id').trim();
    if (id.isEmpty) {
      _snack(ctx, 'التقييم سيتاح بعد نشر التطبيق في المتجر');
      return;
    }
    await _open(
        ctx,
        Uri.parse('https://apps.apple.com/app/id$id?action=write-review'),
        'تعذّر فتح المتجر');
  }

  void _legal(BuildContext ctx, String titleKey, String bodyKey) {
    final t = Content.t(titleKey).split('\n').first.trim();
    Navigator.push(
        ctx, MaterialPageRoute(builder: (_) => LegalScreen(t, bodyKey)));
  }

  void _contact(BuildContext ctx) {
    final email = Content.t('contact.email').trim();
    final wa = Content.t('contact.whatsapp').replaceAll(RegExp(r'[^0-9]'), '');
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: cBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 18),
            const Text('تواصل مع الفريق',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: cDark)),
            const SizedBox(height: 8),
            Text(Content.t('contact.body'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: cGrey, height: 1.7)),
            const SizedBox(height: 18),
            if (wa.isNotEmpty)
              _sheetRow(sctx, Icons.chat_bubble_outline, 'واتساب', () {
                Navigator.pop(sctx);
                _open(
                    ctx,
                    Uri.parse('https://wa.me/$wa?text='
                        '${Uri.encodeComponent('مرحباً، بخصوص تطبيق GlutPass')}'),
                    'واتساب غير مثبّت على جهازك');
              }),
            if (email.isNotEmpty)
              _sheetRow(sctx, Icons.mail_outline, 'البريد الإلكتروني', () {
                Navigator.pop(sctx);
                _open(
                    ctx,
                    Uri.parse('mailto:$email?subject='
                        '${Uri.encodeComponent('ملاحظة على تطبيق GlutPass')}'),
                    'لا يوجد تطبيق بريد مُعدّ على جهازك');
              }),
            const SizedBox(height: 6),
            TextButton(
                onPressed: () => Navigator.pop(sctx),
                child: const Text('إغلاق',
                    style: TextStyle(color: cGrey, fontSize: 13.5))),
          ]),
        ),
      ),
    );
  }

  Widget _sheetRow(
          BuildContext ctx, IconData ic, String label, VoidCallback tap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
                color: cBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cBorder)),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: cSafeBg, borderRadius: BorderRadius.circular(11)),
                child: Icon(ic, size: 18, color: cGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: cDark)),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: cGrey),
            ]),
          ),
        ),
      );

  /// صف في القائمة — الأيقونة يميناً والسهم يساراً كما في التصميم
  Widget _row(IconData ic, String label, VoidCallback tap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cBorder)),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: cSafeBg, borderRadius: BorderRadius.circular(11)),
                  child: Icon(ic, size: 18, color: cGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: cDark)),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: cGrey),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext ctx) {
    final privacy = Content.t('legal.privacy').split('\n').first.trim();
    final terms = Content.t('legal.terms').split('\n').first.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 110),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cBorder)),
            child: const GlutMark(width: 46),
          ),
        ),
        const SizedBox(height: 14),
        const Text('GlutPass',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, color: cGreen)),
        const SizedBox(height: 3),
        const Text('الإصدار ١٫٠٫٠',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: cGrey)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: cSafeBg, borderRadius: BorderRadius.circular(18)),
          child: Text(Content.t('about.body'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13.5, color: Color(0xFF25402F), height: 1.95)),
        ),
        const SizedBox(height: 20),
        _row(Icons.star_outline, 'قيّم التطبيق في المتجر', () => _rate(ctx)),
        _row(Icons.description_outlined,
            privacy.isEmpty ? 'سياسة الخصوصية' : privacy,
            () => _legal(ctx, 'legal.privacy', 'legal.privacy.body')),
        _row(Icons.description_outlined,
            terms.isEmpty ? 'شروط الاستخدام' : terms,
            () => _legal(ctx, 'legal.terms', 'legal.terms.body')),
        _row(Icons.phone_outlined, 'تواصل مع الفريق', () => _contact(ctx)),
        const SizedBox(height: 22),
        const Text('صُنع بحب لمجتمع السيلياك في السعودية',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cGrey)),
      ],
    );
  }
}
