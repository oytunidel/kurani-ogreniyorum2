import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/letter_model.dart';
import 'screens/lesson_screen.dart';
import 'services/progress_service.dart';
import 'widgets/common_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);
  await ProgressService.instance.load();
  runApp(const KuraniApp());
}

class KuraniApp extends StatelessWidget {
  const KuraniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Kur'an'ı Öğreniyorum",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green),
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: '/',
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/lesson':
            final int start = settings.arguments is int ? settings.arguments as int : 0;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (BuildContext context) => LessonScreen(startIndex: start),
            );
          default:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (BuildContext context) => const HomeScreen(),
            );
        }
      },
    );
  }
}

class _ModuleInfo {
  const _ModuleInfo(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<_ModuleInfo> _upcoming = <_ModuleInfo>[
    _ModuleInfo('Harekeler', 'Üstün, esre ve ötre', Icons.text_fields_rounded),
    _ModuleInfo('Başta, ortada, sonda', 'Harflerin yazılış biçimleri', Icons.swap_horiz_rounded),
    _ModuleInfo('Kısa sure kelimeleri', 'İlk kelimeleri okumaya geçiş', Icons.menu_book_rounded),
  ];

  void _open(BuildContext context, int index) {
    Navigator.of(context).pushNamed('/lesson', arguments: index);
  }

  @override
  Widget build(BuildContext context) {
    final ProgressService progress = ProgressService.instance;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: progress,
          builder: (BuildContext context, Widget? child) {
            final int next = progress.nextLetter.clamp(0, kLetters.length);
            final bool allDone = next >= kLetters.length;
            final String startLabel = next == 0 ? 'BAŞLA' : (allDone ? 'TEKRAR ET' : 'DEVAM ET');
            final int startIndex = allDone ? 0 : next;
            final int minutes = progress.todaySeconds ~/ 60;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                const Text(
                  "Kur'an'ı Öğreniyorum",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.greenDark),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Diyanet Elif-Bâ yöntemiyle adım adım',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textLight),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        Icons.local_fire_department_rounded,
                        AppColors.orange,
                        AppColors.orangeBg,
                        '${progress.currentStreak}',
                        'gün seri',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        Icons.bolt_rounded,
                        AppColors.goldDark,
                        const Color(0xFFFFF6CC),
                        '${progress.xp}',
                        'XP',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        Icons.military_tech_rounded,
                        AppColors.blueDark,
                        AppColors.blueBg,
                        '${progress.level}',
                        'seviye',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gray, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Günlük hedef', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.text)),
                          ),
                          Text('$minutes / 15 dk', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.blueDark)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress.dailyGoalFraction,
                          minHeight: 12,
                          backgroundColor: AppColors.gray,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Günde 15-20 dakika yeterli. Düzenli çalışmak seriyi korur.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Button3D(
                  label: startLabel,
                  icon: Icons.play_arrow_rounded,
                  height: 58,
                  fontSize: 19,
                  onTap: () => _open(context, startIndex),
                ),
                const SizedBox(height: 26),
                const Text('Bölüm 1: Elif-Bâ harfleri', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text)),
                const SizedBox(height: 4),
                Text(
                  '${progress.completed.length} / ${kLetters.length} harf tamamlandı',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textLight),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                  children: [
                    for (int i = 0; i < kLetters.length; i++) _letterBubble(context, progress, i, next),
                  ],
                ),
                const SizedBox(height: 26),
                const Text('Sıradaki bölümler', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text)),
                const SizedBox(height: 12),
                for (final _ModuleInfo module in _upcoming) _lockedModule(module),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, Color color, Color bg, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _letterBubble(BuildContext context, ProgressService progress, int index, int next) {
    final LetterModel letter = kLetters[index];
    final bool done = progress.completed.contains(letter.order);
    final bool current = index == next;
    final bool unlocked = index <= next;
    Color face = Colors.white;
    Color edge = AppColors.gray;
    Color fg = AppColors.grayDark;
    if (done) {
      face = AppColors.greenBg;
      edge = AppColors.green;
      fg = AppColors.greenDark;
    } else if (current) {
      face = AppColors.blueBg;
      edge = AppColors.blue;
      fg = AppColors.blueDark;
    }
    return Card3D(
      face: face,
      edge: edge,
      radius: 18,
      onTap: unlocked ? () => _open(context, index) : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(letter.arabic, style: TextStyle(fontSize: 34, height: 1.2, color: fg, fontWeight: FontWeight.w700)),
          Text(letter.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }

  Widget _lockedModule(_ModuleInfo module) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gray, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: AppColors.gray, shape: BoxShape.circle),
            child: Icon(module.icon, color: AppColors.grayDark, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(module.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textLight)),
                Text(module.subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.grayDark)),
              ],
            ),
          ),
          const Icon(Icons.lock_rounded, color: AppColors.grayDark),
        ],
      ),
    );
  }
}
