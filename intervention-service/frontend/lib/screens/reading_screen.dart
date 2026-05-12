import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/reading_audio_service.dart';
import '../theme/reading_theme.dart';
import '../widgets/mascot.dart';
import '../widgets/word_help_modal.dart';

/// The main reading experience: a passage is shown, the child reads it,
/// and taps any word they struggle with. The owl mascot pops up, the word
/// is analysed by Model 1 (via the backend), and the matching mini-activity
/// opens in a colourful bottom-sheet.
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final _audio = ReadingAudioService.instance;

  static const _backendBase = 'http://127.0.0.1:8000';
  static const _passage =
      'ගසේ ඉහළ කුරුල්ලෙක් ඉඳ ගයයි. '
      'ඔහු ලස්සන ගී ගයයි. '
      'අහසේ සුදු වලාකුළු පාවෙයි. '
      'පොඩි සමනලයෙක් මල් මත වාඩි වෙයි. '
      'ගොවියා කුඹුරේ සෞඛ්\u200dයයට හොඳ ආහාර වවයි.';

  List<_WordData> _words = [];
  bool _loading = true;
  String _mascotMsg = 'අපි කතාවක් කියවමු! 📖';
  Set<int> _helped = {};

  // Playback state
  bool _isPlaying = false;
  int _playIndex = -1;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _audio.init();
    _loadPassage();
  }

  Future<void> _loadPassage() async {
    setState(() => _loading = true);

    try {
      final uri = Uri.parse('$_backendBase/api/v1/c4/passage/start');
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'student_id': 'demo_student',
              'session_id': 'demo_session',
              'passage_text': _passage,
              'language': 'si',
              'pre_generate_audio': true,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final wordList = (body['words'] as List?) ?? [];

        // MOCK OVERRIDE: For the demo, we want to map specific words in the paragraph
        // to their ideal error type and difficulty so the modal activity perfectly fits.
        _words = wordList.map((w) {
          final m = w as Map<String, dynamic>;
          String text = m['word_text'] as String? ?? '';
          double diff = (m['difficulty_score'] as num?)?.toDouble() ?? 0;
          String? eType = m['error_type_hint'] as String?;

          if (text.contains('සෞ') || text.contains('ඛ්')) {
            eType = 'long_word';
            diff = 0.8;
          } else if (text.contains('කුරු') || text.contains('ලෙක්')) {
            eType = 'consonant_confusion';
            diff = 0.6;
          } else if (text.contains('ගොවි') || text.contains('යා')) {
            eType = 'vowel_sign';
            diff = 0.5;
          } else if (text.contains('වලා') || text.contains('සමන') || text.contains('ආහාර')) {
            eType = 'unfamiliar';
            diff = 0.7;
          } else {
            eType = null;
            diff = 0.1;
          }

          return _WordData(
            text: text,
            difficulty: diff,
            errorType: eType,
            syllables: (m['syllables'] as List?)
                    ?.map((s) => s.toString())
                    .toList() ??
                [],
          );
        }).toList();
        _mascotMsg = 'නියමයි! කියවන්න පටන් ගමු 📖\nකියවන්න බැරි වචනයක් ස්පර්ශ කරන්න.';
      } else {
        _fallbackTokenize();
        _mascotMsg = 'මාර්ගගත නෑ. ඒත් අපි කියවමු! 📖';
      }
    } catch (e) {
      _fallbackTokenize();
      _mascotMsg = 'සේවාව ලැබුණේ නැත. ඒත් අපි කියවමු! 📖';
    }

    setState(() => _loading = false);
  }

  void _fallbackTokenize() {
    _words = _passage
        .replaceAll('\n', ' ')
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .map((w) => _WordData(text: w.trim()))
        .toList();
  }

  Future<void> _onWordTap(int idx) async {
    if (_isPlaying) return; // Don't allow tapping while auto-playing
    
    final w = _words[idx];
    setState(() {
      _helped.add(idx);
      _mascotMsg = 'හොඳයි! "${w.text}" බලමු 🦉';
    });

    await showWordHelpModal(
      context,
      WordInfo(
        word: w.text,
        difficulty: w.difficulty,
        errorType: w.errorType,
        syllables: w.syllables,
      ),
    );

    if (!mounted) return;
    setState(() {
      _mascotMsg = 'ඉතින් ඊළඟ එක කියවමු! 🌟';
    });
  }

  void _slower() {
    setState(() {
      if (_speed > 0.5) _speed -= 0.5;
    });
  }

  void _faster() {
    setState(() {
      if (_speed < 2.0) _speed += 0.5;
    });
  }

  void _stop() {
    setState(() {
      _isPlaying = false;
      _playIndex = -1;
      _mascotMsg = 'ආයෙත් පටන් ගමු! 🔄';
    });
    _audio.stop();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      setState(() {
        _isPlaying = false;
        _mascotMsg = 'නැවැත්තුවා. ⏸️';
      });
      await _audio.stop();
      return;
    }

    setState(() {
      _isPlaying = true;
      if (_playIndex == -1) _playIndex = 0;
      _mascotMsg = 'මා සමඟ අසන්න 🎧';
    });

    while (_isPlaying && _playIndex < _words.length) {
      if (!mounted) return;
      setState(() {});

      await _audio.speak(_words[_playIndex].text);

      int delayMs = (1500 / _speed).round();
      int waited = 0;
      // Wait in small increments so we can break early if paused
      while (waited < delayMs && _isPlaying) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited += 100;
      }

      if (_isPlaying) {
        _playIndex++;
      }
    }

    if (_isPlaying && _playIndex >= _words.length) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _playIndex = -1;
        _mascotMsg = 'නියමයි! දැන් ඔයාට කියවන්න පුළුවන්! 🎉';
      });
      
      // Show celebration dialog when story finishes
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              const Text(
                'නියමයි!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
              const Text(
                'ඔයා කතාව සම්පූර්ණයෙන්ම අහලා ඉවර කළා. දැන් ඔයාට තනියම කියවන්න පුළුවන්!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('හරි', style: TextStyle(fontSize: 20, color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
  }

  Color _wordColor(int idx) {
    if (idx == _playIndex) return Colors.black;
    if (_helped.contains(idx)) return ReadingKidTheme.primary;
    final d = _words[idx].difficulty;
    if (d >= 0.7) return const Color(0xFFC62828);
    if (d >= 0.4) return const Color(0xFFEF6C00);
    return ReadingKidTheme.textMain;
  }

  Color _wordBg(int idx) {
    if (idx == _playIndex) return Colors.yellow.shade300;
    if (_helped.contains(idx)) {
      return ReadingKidTheme.primary.withOpacity(.10);
    }
    final d = _words[idx].difficulty;
    if (d >= 0.7) return const Color(0xFFC62828).withOpacity(.08);
    if (d >= 0.4) return const Color(0xFFEF6C00).withOpacity(.06);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('කතාව කියවමු')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Mascot(
                        message: _mascotMsg,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _DifficultyLegend(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(ReadingKidTheme.radius),
                          border: Border.all(
                            color: ReadingKidTheme.primary.withOpacity(.20),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // Attractive Header Banner
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.lightBlue.shade100, Colors.green.shade100],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Text('🌳', style: TextStyle(fontSize: 36)),
                                    Text('🐦', style: TextStyle(fontSize: 36)),
                                    Text('☁️', style: TextStyle(fontSize: 36)),
                                    Text('🦋', style: TextStyle(fontSize: 36)),
                                    Text('👨‍🌾', style: TextStyle(fontSize: 36)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 6,
                                runSpacing: 10,
                                children: [
                                  for (var i = 0; i < _words.length; i++)
                                    _TappableWord(
                                      text: _words[i].text,
                                      color: _wordColor(i),
                                      bg: _wordBg(i),
                                      helped: _helped.contains(i),
                                      onTap: () => _onWordTap(i),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Playback Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Speed Controls Tab
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.grey.shade300, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.04),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Speed Down
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF6C00).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.remove_rounded, size: 20),
                                  color: const Color(0xFFEF6C00),
                                  onPressed: _speed > 0.5 ? _slower : null,
                                  tooltip: 'වේගය අඩු කරන්න',
                                ),
                              ),
                              
                              const SizedBox(width: 8),
                              // Speed Indicator
                              Text(
                                '${_speed}x', 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  color: ReadingKidTheme.textMain,
                                  fontSize: 14,
                                )
                              ),
                              const SizedBox(width: 8),

                              // Speed Up
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  color: Colors.green.shade600,
                                  onPressed: _speed < 2.0 ? _faster : null,
                                  tooltip: 'වේගය වැඩි කරන්න',
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Play/Stop Controls Tab
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: ReadingKidTheme.primary.withOpacity(0.3), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: ReadingKidTheme.primary.withOpacity(.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Play/Pause
                              InkWell(
                                onTap: _togglePlay,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _isPlaying ? Colors.orange : ReadingKidTheme.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isPlaying ? Colors.orange : ReadingKidTheme.primary).withOpacity(0.4),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  ),
                                  child: Icon(
                                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 8),
                              
                              // Stop
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.stop_rounded, size: 24),
                                  color: _playIndex != -1 ? Colors.red.shade400 : Colors.grey.shade400,
                                  onPressed: _playIndex != -1 ? _stop : null,
                                  tooltip: 'නතර කරන්න',
                                ),
                              ),
                            ],
                          ),
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

