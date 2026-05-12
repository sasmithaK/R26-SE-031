import 'dart:async';
import 'package:flutter/material.dart';

import '../services/reading_audio_service.dart';
import '../theme/reading_theme.dart';
import 'mascot.dart';

/// Data about a single word that the child tapped.
class WordInfo {
  const WordInfo({
    required this.word,
    required this.difficulty,
    required this.errorType,
    this.syllables = const [],
  });
  final String word;
  final double difficulty;
  final String? errorType;
  final List<String> syllables;
}

/// Opens a full-screen modal with the correct mini-activity for the word,
/// guided by the owl mascot.
Future<void> showWordHelpModal(BuildContext context, WordInfo info) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(0.65),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (_, __, ___) => const SizedBox(),
    transitionBuilder: (context, anim1, anim2, child) {
      final scale = CurvedAnimation(parent: anim1, curve: Curves.elasticOut);
      final fade = CurvedAnimation(parent: anim1, curve: Curves.easeIn);
      return ScaleTransition(
        scale: scale,
        child: FadeTransition(
          opacity: fade,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: _WordHelpSheet(info: info),
            ),
          ),
        ),
      );
    },
  );
}

class _WordHelpSheet extends StatefulWidget {
  const _WordHelpSheet({required this.info});
  final WordInfo info;

  @override
  State<_WordHelpSheet> createState() => _WordHelpSheetState();
}

class _WordHelpSheetState extends State<_WordHelpSheet> {
  final _audio = ReadingAudioService.instance;

  String _mascotMsg = '';

  @override
  void initState() {
    super.initState();
    _setInitialMessage();
  }

  void _setInitialMessage() {
    final e = widget.info.errorType ?? 'none';
    switch (e) {
      case 'long_word':
        _mascotMsg = 'මේ දිගු වචනයක්! අපි කෑලි කෑලි කරමු 🎵';
        break;
      case 'consonant_confusion':
        _mascotMsg = 'පළමු අකුර හොඳට බලමු! 🔍';
        break;
      case 'vowel_sign':
        _mascotMsg = 'ස්වරය හොඳට අහන්න 🎶';
        break;
      case 'unfamiliar':
        _mascotMsg = 'අලුත් වචනයක්! අරුත දැනගමු 💡';
        break;
      default:
        _mascotMsg = 'මේ වචනය අසමු 🔊';
    }
  }

