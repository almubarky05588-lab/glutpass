import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core.dart';
import 'content.dart';
import 'push.dart';
import 'screens/home.dart';
import 'screens/account.dart';
import 'screens/submit.dart';
import 'screens/map.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kUrl, anonKey: kKey);
  // الثلاثة تفشل بصمت ولا توقف الإقلاع
  await Content.load();
  await Cities.load();
  await Push.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
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
      home: const Shell(),
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
          _About(),
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
                      body.trim().isEmpty
                          ? 'لم يُنشر هذا النص بعد.'
                          : body,
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

class _About extends StatelessWidget {
  const _About();

  void _open(BuildContext ctx, String titleKey, String bodyKey) {
    final t = Content.t(titleKey).split('\n').first.trim();
    Navigator.push(
        ctx, MaterialPageRoute(builder: (_) => LegalScreen(t, bodyKey)));
  }

  @override
  Widget build(BuildContext ctx) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 30),
          const Icon(Icons.eco, color: cGreen, size: 64),
          const SizedBox(height: 12),
          const Text('GlutPass',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, color: cGreen)),
          const SizedBox(height: 4),
          const Text('الإصدار ١٫٠٫٠',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cGrey)),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cBorder)),
            child: Text(Content.t('about.body'),
                textAlign: TextAlign.start,
                style: const TextStyle(
                    fontSize: 14, color: cDark, height: 1.9)),
          ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
              child: TextButton(
                onPressed: () =>
                    _open(ctx, 'legal.privacy', 'legal.privacy.body'),
                child: Text(
                    Content.t('legal.privacy').split('\n').first.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: cGreen,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const Text('·', style: TextStyle(color: cGrey)),
            Flexible(
              child: TextButton(
                onPressed: () => _open(ctx, 'legal.terms', 'legal.terms.body'),
                child: Text(
                    Content.t('legal.terms').split('\n').first.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: cGreen,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          const Text('صُنع بحب لمجتمع السيلياك في السعودية',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cGrey)),
          const SizedBox(height: 40),
        ],
      );
}