class _TappableWord extends StatelessWidget {
  const _TappableWord({
    required this.text,
    required this.color,
    required this.bg,
    required this.helped,
    required this.onTap,
  });
  final String text;
  final Color color;
  final Color bg;
  final bool helped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: helped
              ? Border.all(
                  color: ReadingKidTheme.primary.withOpacity(.45), width: 2)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (helped)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle_rounded,
                    color: ReadingKidTheme.primary, size: 18),
              ),
            Text(
              text,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(.20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Dot(color: ReadingKidTheme.textMain, label: 'පහසු'),
          const SizedBox(width: 16),
          _Dot(color: const Color(0xFFEF6C00), label: 'මධ්\u200dයම'),
          const SizedBox(width: 16),
          _Dot(color: const Color(0xFFC62828), label: 'අමාරු'),
          const SizedBox(width: 16),
          _Dot(
            color: ReadingKidTheme.primary,
            label: 'උදව් කළා',
            icon: Icons.check_circle_rounded,
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.label, this.icon});
  final Color color;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, color: color, size: 14)
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _WordData {
  _WordData({
    required this.text,
    this.difficulty = 0,
    this.errorType,
    this.syllables = const [],
  });
  final String text;
  final double difficulty;
  final String? errorType;
  final List<String> syllables;
}
