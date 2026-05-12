import 'package:flutter/material.dart';

import '../services/reading_audio_service.dart';
import '../theme/reading_theme.dart';
import '../widgets/activity_shell.dart';

class FluencyScreen extends StatelessWidget {
  const FluencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ActivityShell(
      title: 'ලස්සනට කියවීම',
      subtitle: 'මා සමඟ අනුකරණයෙන් කියමු, පසුව පියවරෙන් වැඩි කරමු.',
      icon: Icons.repeat_rounded,
      builder: (_) => const _FluencyBody(),
    );
  }
}

class _FluencyBody extends StatefulWidget {
  const _FluencyBody();

  @override
  State<_FluencyBody> createState() => _FluencyBodyState();
}

class _FluencyBodyState extends State<_FluencyBody> {
  final _audio = ReadingAudioService.instance;

  static const _passage = 'ගසේ ඉහළ අහසේ වලාකුළු පාවෙයි. කුරුල්ලෙක් ගසේ ඉඳ ගයයි.';
  static const _ladder = [
    'ගසේ',
    'ගසේ ඉහළ',
    'ගසේ ඉහළ අහසේ',
    'ගසේ ඉහළ අහසේ වලාකුළු පාවෙයි.',
  ];

  int _ladderStep = 0;
  int _wordCursor = -1;

  Future<void> _shadowRead() async {
    final words = _passage.split(' ');
    for (var i = 0; i < words.length; i++) {
      if (!mounted) return;
      setState(() => _wordCursor = i);
      await _audio.speak(words[i]);
      await Future.delayed(Duration(
        milliseconds: _audio.rate < 0.35 ? 900 : 650,
      ));
    }
    if (!mounted) return;
    setState(() => _wordCursor = -1);
  }

  Future<void> _stepLadder() async {
    await _audio.speak(_ladder[_ladderStep]);
  }

  void _nextLadder() {
    setState(() {
      _ladderStep = (_ladderStep + 1) % _ladder.length;
    });
  }

  void _resetLadder() {
    setState(() => _ladderStep = 0);
  }

  @override
  Widget build(BuildContext context) {
    final words = _passage.split(' ');
    return ListView(
      children: [
        _Section(
          title: 'අනුකරණයෙන් කියවීම',
          color: ReadingKidTheme.accent,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < words.length; i++)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _wordCursor == i
                        ? ReadingKidTheme.highlight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(words[i], style: ReadingKidTheme.passage),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PlayButton(
          label: 'මා සමඟ කියවන්න',
          color: ReadingKidTheme.accent,
          icon: Icons.headset_rounded,
          onTap: _shadowRead,
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'පියවරැති — පියවර ${_ladderStep + 1} / ${_ladder.length}',
          color: const Color(0xFFEF6C00),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            alignment: Alignment.center,
            child: Text(
              _ladder[_ladderStep],
              textAlign: TextAlign.center,
              style: ReadingKidTheme.chunk.copyWith(fontSize: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PlayButton(
                label: 'අසන්න',
                color: const Color(0xFFEF6C00),
                icon: Icons.volume_up_rounded,
                onTap: _stepLadder,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PlayButton(
                label: 'ඊළඟ පියවර',
                color: ReadingKidTheme.primary,
                icon: Icons.stairs_rounded,
                onTap: _nextLadder,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _resetLadder,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('ආයෙත් පටන් ගන්න'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.color, required this.child});
  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ReadingKidTheme.card,
        borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
        border: Border.all(color: color.withOpacity(.25), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: ReadingKidTheme.title.copyWith(color: color, fontSize: 20)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
