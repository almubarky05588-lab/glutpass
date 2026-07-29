import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core.dart';
import 'content.dart';
import 'screens/home.dart';
import 'screens/account.dart';
import 'screens/submit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kUrl, anonKey: kKey);
  await Content.load();   // النصوص من لوحة التحكم — تفشل بصمت وتبقى النسخة المدمجة
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
          _Soon('الخريطة'),
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

class _About extends StatelessWidget {
  const _About();
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
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14, color: cDark, height: 1.9)),
          ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(Content.t('legal.privacy'),
                style: const TextStyle(fontSize: 12.5, color: cGreen)),
            const Text('  ·  ', style: TextStyle(color: cGrey)),
            Text(Content.t('legal.terms'),
                style: const TextStyle(fontSize: 12.5, color: cGreen)),
          ]),
          const SizedBox(height: 24),
          const Text('صُنع بحب لمجتمع السيلياك في السعودية',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cGrey)),
          const SizedBox(height: 40),
        ],
      );
}

class _Soon extends StatelessWidget {
  final String name;
  const _Soon(this.name);
  @override
  Widget build(BuildContext ctx) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.construction, size: 44, color: cGrey),
          const SizedBox(height: 12),
          Text('شاشة $name',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: cDark)),
          const SizedBox(height: 4),
          const Text('قيد البناء', style: TextStyle(color: cGrey)),
        ]),
      );
}

