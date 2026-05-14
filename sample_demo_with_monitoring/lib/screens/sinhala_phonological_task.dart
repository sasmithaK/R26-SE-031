import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import '../services/adaptive_state.dart';
import '../services/avli_service.dart';
import '../models/mbsv.dart';
import '../models/typography_config.dart';

// ── Grade-1 Sinhala word definitions ──────────────────────────────────────
const List<Map<String, dynamic>> _kTasks = [
  {
    'word': 'ගස',
    'meaning': '(tree)',
    'segments': [
      {'text': 'ග', 'romanized': 'ga'},
      {'text': 'ස', 'romanized': 'sa'},
    ],
  },
  {
    'word': 'ගෙදර',
    'meaning': '(home)',
    'segments': [
      {'text': 'ගෙ', 'romanized': 'ge'},
      {'text': 'ද', 'romanized': 'da'},
      {'text': 'ර', 'romanized': 'ra'},
    ],
  },
  {
    'word': 'ළදරු',
    'meaning': '(baby)',
    'segments': [
      {'text': 'ළ', 'romanized': 'la'},
      {'text': 'ද', 'romanized': 'da'},
      {'text': 'රු', 'romanized': 'ru'},
    ],
  },
];

bool get _speechSupported =>
    js.context.hasProperty('SpeechRecognition') ||
    js.context.hasProperty('webkitSpeechRecognition');

class SinhalaPhonologicalTask extends StatefulWidget {
  final VoidCallback? onComplete;
  const SinhalaPhonologicalTask({super.key, this.onComplete});

  @override
  State<SinhalaPhonologicalTask> createState() =>
      _SinhalaPhonologicalTaskState();
}

