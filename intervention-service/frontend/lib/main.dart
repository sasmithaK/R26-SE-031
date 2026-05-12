import 'package:flutter/material.dart';

import 'screens/reading_screen.dart';
import 'screens/long_word_screen.dart';
import 'screens/consonant_screen.dart';
import 'screens/vowel_screen.dart';
import 'screens/unfamiliar_screen.dart';
import 'screens/fluency_screen.dart';
import 'screens/phonological_screen.dart';
import 'theme/reading_theme.dart';
import 'widgets/mascot.dart';

void main() {
  runApp(const ReadingInterventionApp());
}

class ReadingInterventionApp extends StatelessWidget {
  const ReadingInterventionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'කියවීමේ උදව්',
      debugShowCheckedModeBanner: false,
      theme: ReadingKidTheme.theme(),
      home: const HomeHub(),
    );
  }
}

class _Activity {
  const _Activity(
    this.label,
    this.subtitle,
    this.icon,
    this.color,
    this.builder,
  );
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;
}

class HomeHub extends StatelessWidget {
  const HomeHub({super.key});

  @override
  Widget build(BuildContext context) {
    final activities = <_Activity>[
      _Activity(
        'දිගු වචන',
        'තාලෙට කියමු',
        Icons.straighten_rounded,
        const Color(0xFFEF6C00),
        (_) => const LongWordScreen(),
      ),
      _Activity(
        'ව්\u200dයඤ්ජන හඬ',
        'පළමු හඬ අසමු',
        Icons.graphic_eq_rounded,
        const Color(0xFF6A1B9A),
        (_) => const ConsonantScreen(),
      ),
      _Activity(
        'ස්වර ලකුණු',
        'ස්වරය එක් කරමු',
        Icons.music_note_rounded,
        const Color(0xFF1565C0),
        (_) => const VowelScreen(),
      ),
      _Activity(
        'අලුත් වචන',
        'අරුත මුලින් දැනගමු',
        Icons.lightbulb_rounded,
        const Color(0xFF2E7D32),
        (_) => const UnfamiliarScreen(),
      ),
      _Activity(
        'ලස්සනට කියවීම',
        'මා සමඟ කියමු',
        Icons.repeat_rounded,
        const Color(0xFF00838F),
        (_) => const FluencyScreen(),
      ),
      _Activity(
        'හඬ රටා',
        'ප්\u200dරාසය හඳුනමු',
        Icons.queue_music_rounded,
        const Color(0xFFC62828),
        (_) => const PhonologicalScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('කියවීමේ උදව්'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HubHeader(),
              const SizedBox(height: 14),
              _ReadingCard(),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  itemCount: activities.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.15,
                  ),
                  itemBuilder: (context, i) {
                    final a = activities[i];
                    return _ActivityCard(activity: a, index: i);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFFF8E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded,
              size: 38, color: Color(0xFFFF8F00)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'පුහුණුවක් තෝරමු!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5D4037),
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'ඔයාට කැමති එක ස්පර්ශ කරන්න',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6D4C41),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.star_rounded,
              size: 36, color: Color(0xFFFFB300)),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.index});
  final _Activity activity;
  final int index;

  static const _badges = [
    Icons.local_florist_rounded,
    Icons.cake_rounded,
    Icons.water_drop_rounded,
    Icons.spa_rounded,
    Icons.cloud_rounded,
    Icons.favorite_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final c = activity.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: activity.builder),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.withOpacity(.18), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
            border: Border.all(color: c.withOpacity(.35), width: 2),
            boxShadow: [
              BoxShadow(
                color: c.withOpacity(.12),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: Icon(
                  _badges[index % _badges.length],
                  color: c.withOpacity(.35),
                  size: 24,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.withOpacity(.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.withOpacity(.30)),
                    ),
                    child: Icon(activity.icon, color: c, size: 28),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activity.label,
                    style: ReadingKidTheme.title.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity.subtitle,
                    style: ReadingKidTheme.hint.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReadingScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFA5D6A7), Color(0xFFE8F5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
            border: Border.all(
              color: ReadingKidTheme.primary.withOpacity(.45),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: ReadingKidTheme.primary.withOpacity(.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const MascotMini(size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'කතාව කියවමු 📖',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B5E20),
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'කතාවක් කියවා, බැරි වචන ස්පර්ශ කරන්න!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF388E3C),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF2E7D32),
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
