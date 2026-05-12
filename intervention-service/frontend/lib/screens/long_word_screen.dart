import 'dart:async';
import 'package:flutter/material.dart';

import '../services/reading_audio_service.dart';
import '../theme/reading_theme.dart';
import '../widgets/activity_shell.dart';

class LongWordScreen extends StatelessWidget {
  const LongWordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ActivityShell(
      title: 'දිගු වචන — තාල පෙට්ටිය',
      subtitle: 'මුළු වචනය අසා, එක එක අකුරු අසා, පසුව එක්ව කියමු.',
      icon: Icons.straighten_rounded,
      builder: (_) => const _BeatBarBody(),
    );
  }
}

class _BeatBarBody extends StatefulWidget {
  const _BeatBarBody();

  @override
  State<_BeatBarBody> createState() => _BeatBarBodyState();
}

class _BeatBarBodyState extends State<_BeatBarBody> {
  final _audio = ReadingAudioService.instance;

  static const String _word = 'සෞඛ්\u200dයයට';
  static const String _sentence = 'අපේ සෞඛ්\u200dයයට ඇපල් හොඳයි.';
  static const List<String> _syllables = ['සෞ', 'ඛ්\u200dය', 'ය', 'ට'];

  int _active = -1;
  Timer? _beatTimer;

  @override
  void dispose() {
    _beatTimer?.cancel();
    super.dispose();
  }

  Future<void> _playWhole() async {
    setState(() => _active = -1);
    await _audio.speak(_word);
  }

  Future<void> _playBeats() async {
    _beatTimer?.cancel();
    setState(() => _active = 0);
    await _audio.speak(_syllables.first);

    final stepMs = _audio.rate < 0.35 ? 1500 : 1100;
    _beatTimer = Timer.periodic(Duration(milliseconds: stepMs), (t) async {
      final next = _active + 1;
      if (next >= _syllables.length) {
        t.cancel();
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        setState(() => _active = -1);
        await _audio.speak(_word);
        return;
      }
      if (!mounted) return;
      setState(() => _active = next);
      await _audio.speak(_syllables[next]);
    });
  }

  Future<void> _tapBeat(int i) async {
    setState(() => _active = i);
    await _audio.speak(_syllables[i]);
  }

  Future<void> _yourTurn() async {
    _beatTimer?.cancel();
    setState(() => _active = -1);
    await _audio.speak('ඔයාට පුළුවන්ද කියන්න?');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ReadingKidTheme.card,
            borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
            border: Border.all(color: ReadingKidTheme.primary.withOpacity(.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('මේ වාක්\u200dයයේ:', style: ReadingKidTheme.hint),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: ReadingKidTheme.passage,
                  children: _highlightedSentence(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _syllables.length; i++)
              ChunkBox(
                text: _syllables[i],
                active: _active == i,
                onTap: () => _tapBeat(i),
              ),
          ],
        ),
        const SizedBox(height: 18),
        PlayButton(
          label: 'මුළු වචනය අසන්න',
          icon: Icons.volume_up_rounded,
          color: ReadingKidTheme.primary,
          onTap: _playWhole,
        ),
        const SizedBox(height: 10),
        PlayButton(
          label: 'එක එක අකුර අසන්න',
          icon: Icons.graphic_eq_rounded,
          color: ReadingKidTheme.accent,
          onTap: _playBeats,
        ),
        const SizedBox(height: 10),
        PlayButton(
          label: 'දැන් ඔයාට!',
          icon: Icons.record_voice_over_rounded,
          color: const Color(0xFFEF6C00),
          onTap: _yourTurn,
        ),
      ],
    );
  }

  List<TextSpan> _highlightedSentence() {
    final parts = _sentence.split(_word);
    final spans = <TextSpan>[];
    for (var i = 0; i < parts.length; i++) {
      spans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        spans.add(
          TextSpan(
            text: _word,
            style: const TextStyle(
              backgroundColor: ReadingKidTheme.highlight,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }
    }
    return spans;
  }
}
