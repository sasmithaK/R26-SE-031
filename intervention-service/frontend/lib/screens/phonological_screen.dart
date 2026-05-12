import 'package:flutter/material.dart';

import '../services/reading_audio_service.dart';
import '../theme/reading_theme.dart';
import '../widgets/activity_shell.dart';

class PhonologicalScreen extends StatelessWidget {
  const PhonologicalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ActivityShell(
      title: 'හඬ රටා',
      subtitle: 'ප්\u200dරාසය අසන්න. එම අන්තයෙන් කෙළවර වන වචනය තෝරන්න.',
      icon: Icons.queue_music_rounded,
      builder: (_) => const _PhonoBody(),
    );
  }
}

class _RhymeSet {
  const _RhymeSet(this.target, this.options, this.correct);
  final String target;
  final List<String> options;
  final int correct;
}

class _PhonoBody extends StatefulWidget {
  const _PhonoBody();

  @override
  State<_PhonoBody> createState() => _PhonoBodyState();
}

class _PhonoBodyState extends State<_PhonoBody> {
  final _audio = ReadingAudioService.instance;
  final List<_RhymeSet> _sets = const [
    _RhymeSet('පොත', ['ගස', 'කොත', 'වතුර'], 1),
    _RhymeSet('කොළ', ['වැළ', 'හීන', 'ගෙය'], 0),
    _RhymeSet('කෑම', ['වැඩ', 'පැම', 'වතුර'], 1),
  ];
  int _idx = 0;
  int? _picked;

  _RhymeSet get _s => _sets[_idx];

  Future<void> _playTarget() async => _audio.speak(_s.target);
  Future<void> _playOption(int i) async {
    setState(() => _picked = i);
    await _audio.speak(_s.options[i]);
  }

  void _check() async {
    if (_picked == null) return;
    final ok = _picked == _s.correct;
    await _audio.speak(ok ? 'හරියි! නියමයි.' : 'ආයෙත් උත්සාහ කරන්න.');
  }

  void _next() {
    setState(() {
      _idx = (_idx + 1) % _sets.length;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ReadingKidTheme.card,
            borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
            border: Border.all(color: ReadingKidTheme.primary.withOpacity(.25)),
          ),
          child: Column(
            children: [
              Text('මේ වචනය අසන්න', style: ReadingKidTheme.hint),
              const SizedBox(height: 8),
              Text(_s.target,
                  style: ReadingKidTheme.chunk.copyWith(fontSize: 48)),
              const SizedBox(height: 10),
              PlayButton(
                label: 'වචනය වාදනය',
                color: ReadingKidTheme.primary,
                onTap: _playTarget,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('ප්\u200dරාසනය වන වචනය මොකක්ද?', style: ReadingKidTheme.title),
        const SizedBox(height: 8),
        for (var i = 0; i < _s.options.length; i++) ...[
          _RhymeButton(
            text: _s.options[i],
            picked: _picked == i,
            onTap: () => _playOption(i),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PlayButton(
                label: 'බලන්න',
                color: ReadingKidTheme.accent,
                icon: Icons.check_rounded,
                onTap: _check,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('ඊළඟ'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RhymeButton extends StatelessWidget {
  const _RhymeButton({
    required this.text,
    required this.picked,
    required this.onTap,
  });
  final String text;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: picked
          ? ReadingKidTheme.accent.withOpacity(.12)
          : ReadingKidTheme.card,
      borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: picked
                  ? ReadingKidTheme.accent
                  : ReadingKidTheme.accent.withOpacity(.25),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
          ),
          child: Row(
            children: [
              Icon(Icons.volume_up_rounded,
                  color: ReadingKidTheme.accent, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: ReadingKidTheme.passage.copyWith(fontSize: 22)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