class _SinhalaPhonologicalTaskState extends State<SinhalaPhonologicalTask>
    with TickerProviderStateMixin {
  final String studentId = 'DEMO_STUDENT_001';
  final AVLIService _avli = AVLIService();

  late final String _sessionId;

  // ── Task state ─────────────────────────────────────────────────────────
  int _taskIndex = 0;
  DateTime? _taskStartTime;
  DateTime? _firstTapTime;
  late List<bool?> _segmentResults;
  int _listeningIndex = -1;

  // ── C1 behavioral telemetry (12 features) ─────────────────────────────
  final List<Map<String, dynamic>> _touchEvents = [];
  int _corrections = 0;
  int _hints = 0;
  int _replays = 0;
  final List<double> _tapIntervals = [];
  DateTime? _lastTapTime;
  int _pauseMs = 0;
  double _syllableRate = 0;
  int _disfluencyCount = 0;
  int _recognizedSegments = 0;
  int _totalAttempts = 0;

  // ── C1 MBSV output ─────────────────────────────────────────────────────
  MBSV? _mbsv;
  double _prevVisualStrain = 0.5; // for C2 reward computation

  // ── C2 AVLI state ──────────────────────────────────────────────────────
  TypographyConfig _typo = TypographyConfig.defaultConfig();
  int _armId = -1;         // -1 = not yet selected
  bool _gameTrigger = false;
  int _gameDifficulty = 2;
  double _lastReward = 0.0;
  double _cumulativeReward = 0.0;
  int _avliCallCount = 0;

  // ── Display state ───────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _logs = [];
  String _lastHeard = '';
  String _micStatus = '';

  late AnimationController _listenPulse;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _sessionId = 'SESSION_${DateTime.now().millisecondsSinceEpoch}';
    _micStatus = _speechSupported ? '🎤 Ready' : '🚫 No Speech API';

    _listenPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _resetTask();
    _log('🚀 Session: $_sessionId', Colors.cyan, 'system');
    _log('🎤 ${_speechSupported ? "Speech API available" : "No Speech API — use Chrome"}',
        _speechSupported ? Colors.greenAccent : Colors.orange, 'system');
    _log('👆 Touch a segment → speak it aloud', Colors.white70, 'system');
  }

  @override
  void dispose() {
    _listenPulse.dispose();
    super.dispose();
  }

  void _resetTask() {
    final segs = _kTasks[_taskIndex]['segments'] as List;
    _segmentResults = List.filled(segs.length, null);
    _listeningIndex = -1;
    _taskStartTime = DateTime.now();
    _firstTapTime = null;
  }

  // ── Logging with source tag ─────────────────────────────────────────────
  void _log(String msg, Color color, String src) {
    if (!mounted) return;
    setState(() {
      final now = DateTime.now();
      final ts = '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';
      _logs.insert(0, {'msg': '[$ts][$src] $msg', 'color': color});
      if (_logs.length > 60) _logs.removeLast();
    });
  }

  // ── Touch recording ────────────────────────────────────────────────────
  void _recordTouch(Offset pos, {double pressure = 0.5}) {
    _firstTapTime ??= DateTime.now();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastTapTime != null) {
      _tapIntervals.add((nowMs - _lastTapTime!.millisecondsSinceEpoch).toDouble());
    }
    _lastTapTime = DateTime.now();
    _touchEvents.add({
      'x': pos.dx,
      'y': pos.dy,
      'pressure': pressure,
      'timestamp_ms': nowMs,
    });
  }

  // ── Speech recognition ─────────────────────────────────────────────────
  void _startListeningForSegment(int segIndex) {
    if (!_speechSupported) {
      _log('⚠️ Speech API unavailable — use Chrome', Colors.orange, 'mic');
      return;
    }
    setState(() {
      _listeningIndex = segIndex;
      _micStatus = '🔴 Recording...';
    });

    final seg = (_kTasks[_taskIndex]['segments'] as List)[segIndex];
    _log('🎙️ Listening: "${seg['text']}" (${seg['romanized']})', Colors.yellow, 'mic');

    try {
      final speechClass = js.context.hasProperty('SpeechRecognition')
          ? js.context['SpeechRecognition']
          : js.context['webkitSpeechRecognition'];
      final recognition = js.JsObject(speechClass as js.JsFunction);
      recognition['lang'] = 'si-LK';
      recognition['continuous'] = false;
      recognition['interimResults'] = true;
      recognition['maxAlternatives'] = 5;

      final speakStart = DateTime.now();

      recognition['onstart'] =
          js.allowInterop((_) => _log('🔴 Mic active', Colors.red.shade300, 'mic'));

      recognition['onspeechstart'] = js.allowInterop((_) {
        if (mounted) setState(() => _micStatus = '🔴 Speech detected...');
        _log('🗣️ Speech detected!', Colors.greenAccent, 'mic');
      });

      recognition['onresult'] = js.allowInterop((dynamic event) {
        try {
          final results = event['results'];
          final count = (results['length'] as int?) ?? 0;
          if (count == 0) return;
          final lastResult = results[count - 1];
          final isFinal = lastResult['isFinal'] as bool? ?? false;
          final altCount = lastResult['length'] as int? ?? 1;

          final List<String> transcripts = [];
          for (int a = 0; a < altCount; a++) {
            final t = lastResult[a]['transcript']?.toString().trim() ?? '';
            if (t.isNotEmpty) transcripts.add(t);
          }
          final best = transcripts.isNotEmpty ? transcripts.first : '';

          if (mounted) {
            setState(() {
              _lastHeard = best;
              _micStatus = isFinal ? '✅ Heard: $best' : '🔄 Interim: $best';
            });
          }

          if (isFinal && best.isNotEmpty) {
            _pauseMs = DateTime.now().difference(speakStart).inMilliseconds;
            _totalAttempts++;
            final matched = _checkMatch(best, seg['text'], seg['romanized']);
            _handleRecognitionResult(segIndex, best, matched, transcripts);
          }
        } catch (e) {
          _log('⚠️ Result parse: $e', Colors.orange, 'mic');
        }
      });

      recognition['onnomatch'] = js.allowInterop((_) {
        _log('❓ No match — try again', Colors.orange, 'mic');
        _disfluencyCount++;
        _totalAttempts++;
        if (mounted) setState(() {
          _listeningIndex = -1;
          _micStatus = '🎤 Ready';
        });
        _pipeline(accuracyDelta: -0.1, eventType: 'TAP');
      });

      recognition['onerror'] = js.allowInterop((dynamic event) {
        final err = event['error']?.toString() ?? 'unknown';
        _log('❌ Mic error: $err', Colors.red, 'mic');
        if (mounted) setState(() {
          _listeningIndex = -1;
          _micStatus = err == 'not-allowed' ? '🚫 Mic denied' : '🎤 Ready';
        });
        if (err == 'not-allowed') _showPermissionDialog();
      });

      recognition['onend'] = js.allowInterop((_) {
        if (mounted) setState(() {
          if (_listeningIndex == segIndex) _listeningIndex = -1;
          if (_micStatus.startsWith('🔴')) _micStatus = '🎤 Ready';
        });
      });

      recognition.callMethod('start');
    } catch (e) {
      _log('❌ Recognition start: $e', Colors.red, 'mic');
      if (mounted) setState(() {
        _listeningIndex = -1;
        _micStatus = '🎤 Ready';
      });
    }
  }

  bool _checkMatch(String heard, String expected, String romanized) {
    final h = heard.trim().toLowerCase();
    final e = expected.trim().toLowerCase();
    final r = romanized.trim().toLowerCase();
    return h == e || h.contains(e) || e.contains(h) ||
        h.contains(r) || r.contains(h) ||
        _jaroWinkler(h, e) > 0.85 || _jaroWinkler(h, r) > 0.85;
  }

  double _jaroWinkler(String s, String t) {
    if (s == t) return 1.0;
    if (s.isEmpty || t.isEmpty) return 0.0;
    final matchDist = (max(s.length, t.length) ~/ 2) - 1;
    if (matchDist < 0) return 0.0;
    final sM = List.filled(s.length, false);
    final tM = List.filled(t.length, false);
    int matches = 0, transpositions = 0;
    for (int i = 0; i < s.length; i++) {
      final start = max(0, i - matchDist);
      final end = min(i + matchDist + 1, t.length);
      for (int j = start; j < end; j++) {
        if (tM[j] || s[i] != t[j]) continue;
        sM[i] = tM[j] = true;
        matches++;
        break;
      }
    }
    if (matches == 0) return 0.0;
    int k = 0;
    for (int i = 0; i < s.length; i++) {
      if (!sM[i]) continue;
      while (!tM[k]) k++;
      if (s[i] != t[k]) transpositions++;
      k++;
    }
    final jaro = (matches / s.length + matches / t.length +
            (matches - transpositions / 2) / matches) / 3;
    int prefix = 0;
    for (int i = 0; i < min(min(s.length, t.length), 4); i++) {
      if (s[i] == t[i]) prefix++; else break;
    }
    return jaro + prefix * 0.1 * (1 - jaro);
  }

  void _handleRecognitionResult(
      int segIndex, String heard, bool matched, List<String> alts) {
    final seg = (_kTasks[_taskIndex]['segments'] as List)[segIndex];
    if (matched) {
      _recognizedSegments++;
      _syllableRate = _recognizedSegments /
          max(1.0, DateTime.now().difference(_taskStartTime!).inSeconds.toDouble());
      setState(() => _segmentResults[segIndex] = true);
      _log('✅ CORRECT: "$heard" → "${seg['text']}"', Colors.greenAccent, 'mic');
    } else {
      _disfluencyCount++;
      setState(() => _segmentResults[segIndex] = false);
      _log('❌ Unmatched: "$heard" (alts: ${alts.take(3).join(", ")})',
          Colors.redAccent, 'mic');
    }

    _pipeline(
      accuracyDelta: matched ? 0.5 : -0.2,
      eventType: 'TAP',
    );

    if (_segmentResults.every((r) => r == true)) {
      _log('🎉 Word "${_kTasks[_taskIndex]['word']}" complete!', Colors.amber, 'system');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎤 Microphone Permission Required'),
        content: const Text(
          'Allow microphone access in your browser to use speech recognition.\n\n'
          'Click the 🔒 icon in the address bar → Microphone → Allow',
        ),
        actions: [TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        )],
      ),
    );
  }

  // ── Central pipeline: C1 → C2 (typography) → C2 (reward) ─────────────
  //
  // Step 1  POST /api/v1/telemetry        (C1)  → MBSV (6 dims)
  // Step 2  POST /api/v1/ui/typography    (C2)  → TypographyConfig + ArmId + GameTrigger
  // Step 3  POST /api/v1/ui/reward        (C2)  → LinUCB update with accuracy delta
  Future<void> _pipeline({
    required double accuracyDelta,
    String eventType = 'TAP',
  }) async {
    if (!mounted) return;

    // ── Build C1 telemetry payload ────────────────────────────────────────
    final int hesitationMs = _firstTapTime != null
        ? _firstTapTime!.difference(_taskStartTime!).inMilliseconds.abs().clamp(0, 5000)
        : 500;
    final int sessionLatencyMs =
        DateTime.now().difference(_taskStartTime!).inMilliseconds.clamp(0, 30000);
    final double corrRate =
        _totalAttempts > 0 ? (_corrections / _totalAttempts).clamp(0.0, 1.0) : 0.0;

    final telemetry = {
      'student_id': studentId,
      'session_id': _sessionId,
      'task_id': 'phonological_task_${_taskIndex + 1}',
      'event_type': eventType,
      'hesitation_ms': hesitationMs,
      'correction_rate': corrRate,
      'response_latency': sessionLatencyMs,
      'replay_count': _replays,
      'hint_request_count': _hints,
      'stylus_deviation': 0.0,
      'read_aloud_pause_ms': _pauseMs,
      'syllable_rate': _syllableRate,
      'disfluency_count': _disfluencyCount,
      'touch_events': List<Map<String, dynamic>>.from(_touchEvents),
    };

    // ── Step 1: C1 → MBSV ────────────────────────────────────────────────
    _log('⬆️ C1: sending telemetry (event=$eventType)', Colors.blue.shade300, 'C1');

    final adaptiveState = Provider.of<AdaptiveState>(context, listen: false);
    final mbsv = await adaptiveState.sendTelemetry(telemetry: telemetry);
    if (!mounted) return;

    final visualStrainBefore = _prevVisualStrain;
    _prevVisualStrain = mbsv.visualStrainIndex;

    setState(() => _mbsv = mbsv);
    _log(
      '⬇️ C1 MBSV: CLI=${mbsv.cognitiveLoadIndex.toStringAsFixed(2)} '
      'PSI=${mbsv.phonologicalStrainIndex.toStringAsFixed(2)} '
      'VSI=${mbsv.visualStrainIndex.toStringAsFixed(2)} '
      'ENG=${mbsv.engagementIndex.toStringAsFixed(2)}',
      Colors.lightBlue, 'C1',
    );

    // ── Step 2: C2 → TypographyConfig ─────────────────────────────────────
    _log('⬆️ C2: requesting typography (VSI=${mbsv.visualStrainIndex.toStringAsFixed(2)}, '
        'ENG=${mbsv.engagementIndex.toStringAsFixed(2)})',
        Colors.purple.shade300, 'C2');

    TypographyResponse typoResponse;
    try {
      typoResponse = await _avli.getTypography(
        studentId: studentId,
        mbsv: mbsv,
        context: {
          'session_id': _sessionId,
          'session_number': 1,
          'current_content_text': _kTasks[_taskIndex]['word'],
          'child_age_years': 7,
        },
      );
    } catch (e) {
      _log('⚠️ C2 typography error: $e', Colors.orange, 'C2');
      typoResponse = TypographyResponse(
        studentId: studentId,
        armId: 0,
        config: TypographyConfig.defaultConfig(),
        gameModeTrigger: false,
      );
    }

    if (!mounted) return;
    _avliCallCount++;

    setState(() {
      _typo = typoResponse.config;
      _armId = typoResponse.armId;
      _gameTrigger = typoResponse.gameModeTrigger;
    });

    _log(
      '⬇️ C2 Arm #${typoResponse.armId}: '
      'font=${typoResponse.config.fontSize.toStringAsFixed(0)}px '
      'ls=${typoResponse.config.letterSpacing.toStringAsFixed(1)} '
      'ws=${typoResponse.config.wordSpacing.toStringAsFixed(1)} '
      'diac=${typoResponse.config.diacriticOffset.toStringAsFixed(1)} '
      'glyph=${typoResponse.config.glyphPadding.toStringAsFixed(1)}',
      Colors.purpleAccent, 'C2',
    );
    _log(
      '  contrast=${typoResponse.config.backgroundContrast} '
      'lh=${typoResponse.config.lineHeight.toStringAsFixed(1)}',
      Colors.purple.shade200, 'C2',
    );

    if (typoResponse.gameModeTrigger) {
      _log('🎮 GAMIFICATION TRIGGERED (engagement recovery)',
          Colors.amber, 'C2');
    }

    // ── Step 3: C2 → reward update ────────────────────────────────────────
    final reward = (visualStrainBefore - mbsv.visualStrainIndex) +
        (0.3 * accuracyDelta);
    _lastReward = reward;
    _cumulativeReward += reward;

    _log(
      '⬆️ C2 Reward: ${reward.toStringAsFixed(3)} '
      '(VSI Δ=${(visualStrainBefore - mbsv.visualStrainIndex).toStringAsFixed(3)}, '
      'acc=${accuracyDelta.toStringAsFixed(1)}) '
      '→ cumR=${_cumulativeReward.toStringAsFixed(3)}',
      Colors.teal.shade300, 'C2',
    );

    try {
      await _avli.sendReward(
        studentId: studentId,
        armId: typoResponse.armId,
        reward: accuracyDelta,
        visualStrainBefore: visualStrainBefore,
        visualStrainAfter: mbsv.visualStrainIndex,
      );
      _log('✅ C2 LinUCB updated (arm=${typoResponse.armId})',
          Colors.teal, 'C2');
    } catch (e) {
      _log('⚠️ C2 reward error: $e', Colors.orange, 'C2');
    }
  }

  // ── Advance task ───────────────────────────────────────────────────────
  void _advanceTask() {
    if (_taskIndex < _kTasks.length - 1) {
      setState(() {
        _taskIndex++;
        _touchEvents.clear();
        _tapIntervals.clear();
        _corrections = 0;
        _hints = 0;
        _replays = 0;
        _pauseMs = 0;
        _syllableRate = 0;
        _disfluencyCount = 0;
        _recognizedSegments = 0;
        _totalAttempts = 0;
        _lastHeard = '';
        _gameTrigger = false;
        _resetTask();
      });
      _log('➡️ Task ${_taskIndex + 1}/3: ${_kTasks[_taskIndex]['word']}',
          Colors.cyan, 'system');
    } else {
      _log('🎉 All 3 tasks complete!', Colors.amber, 'system');
      widget.onComplete?.call();
    }
  }

  // ── Background color from C2 contrast setting ─────────────────────────
  Color get _taskBgColor {
    switch (_typo.backgroundContrast) {
      case 'WCAG_AAA':
        return const Color(0xFFFFFDE7); // pale cream — high contrast
      case 'WCAG_AA':
      default:
        return const Color(0xFFF0F4FF); // default light blue
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final task = _kTasks[_taskIndex];
    final segments = task['segments'] as List<Map<String, dynamic>>;
    final allCorrect = _segmentResults.every((r) => r == true);

    return Scaffold(
      backgroundColor: _taskBgColor,
      body: Row(
        children: [
          // ── Left: Task area ────────────────────────────────────────────
          Expanded(
            flex: 7,
            child: Column(
              children: [
                _buildHeader(task),
                LinearProgressIndicator(
                  value: (_taskIndex + 1) / _kTasks.length,
                  backgroundColor: Colors.indigo.shade100,
                  color: Colors.indigo,
                  minHeight: 4,
                ),
                // Gamification banner
                if (_gameTrigger)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    color: Colors.amber.shade100,
                    child: Row(children: [
                      const Text('🎮', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Engagement recovery mode active — '
                          'game difficulty: $_gameDifficulty',
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _gameTrigger = false),
                        child: const Text('Dismiss'),
                      ),
                    ]),
                  ),
                Expanded(
                  child: Listener(
                    onPointerDown: (e) =>
                        _recordTouch(e.localPosition, pressure: e.pressure),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      color: _taskBgColor,
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Word display with C2 typography applied
                          Transform.translate(
                            offset: Offset(0, _typo.diacriticOffset),
                            child: Text(
                              task['word'],
                              style: GoogleFonts.outfit(
                                fontSize: _typo.fontSize.clamp(40.0, 80.0),
                                fontWeight: FontWeight.w900,
                                color: Colors.indigo.shade900,
                                letterSpacing:
                                    _typo.letterSpacing + _typo.glyphPadding,
                                wordSpacing: _typo.wordSpacing,
                                height: _typo.lineHeight,
                              ),
                            ),
                          ),
                          Text(
                            task['meaning'],
                            style: GoogleFonts.outfit(
                                fontSize: 16, color: Colors.grey.shade500),
                          ),
                          if (_armId >= 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'C2 Arm #$_armId  •  '
                                '${_typo.fontSize.toStringAsFixed(0)}px  •  '
                                'ls=${_typo.letterSpacing.toStringAsFixed(1)}  •  '
                                '${_typo.backgroundContrast}',
                                style: GoogleFonts.inconsolata(
                                    fontSize: 10, color: Colors.grey.shade400),
                              ),
                            ),
                          const SizedBox(height: 14),
                          Text(
                            '👆 Touch a segment → speak it aloud',
                            style: GoogleFonts.outfit(
                                fontSize: 14, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 28),
                          Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            alignment: WrapAlignment.center,
                            children: List.generate(segments.length,
                                (i) => _buildSegmentTile(i, segments[i])),
                          ),
                          const SizedBox(height: 32),
                          if (_lastHeard.isNotEmpty)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                border: Border.all(
                                    color: Colors.indigo.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🎤',
                                      style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Heard: "$_lastHeard"',
                                    style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        color: Colors.indigo.shade800),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 28),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              _actionBtn('💡 Hint', Colors.amber.shade600, () {
                                _hints++;
                                _log('💡 Hint #$_hints', Colors.amber, 'student');
                                _pipeline(accuracyDelta: -0.1, eventType: 'HINT');
                              }),
                              _actionBtn('🔊 Replay', Colors.purple.shade600,
                                  () {
                                _replays++;
                                _log('🔊 Replay #$_replays',
                                    Colors.purple.shade200, 'student');
                                _pipeline(accuracyDelta: -0.05, eventType: 'REPLAY');
                              }),
                              _actionBtn('❌ Correction', Colors.red.shade600,
                                  () {
                                _corrections++;
                                _log('❌ Correction #$_corrections',
                                    Colors.redAccent, 'student');
                                _pipeline(accuracyDelta: -0.2, eventType: 'TAP');
                              }),
                              if (allCorrect ||
                                  _segmentResults.any((r) => r != null))
                                _actionBtn(
                                  allCorrect ? '🎉 Next Task →' : '⏭ Skip →',
                                  allCorrect
                                      ? Colors.green.shade600
                                      : Colors.blueGrey,
                                  _advanceTask,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Right: Monitoring panel ────────────────────────────────────
          Container(
            width: 320,
            color: const Color(0xFF1A1D2E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── C1 MBSV ─────────────────────────────────────────────
                _panelHeader('📊 C1 — MBSV Output', Colors.blue.shade800),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _mbsv != null
                      ? _buildMbsvSection(_mbsv!)
                      : Text('Waiting for first recognition...',
                          style: GoogleFonts.outfit(
                              color: Colors.white54, fontSize: 11)),
                ),

                // ── C2 AVLI ─────────────────────────────────────────────
                _panelHeader('🎨 C2 — AVLI Typography', Colors.purple.shade800),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: _buildAvliSection(),
                ),

                // ── Audio recognition ────────────────────────────────────
                _panelHeader('🎙️ Audio Recognition', Colors.teal.shade800),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: Column(
                    children: [
                      _statRow('Mic', _micStatus),
                      _statRow('Last heard',
                          _lastHeard.isEmpty ? '—' : '"$_lastHeard"'),
                      _statRow('Recognized', '$_recognizedSegments/$_totalAttempts'),
                      _statRow('Disfluencies', '$_disfluencyCount'),
                      _statRow('Pause', '${_pauseMs}ms'),
                      _statRow('Syllable rate',
                          '${_syllableRate.toStringAsFixed(2)}/s'),
                    ],
                  ),
                ),

                // ── Live log ─────────────────────────────────────────────
                _panelHeader('📝 Live Log', Colors.blueGrey.shade800),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        _logs[i]['msg'],
                        style: GoogleFonts.inconsolata(
                          fontSize: 9.5,
                          color: _logs[i]['color'] as Color,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader(Map<String, dynamic> task) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.indigo.shade700, Colors.blue.shade500]),
        ),
        child: Row(children: [
          const Text('🇱🇰', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('සිංහල ශබ්ද කොටස් කර්තව්‍යය',
                    style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text(
                    'Task ${_taskIndex + 1}/3  •  ${task['word']}  •  '
                    'C1+C2 active',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _listeningIndex >= 0
                  ? Colors.red.shade600
                  : Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_micStatus,
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white)),
          ),
        ]),
      );

  // ── C1 MBSV section ────────────────────────────────────────────────────
  Widget _buildMbsvSection(MBSV m) {
    final epv = m.errorPatternVector;
    final flags = [
      if (epv.length > 0 && epv[0] > 0) 'Reversal',
      if (epv.length > 1 && epv[1] > 0) 'Omission',
      if (epv.length > 2 && epv[2] > 0) 'Substitution',
      if (epv.length > 3 && epv[3] > 0) 'Hesitation',
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _mbsvBar('🧠 Cognitive Load', m.cognitiveLoadIndex),
      _mbsvBar('🗣️ Phonological Strain', m.phonologicalStrainIndex),
      _mbsvBar('👁️ Visual Strain', m.visualStrainIndex),
      _mbsvBar('😴 Fatigue', m.sessionFatigueIndex),
      _mbsvBar('😊 Engagement', m.engagementIndex, inverse: true),
      _mbsvBar('🛡️ Error Resilience', m.errorResilienceIndex, inverse: true),
      const SizedBox(height: 4),
      Text('Error flags:',
          style: GoogleFonts.inconsolata(fontSize: 9, color: Colors.white38)),
      Text(
        flags.isEmpty ? 'None' : flags.join(' • '),
        style: GoogleFonts.inconsolata(
            fontSize: 9,
            color: flags.isEmpty ? Colors.white24 : Colors.orangeAccent),
      ),
    ]);
  }

  // ── C2 AVLI section ────────────────────────────────────────────────────
  Widget _buildAvliSection() {
    if (_armId < 0) {
      return Text('Waiting for first C1 result...',
          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Arm + reward summary
      Row(children: [
        _chip('Arm #$_armId', Colors.purple.shade700),
        const SizedBox(width: 6),
        _chip(
          'R: ${_lastReward >= 0 ? "+" : ""}${_lastReward.toStringAsFixed(3)}',
          _lastReward >= 0 ? Colors.green.shade800 : Colors.red.shade800,
        ),
        const SizedBox(width: 6),
        _chip('ΣR: ${_cumulativeReward.toStringAsFixed(2)}',
            Colors.blueGrey.shade700),
      ]),
      const SizedBox(height: 8),
      // Typography parameters
      _statRow('Font size', '${_typo.fontSize.toStringAsFixed(0)}px'),
      _statRow('Letter spacing', '${_typo.letterSpacing.toStringAsFixed(1)}px'),
      _statRow('Word spacing', '${_typo.wordSpacing.toStringAsFixed(1)}px'),
      _statRow('Line height', _typo.lineHeight.toStringAsFixed(2)),
      _statRow('Contrast', _typo.backgroundContrast),
      _statRow('Diacritic offset', '${_typo.diacriticOffset.toStringAsFixed(1)}px'),
      _statRow('Glyph padding', '${_typo.glyphPadding.toStringAsFixed(1)}px'),
      const SizedBox(height: 6),
      // Gamification status
      Row(children: [
        Icon(
          _gameTrigger ? Icons.videogame_asset : Icons.videogame_asset_off,
          size: 14,
          color: _gameTrigger ? Colors.amber : Colors.white38,
        ),
        const SizedBox(width: 6),
        Text(
          _gameTrigger
              ? '🎮 Game mode (difficulty: $_gameDifficulty)'
              : 'Game mode: inactive',
          style: GoogleFonts.inconsolata(
              fontSize: 10,
              color: _gameTrigger ? Colors.amber : Colors.white38),
        ),
      ]),
      const SizedBox(height: 3),
      Text('C2 calls: $_avliCallCount',
          style: GoogleFonts.inconsolata(fontSize: 9, color: Colors.white24)),
    ]);
  }

  // ── Segment tile ───────────────────────────────────────────────────────
  Widget _buildSegmentTile(int i, Map<String, dynamic> seg) {
    final state = _segmentResults[i];
    final isListening = _listeningIndex == i;

    Color bg, border, textColor;
    if (isListening) {
      bg = Colors.red.shade50; border = Colors.red.shade400; textColor = Colors.red.shade900;
    } else if (state == true) {
      bg = Colors.green.shade50; border = Colors.green.shade400; textColor = Colors.green.shade900;
    } else if (state == false) {
      bg = Colors.orange.shade50; border = Colors.orange.shade400; textColor = Colors.orange.shade900;
    } else {
      bg = Colors.blue.shade50; border = Colors.blue.shade300; textColor = Colors.blue.shade900;
    }

    return GestureDetector(
      onTapDown: (details) {
        if (_listeningIndex >= 0) return;
        _recordTouch(details.localPosition);
      },
      onTap: () {
        if (_listeningIndex >= 0) return;
        _startListeningForSegment(i);
      },
      child: AnimatedBuilder(
        animation: _listenPulse,
        builder: (_, child) {
          final scale = isListening ? 1.0 + _listenPulse.value * 0.06 : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: isListening ? 3 : 2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isListening
                ? [BoxShadow(color: Colors.red.shade200, blurRadius: 12, spreadRadius: 2)]
                : state == true
                    ? [BoxShadow(color: Colors.green.shade200, blurRadius: 8)]
                    : [],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Transform.translate(
              offset: Offset(0, _typo.diacriticOffset * 0.5),
              child: Text(
                seg['text'],
                style: GoogleFonts.outfit(
                  fontSize: (_typo.fontSize * 1.6).clamp(32.0, 52.0),
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: _typo.glyphPadding * 0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (isListening)
              const Text('🔴', style: TextStyle(fontSize: 14))
            else if (state == true)
              const Text('✅', style: TextStyle(fontSize: 14))
            else if (state == false)
              const Text('🔄 Retry', style: TextStyle(fontSize: 10))
            else
              Text('👆 Tap',
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: Colors.blue.shade400)),
          ]),
        ),
      ),
    );
  }

  // ── UI helpers ─────────────────────────────────────────────────────────
  Widget _actionBtn(String label, Color color, VoidCallback onTap) =>
      ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: GoogleFonts.outfit(fontSize: 13)),
      );

  Widget _panelHeader(String title, Color bg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        color: bg,
        child: Text(title,
            style: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
      );

  Widget _chip(String label, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            style: GoogleFonts.inconsolata(
                fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
      );

  Widget _mbsvBar(String label, double value, {bool inverse = false}) {
    final display = inverse ? 1 - value : value;
    final Color c = display < 0.4
        ? Colors.green
        : display < 0.7 ? Colors.orange : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: GoogleFonts.outfit(fontSize: 9.5, color: Colors.white70)),
          Text(value.toStringAsFixed(2),
              style: GoogleFonts.outfit(
                  fontSize: 9.5, fontWeight: FontWeight.bold, color: c)),
        ]),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(c),
          ),
        ),
      ]),
    );
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.inconsolata(
                    fontSize: 9.5, color: Colors.white54)),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inconsolata(
                      fontSize: 9.5,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}
