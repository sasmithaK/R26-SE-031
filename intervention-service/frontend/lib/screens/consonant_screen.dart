import 'package:flutter/material.dart';

import '../services/reading_audio_service.dart';
import '../theme/reading_theme.dart';
import '../widgets/activity_shell.dart';
import '../widgets/reward_animation.dart';

class ConsonantScreen extends StatelessWidget {
  const ConsonantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ActivityShell(
      title: 'ව්\u200dයඤ්ජන හඬ — පළමු හඬ',
      subtitle: 'පළමු අකුර බලමු. අසමු, පෙන්වමු, පසුව මුළු වචනය කියවමු.',
      icon: Icons.graphic_eq_rounded,
      builder: (_) => const _ConsonantBody(),
    );
  }
}

class _Item {
  const _Item(this.word, this.firstChunk, this.rest, this.cue);
  final String word;
  final String firstChunk;
  final String rest;
  final String cue;
}

class _ConsonantBody extends StatefulWidget {
  const _ConsonantBody();

  @override
  State<_ConsonantBody> createState() => _ConsonantBodyState();
}

class _ConsonantBodyState extends State<_ConsonantBody> {
  final _audio = ReadingAudioService.instance;
  final List<_Item> _items = const [
    _Item('බල්ලා', 'බ', 'ල්ලා', 'පළමු හඬ: බ'),
    _Item('දන්නවා', 'ද', 'න්නවා', 'පළමු හඬ: ද'),
    _Item('පොත', 'පො', 'ත', 'පළමු හඬ: පො'),
    _Item('මල', 'ම', 'ල', 'පළමු හඬ: ම'),
  ];
  int _idx = 0;
  bool _anchor = true;
  bool _showReward = false;

  _Item get _cur => _items[_idx];

  Future<void> _playFirst() async {
    setState(() {
      _anchor = true;
      _showReward = false;
    });
    await _audio.speak('${_cur.firstChunk} යන්න');
  }

  Future<void> _playWhole() async {
    setState(() {
      _anchor = false;
      _showReward = true; // Show reward when they finish the word!
    });
    await _audio.speak(_cur.word);
  }

  void _next() {
    setState(() {
      _idx = (_idx + 1) % _items.length;
      _anchor = true;
      _showReward = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ReadingKidTheme.card,
                borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
                border: Border.all(color: ReadingKidTheme.accent.withOpacity(.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(_cur.cue, style: ReadingKidTheme.hint),
                  const SizedBox(height: 10),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: ReadingKidTheme.chunk,
                      children: [
                        TextSpan(
                          text: _cur.firstChunk,
                          style: TextStyle(
                            backgroundColor:
                                _anchor ? ReadingKidTheme.highlight : Colors.transparent,
                            color: ReadingKidTheme.textMain,
                            fontWeight: FontWeight.w900,
                            fontSize: 48,
                          ),
                        ),
                        TextSpan(
                          text: _cur.rest,
                          style: TextStyle(
                            color: _anchor
                                ? ReadingKidTheme.textSoft.withOpacity(.55)
                                : ReadingKidTheme.textMain,
                            fontSize: 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PlayButton(
              label: 'පළමු හඬ අසන්න',
              icon: Icons.volume_up_rounded,
              color: ReadingKidTheme.primary,
              onTap: _playFirst,
            ),
            const SizedBox(height: 10),
            PlayButton(
              label: 'මුළු වචනය අසන්න',
              icon: Icons.menu_book_rounded,
              color: ReadingKidTheme.accent,
              onTap: _playWhole,
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
              emoji: '👏',
              text: 'සුපිරි!',
            ),
          ),
      ],
    );
  }
}
