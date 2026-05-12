import 'package:flutter/material.dart';

import '../services/reading_audio_service.dart';
import '../theme/reading_theme.dart';
import '../widgets/activity_shell.dart';
import '../widgets/reward_animation.dart';

class VowelScreen extends StatelessWidget {
  const VowelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ActivityShell(
      title: 'ස්වර ලකුණු — අසා එක් කරමු',
      subtitle: 'ව්\u200dයඤ්ජනය, ස්වරය, එක්ව, මුළු වචනය. තෝරන්න ඕනේ නෑ.',
      icon: Icons.music_note_rounded,
      builder: (_) => const _VowelBody(),
    );
  }
}

class _Target {
  const _Target(this.word, this.consonant, this.vowelSound, this.syllable);
  final String word;
  final String consonant;
  final String vowelSound;
  final String syllable;
}

class _VowelBody extends StatefulWidget {
  const _VowelBody();

  @override
  State<_VowelBody> createState() => _VowelBodyState();
}

class _VowelBodyState extends State<_VowelBody> {
  final _audio = ReadingAudioService.instance;
  final List<_Target> _targets = const [
    _Target('පොත', 'ප්', 'ඔ', 'පො'),
    _Target('මේසය', 'ම්', 'ඒ', 'මේ'),
    _Target('පිහිය', 'ප්', 'ඉ', 'පි'),
    _Target('පුළුවන්', 'ප්', 'උ', 'පු'),
  ];
  int _idx = 0;
  int _stage = 0;

  _Target get _t => _targets[_idx];

  bool _showReward = false;

  Future<void> _stepConsonant() async {
    setState(() {
      _stage = 1;
      _showReward = false;
    });
    await _audio.speak('${_t.consonant} ශබ්දය');
  }

  Future<void> _stepVowel() async {
    setState(() {
      _stage = 2;
      _showReward = false;
    });
    await _audio.speak('${_t.vowelSound} ශබ්දය');
  }

  Future<void> _stepBlend() async {
    setState(() {
      _stage = 3;
      _showReward = false;
    });
    await _audio.speak('${_t.syllable} යන්න');
  }

  Future<void> _stepWord() async {
    setState(() {
      _stage = 4;
      _showReward = true; // Show reward when they finish the word!
    });
    await _audio.speak(_t.word);
  }

  void _next() {
    setState(() {
      _idx = (_idx + 1) % _targets.length;
      _stage = 0;
      _showReward = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          children: [
            _Stage(target: _t, stage: _stage),
            const SizedBox(height: 18),
            PlayButton(
              label: '1.  ව්\u200dයඤ්ජනය අසන්න',
              color: ReadingKidTheme.primary,
              onTap: _stepConsonant,
            ),
            const SizedBox(height: 10),
            PlayButton(
              label: '2.  ස්වරය අසන්න',
              color: ReadingKidTheme.accent,
              onTap: _stepVowel,
            ),
            const SizedBox(height: 10),
            PlayButton(
              label: '3.  එක්ව කියන්න',
              color: const Color(0xFFEF6C00),
              onTap: _stepBlend,
            ),
            const SizedBox(height: 10),
            PlayButton(
              label: '4.  මුළු වචනය කියවන්න',
              color: const Color(0xFF6A1B9A),
              onTap: _stepWord,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('ඊළඟ වචනය'),
            ),
          ],
        ),
        if (_showReward)
          Positioned(
            top: 20,
            right: 10,
            child: const BouncingReward(
              emoji: '⭐',
              text: 'නියමයි!',
            ),
          ),
      ],
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.target, required this.stage});
  final _Target target;
  final int stage;

  @override
  Widget build(BuildContext context) {
    String big;
    String hint;
    Color color;
    switch (stage) {
      case 1:
        big = target.consonant;
        hint = 'ව්\u200dයඤ්ජනය';
        color = ReadingKidTheme.primary;
        break;
      case 2:
        big = target.vowelSound;
        hint = 'ස්වරය';
        color = ReadingKidTheme.accent;
        break;
      case 3:
        big = target.syllable;
        hint = 'එක්ව';
        color = const Color(0xFFEF6C00);
        break;
      case 4:
        big = target.word;
        hint = 'මුළු වචනය';
        color = const Color(0xFF6A1B9A);
        break;
      default:
        big = target.word;
        hint = 'ඉලක්ක වචනය';
        color = ReadingKidTheme.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: ReadingKidTheme.card,
        borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
        border: Border.all(color: color.withOpacity(.25), width: 2),
      ),
      child: Column(
        children: [
          Text(hint, style: ReadingKidTheme.hint.copyWith(color: color)),
          const SizedBox(height: 12),
          Text(
            big,
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: ReadingKidTheme.textMain,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
