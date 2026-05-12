import 'package:flutter/material.dart';

import '../services/reading_audio_service.dart';
import '../theme/reading_theme.dart';
import '../widgets/activity_shell.dart';

class UnfamiliarScreen extends StatelessWidget {
  const UnfamiliarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ActivityShell(
      title: 'අලුත් වචන — අරුත මුලින්',
      subtitle: 'පින්තූරයත් කෙටි වාක්\u200dයයත් මුලින්, පසුව අලුත් වචනය අසන්න.',
      icon: Icons.lightbulb_rounded,
      builder: (_) => const _UnfamiliarBody(),
    );
  }
}

class _NewWord {
  const _NewWord({
    required this.word,
    required this.emoji,
    required this.sentence,
    required this.meaning,
    required this.options,
    required this.correct,
    required this.frame,
  });
  final String word;
  final String emoji;
  final String sentence;
  final String meaning;
  final List<String> options;
  final int correct;
  final Color frame;
}

class _UnfamiliarBody extends StatefulWidget {
  const _UnfamiliarBody();

  @override
  State<_UnfamiliarBody> createState() => _UnfamiliarBodyState();
}

class _UnfamiliarBodyState extends State<_UnfamiliarBody> {
  final _audio = ReadingAudioService.instance;
  final List<_NewWord> _words = const [
    _NewWord(
      word: 'ගොවියා',
      emoji: '👨\u200d🌾',
      sentence: 'ගොවියා කුඹුරේ වැඩ කරයි.',
      meaning: 'වී වවන කෙනා',
      options: ['වී වවන කෙනා', 'පාසලේ උගන්වන කෙනා'],
      correct: 0,
      frame: Color(0xFF66BB6A),
    ),
    _NewWord(
      word: 'වලාකුළ',
      emoji: '☁️',
      sentence: 'වලාකුළ අහසේ පාවෙයි.',
      meaning: 'අහසේ තියෙන සුදු දේ',
      options: ['අහසේ තියෙන සුදු දේ', 'ගසේ පල'],
      correct: 0,
      frame: Color(0xFF42A5F5),
    ),
    _NewWord(
      word: 'සමනලයා',
      emoji: '🦋',
      sentence: 'සමනලයා මල් මත වාඩි වෙයි.',
      meaning: 'පියාපත් ඇති පුංචි සතා',
      options: ['පියාපත් ඇති පුංචි සතා', 'හතර කකුල් ඇති සතා'],
      correct: 0,
      frame: Color(0xFFAB47BC),
    ),
    _NewWord(
      word: 'තාරකාව',
      emoji: '⭐',
      sentence: 'තාරකාව රාත්\u200dරියේ බබලයි.',
      meaning: 'අහසේ බබලන කුඩා එළිය',
      options: ['අහසේ බබලන කුඩා එළිය', 'ඉරේ එළිය'],
      correct: 0,
      frame: Color(0xFFFFB300),
    ),
  ];
  int _idx = 0;
  int? _picked;
  bool _revealedWord = false;

  _NewWord get _w => _words[_idx];

  Future<void> _hearSentence() async => _audio.speak(_w.sentence);
  Future<void> _hearWord() async {
    setState(() => _revealedWord = true);
    await _audio.speak(_w.word);
  }

  void _pick(int i) async {
    setState(() => _picked = i);
    await _audio.speak(i == _w.correct ? 'හරියි!' : 'ආයෙත් උත්සාහ කරන්න.');
  }

  void _next() {
    setState(() {
      _idx = (_idx + 1) % _words.length;
      _picked = null;
      _revealedWord = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: ReadingKidTheme.card,
            borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
            border: Border.all(color: _w.frame.withOpacity(.30), width: 2),
            boxShadow: [
              BoxShadow(
                color: _w.frame.withOpacity(.10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              _PictureSticker(emoji: _w.emoji, color: _w.frame),
              const SizedBox(height: 14),
              Text(
                _w.sentence,
                textAlign: TextAlign.center,
                style: ReadingKidTheme.passage,
              ),
              const SizedBox(height: 12),
              if (_revealedWord)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: _w.frame.withOpacity(.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _w.frame.withOpacity(.45), width: 2),
                  ),
                  child: Text(
                    _w.word,
                    style: ReadingKidTheme.chunk.copyWith(fontSize: 34),
                  ),
                ),
              _ProgressDots(total: _words.length, active: _idx, color: _w.frame),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PlayButton(
          label: 'වාක්\u200dයය අසන්න',
          color: ReadingKidTheme.accent,
          onTap: _hearSentence,
        ),
        const SizedBox(height: 10),
        PlayButton(
          label: 'අලුත් වචනය අසන්න',
          color: ReadingKidTheme.primary,
          onTap: _hearWord,
        ),
        const SizedBox(height: 18),
        Text('මේකේ අරුත මොකක්ද?', style: ReadingKidTheme.title),
        const SizedBox(height: 8),
        for (var i = 0; i < _w.options.length; i++) ...[
          _OptionButton(
            text: _w.options[i],
            picked: _picked == i,
            correct: _picked != null && i == _w.correct,
            wrong: _picked == i && i != _w.correct,
            onTap: () => _pick(i),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _next,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('ඊළඟ වචනය'),
        ),
      ],
    );
  }
}

/// Round colourful "sticker" tile holding a Twemoji image.
/// Falls back to the system emoji glyph if the network image fails to load.
class _PictureSticker extends StatelessWidget {
  const _PictureSticker({required this.emoji, required this.color});

  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final url = _twemojiUrl(emoji);
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(.28), color.withOpacity(.08)],
          radius: 0.85,
        ),
        border: Border.all(color: color.withOpacity(.55), width: 4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Image.network(
          url,
          width: 108,
          height: 108,
          filterQuality: FilterQuality.medium,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: color,
              ),
            );
          },
          errorBuilder: (_, __, ___) => Text(
            emoji,
            style: const TextStyle(fontSize: 84),
          ),
        ),
      ),
    );
  }

  /// Build a Twemoji CDN URL from an emoji string. Drops the U+FE0F variant
  /// selector because Twemoji's filenames omit it.
  static String _twemojiUrl(String emoji) {
    final hex = emoji.runes
        .where((r) => r != 0xFE0F)
        .map((r) => r.toRadixString(16))
        .join('-');
    return 'https://cdn.jsdelivr.net/gh/twitter/twemoji@latest/assets/72x72/$hex.png';
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.total,
    required this.active,
    required this.color,
  });
  final int total;
  final int active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == active ? 18 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: i == active ? color : color.withOpacity(.25),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.text,
    required this.picked,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });
  final String text;
  final bool picked;
  final bool correct;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color border = ReadingKidTheme.accent.withOpacity(.25);
    Color bg = ReadingKidTheme.card;
    if (correct) {
      border = ReadingKidTheme.primary;
      bg = ReadingKidTheme.primary.withOpacity(.12);
    } else if (wrong) {
      border = Colors.redAccent;
      bg = Colors.redAccent.withOpacity(.10);
    } else if (picked) {
      border = ReadingKidTheme.accent;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 2),
            borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
          ),
          child: Row(
            children: [
              Icon(
                correct
                    ? Icons.check_circle_rounded
                    : (wrong ? Icons.close_rounded : Icons.circle_outlined),
                color: correct
                    ? ReadingKidTheme.primary
                    : (wrong ? Colors.redAccent : ReadingKidTheme.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: ReadingKidTheme.passage.copyWith(fontSize: 20)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