  Color get _themeColor {
    switch (widget.info.errorType) {
      case 'long_word':
        return const Color(0xFFEF6C00);
      case 'consonant_confusion':
        return const Color(0xFF6A1B9A);
      case 'vowel_sign':
        return const Color(0xFF1565C0);
      case 'unfamiliar':
        return const Color(0xFF2E7D32);
      default:
        return ReadingKidTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine a max width for the modal so it doesn't look stretched on wide screens
    final screenWidth = MediaQuery.of(context).size.width;
    final modalWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.9;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: modalWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 50),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                decoration: BoxDecoration(
                  color: ReadingKidTheme.background,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: _themeColor.withOpacity(.40), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: _themeColor.withOpacity(.25),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _WordCard(word: widget.info.word, color: _themeColor),
                      const SizedBox(height: 20),
                      _buildActivity(),
                      const SizedBox(height: 24),
                      _DoneButton(
                        color: _themeColor,
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -10,
                child: Mascot(
                  message: _mascotMsg,
                  size: 96,
                  onTap: () => _audio.speak(_mascotMsg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivity() {
    switch (widget.info.errorType) {
      case 'long_word':
        return _LongWordMini(info: widget.info, color: _themeColor);
      case 'consonant_confusion':
        return _ConsonantMini(info: widget.info, color: _themeColor);
      case 'vowel_sign':
        return _VowelMini(info: widget.info, color: _themeColor);
      case 'unfamiliar':
        return _UnfamiliarMini(info: widget.info, color: _themeColor);
      default:
        return _DefaultMini(info: widget.info, color: _themeColor);
    }
  }
}

// ─── Mini Activities ────────────────────────────────────────────────────────

class _LongWordMini extends StatefulWidget {
  const _LongWordMini({required this.info, required this.color});
  final WordInfo info;
  final Color color;

  @override
  State<_LongWordMini> createState() => _LongWordMiniState();
}

class _LongWordMiniState extends State<_LongWordMini> {
  final _audio = ReadingAudioService.instance;
  int _active = -1;
  Timer? _timer;

  List<String> get _parts {
    final w = widget.info.word;
    if (w.contains('සෞ') || w.contains('ඛ්')) return ['සෞ', 'ඛ්\u200dය', 'ය', 'ට'];
    if (w.contains('සමන')) return ['ස', 'ම', 'න', 'ල', 'යෙක්'];
    if (w.contains('කුරු') || w.contains('ලෙක්')) return ['කු', 'රුල්', 'ලෙක්'];
    if (w.contains('ගොවි') || w.contains('යා')) return ['ගො', 'වි', 'යා'];
    if (w.contains('වලා')) return ['ව', 'ලා', 'කු', 'ළු'];
    if (widget.info.syllables.isNotEmpty) return widget.info.syllables;
    return _splitSimple(widget.info.word);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _playBeats() async {
    _timer?.cancel();
    setState(() => _active = 0);
    await _audio.speak(_parts.first, kind: 'syllable');
    _timer = Timer.periodic(const Duration(milliseconds: 1200), (t) async {
      final next = _active + 1;
      if (next >= _parts.length) {
        t.cancel();
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        setState(() => _active = -1);
        await _audio.speak(widget.info.word);
        return;
      }
      if (!mounted) return;
      setState(() => _active = next);
      await _audio.speak(_parts[next], kind: 'syllable');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionTitle(text: 'කෑලි කෑලි කරමු', color: widget.color),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _parts.length; i++)
              _AnimatedChunk(
                text: _parts[i],
                active: _active == i,
                color: widget.color,
                onTap: () async {
                  setState(() => _active = i);
                  await _audio.speak(_parts[i], kind: 'syllable');
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        _ActionButton(
          label: 'එක එක අකුර අසන්න 🥁',
          color: widget.color,
          icon: Icons.graphic_eq_rounded,
          onTap: _playBeats,
        ),
        const SizedBox(height: 10),
        _ActionButton(
          label: 'මුළු වචනය අසන්න 🔊',
          color: ReadingKidTheme.accent,
          icon: Icons.volume_up_rounded,
          onTap: () => _audio.speak(widget.info.word),
        ),
      ],
    );
  }
}

class _ConsonantMini extends StatefulWidget {
  const _ConsonantMini({required this.info, required this.color});
  final WordInfo info;
  final Color color;

  @override
  State<_ConsonantMini> createState() => _ConsonantMiniState();
}

class _ConsonantMiniState extends State<_ConsonantMini> {
  final _audio = ReadingAudioService.instance;
  bool _anchor = true;

  String get _first {
    final w = widget.info.word;
    if (w.contains('කුරු') || w.contains('ලෙක්')) return 'කු';
    if (w.contains('ගොවි') || w.contains('යා')) return 'ගො';
    if (w.contains('සෞ') || w.contains('ඛ්')) return 'සෞ';
    if (w.contains('සමන')) return 'ස';
    if (w.contains('වලා')) return 'ව';
    return w.length <= 1 ? w : w.substring(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionTitle(text: 'පළමු හඬ බලමු', color: widget.color),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: ReadingKidTheme.chunk.copyWith(fontSize: 50),
            children: [
              TextSpan(
                text: _first,
                style: TextStyle(
                  backgroundColor:
                      _anchor ? ReadingKidTheme.highlight : Colors.transparent,
                  fontWeight: FontWeight.w900,
                  fontSize: 56,
                ),
              ),
              TextSpan(
                text: widget.info.word.substring(_first.length),
                style: TextStyle(
                  color: _anchor
                      ? ReadingKidTheme.textSoft.withOpacity(.45)
                      : ReadingKidTheme.textMain,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ActionButton(
          label: 'පළමු හඬ අසන්න 🔍',
          color: widget.color,
          icon: Icons.volume_up_rounded,
          onTap: () {
            setState(() => _anchor = true);
            _audio.speak(_first, kind: 'first_sound');
          },
        ),
        const SizedBox(height: 10),
        _ActionButton(
          label: 'මුළු වචනය අසන්න 🔊',
          color: ReadingKidTheme.accent,
          icon: Icons.menu_book_rounded,
          onTap: () {
            setState(() => _anchor = false);
            _audio.speak(widget.info.word);
          },
        ),
      ],
    );
  }
}

class _VowelMini extends StatefulWidget {
  const _VowelMini({required this.info, required this.color});
  final WordInfo info;
  final Color color;

  @override
  State<_VowelMini> createState() => _VowelMiniState();
}

class _VowelMiniState extends State<_VowelMini> {
  final _audio = ReadingAudioService.instance;
  int _stage = 0;
  static const _labels = ['ඉලක්කය', 'ව්\u200dයඤ්ජනය', 'ස්වරය', 'එක්ව', 'මුළු වචනය'];
  static const _colors = [
    ReadingKidTheme.primary,
    ReadingKidTheme.primary,
    ReadingKidTheme.accent,
    Color(0xFFEF6C00),
    Color(0xFF6A1B9A),
  ];

  String get _first {
    final w = widget.info.word;
    if (w.contains('ගොවි') || w.contains('යා')) return 'ග';
    if (w.contains('සෞ') || w.contains('ඛ්')) return 'ස';
    if (w.contains('කුරු') || w.contains('ලෙක්')) return 'ක';
    return w.length <= 1 ? w : w.substring(0, 1);
  }

  String get _vowel {
    final w = widget.info.word;
    if (w.contains('ගොවි') || w.contains('යා')) return 'ඔ';
    if (w.contains('සෞ') || w.contains('ඛ්')) return 'ඖ';
    if (w.contains('කුරු') || w.contains('ලෙක්')) return 'උ';
    return 'අ';
  }

  String get _blended {
    final w = widget.info.word;
    if (w.contains('ගොවි') || w.contains('යා')) return 'ගො';
    if (w.contains('සෞ') || w.contains('ඛ්')) return 'සෞ';
    if (w.contains('කුරු') || w.contains('ලෙක්')) return 'කු';
    return w.length <= 1 ? w : w.substring(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionTitle(text: 'ස්වරය එක් කරමු', color: widget.color),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
            border: Border.all(
              color: _colors[_stage].withOpacity(.35),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                _labels[_stage],
                style: ReadingKidTheme.hint
                    .copyWith(color: _colors[_stage], fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _stage == 0
                    ? widget.info.word
                    : (_stage == 1
                        ? _first
                        : (_stage == 2
                            ? _vowel
                            : (_stage == 3 ? _blended : widget.info.word))),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: ReadingKidTheme.textMain,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var s = 1; s <= 4; s++) ...[
          _ActionButton(
            label: '$s. ${_labels[s]}',
            color: _colors[s],
            icon: Icons.volume_up_rounded,
            onTap: () {
              setState(() => _stage = s);
              final text = s == 1
                  ? _first
                  : (s == 2
                      ? _vowel
                      : (s == 3 ? _blended : widget.info.word));
              _audio.speak(text, kind: s <= 2 ? 'syllable' : 'word');
            },
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _UnfamiliarMini extends StatefulWidget {
  const _UnfamiliarMini({required this.info, required this.color});
  final WordInfo info;
  final Color color;

  @override
  State<_UnfamiliarMini> createState() => _UnfamiliarMiniState();
}

class _UnfamiliarMiniState extends State<_UnfamiliarMini> {
  final _audio = ReadingAudioService.instance;
  int? _picked;

  String get _emoji {
    final w = widget.info.word;
    if (w.contains('සෞ') || w.contains('ඛ්')) return '🍎';
    if (w.contains('කුරු') || w.contains('ලෙක්')) return '🐦';
    if (w.contains('සමන')) return '🦋';
    if (w.contains('ගොවි') || w.contains('යා')) return '👨\u200d🌾';
    if (w.contains('වලා')) return '☁️';
    if (w.contains('ගසේ')) return '🌳';
    if (w.contains('මල්')) return '🌸';
    if (w.contains('ආහාර')) return '🍲';
    return '💡';
  }

  List<String> get _options {
    final w = widget.info.word;
    if (w.contains('සෞ') || w.contains('ඛ්')) return ['නිරෝගී බව', 'අසනීප වීම'];
    if (w.contains('කුරු') || w.contains('ලෙක්')) return ['පියාඹන සතා', 'ගහක්'];
    if (w.contains('සමන')) return ['ලස්සන කුඩා සතා', 'බල්ලෙක්'];
    if (w.contains('ගොවි') || w.contains('යා')) return ['වී වවන කෙනා', 'ගුරුවරයා'];
    if (w.contains('වලා')) return ['අහසේ පාවෙන දේ', 'බිම තියෙන දේ'];
    if (w.contains('ගසේ')) return ['කොළ තියෙන ලොකු ශාකය', 'වතුර'];
    if (w.contains('මල්')) return ['සුවඳ දෙන ලස්සන දේ', 'ගල්'];
    if (w.contains('ආහාර')) return ['කෑම බීම', 'සෙල්ලම් බඩු'];
    return ['හරි තේරුම', 'වැරදි තේරුම'];
  }

  int get _correct => 0;

  void _pick(int i) async {
    setState(() => _picked = i);
    await _audio.speak(i == _correct ? 'හරියි!' : 'ආයෙත් උත්සාහ කරන්න.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionTitle(text: 'අරුත දැනගමු', color: widget.color),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
            border: Border.all(color: widget.color.withOpacity(.30), width: 2),
          ),
          child: Column(
            children: [
              _PictureSticker(emoji: _emoji, color: widget.color),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.color.withOpacity(.45), width: 2),
                ),
                child: Text(
                  widget.info.word,
                  style: ReadingKidTheme.chunk.copyWith(fontSize: 34),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'වචනය 🔊',
                color: widget.color,
                icon: Icons.volume_up_rounded,
                onTap: () => _audio.speak(widget.info.word),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'හෙමින් 🐢',
                color: ReadingKidTheme.accent,
                icon: Icons.slow_motion_video_rounded,
                onTap: () => _audio.speak(widget.info.word, kind: 'syllable'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('මේකේ අරුත මොකක්ද?', style: ReadingKidTheme.title.copyWith(fontSize: 22)),
        const SizedBox(height: 8),
        for (var i = 0; i < _options.length; i++) ...[
          _OptionButton(
            text: _options[i],
            picked: _picked == i,
            correct: _picked != null && i == _correct,
            wrong: _picked == i && i != _correct,
            onTap: () => _pick(i),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DefaultMini extends StatelessWidget {
  const _DefaultMini({required this.info, required this.color});
  final WordInfo info;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final audio = ReadingAudioService.instance;
    return Column(
      children: [
        _SectionTitle(text: 'වචනය අසමු', color: color),
        const SizedBox(height: 12),
        _ActionButton(
          label: 'වචනය අසන්න 🔊',
          color: color,
          icon: Icons.volume_up_rounded,
          onTap: () => audio.speak(info.word),
        ),
      ],
    );
  }
}

// ─── Shared small widgets ───────────────────────────────────────────────────

class _BouncingWidget extends StatefulWidget {
  const _BouncingWidget({required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  State<_BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<_BouncingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95).chain(CurveTween(curve: Curves.easeInOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
    ]).animate(_ctrl);

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: widget.child,
    );
  }
}

class _PulsingWidget extends StatefulWidget {
  const _PulsingWidget({required this.child});
  final Widget child;

  @override
  State<_PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<_PulsingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: widget.child,
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.word, required this.color});
  final String word;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _PulsingWidget(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(.18), color.withOpacity(.06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
          border: Border.all(color: color.withOpacity(.40), width: 2),
        ),
        child: Center(
          child: Text(
            word,
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              color: ReadingKidTheme.textMain,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: ReadingKidTheme.title.copyWith(color: color, fontSize: 22),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BouncingWidget(
      delay: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(.25), width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(.6),
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedChunk extends StatelessWidget {
  const _AnimatedChunk({
    required this.text,
    required this.active,
    required this.color,
    required this.onTap,
  });
  final String text;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: active ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: active ? color : color.withOpacity(.12),
        borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
        elevation: active ? 4 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            constraints: const BoxConstraints(minWidth: 72, minHeight: 60),
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : ReadingKidTheme.textMain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BouncingWidget(
      delay: const Duration(milliseconds: 400),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: color.withOpacity(.45), width: 3),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(.3),
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: color, size: 30),
              const SizedBox(width: 8),
              Text(
                'හරි, තේරුණා! 🌟',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Round colourful "sticker" tile holding a Twemoji image.
class _PictureSticker extends StatelessWidget {
  const _PictureSticker({required this.emoji, required this.color});

  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final url = _twemojiUrl(emoji);
    return _PulsingWidget(
      child: Container(
        width: 140,
        height: 140,
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
            width: 90,
            height: 90,
            filterQuality: FilterQuality.medium,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: color,
                ),
              );
            },
            errorBuilder: (_, __, ___) => Text(
              emoji,
              style: const TextStyle(fontSize: 70),
            ),
          ),
        ),
      ),
    );
  }

  static String _twemojiUrl(String emoji) {
    final hex = emoji.runes
        .where((r) => r != 0xFE0F)
        .map((r) => r.toRadixString(16))
        .join('-');
    return 'https://cdn.jsdelivr.net/gh/twitter/twemoji@latest/assets/72x72/$hex.png';
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
    return _BouncingWidget(
      delay: const Duration(milliseconds: 600),
      child: Material(
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
              boxShadow: picked ? [
                BoxShadow(
                  color: border.withOpacity(.3),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                )
              ] : null,
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
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(text,
                      style: ReadingKidTheme.passage.copyWith(fontSize: 22)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<String> _splitSimple(String word) {
  if (word.length <= 2) return [word];
  final chunks = <String>[];
  final runes = word.runes.toList();
  for (var i = 0; i < runes.length; i += 2) {
    final end = (i + 2).clamp(0, runes.length);
    chunks.add(String.fromCharCodes(runes.sublist(i, end)));
  }
  return chunks;
}
