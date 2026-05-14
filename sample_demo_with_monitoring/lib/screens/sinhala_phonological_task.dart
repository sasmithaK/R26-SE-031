import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import '../services/adaptive_state.dart';
import '../models/mbsv.dart';

// ── Grade-1 Sinhala word definitions ──────────────────────────────────────
// Each word split into syllable segments the student reads aloud one by one.
// 'romanized' provides phonetic fallback for Chrome's speech engine (may return
// romanized output when si-LK support is partial).
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

  // Unique session identifier — correlates all telemetry events in C1's Welford baseline
  late final String _sessionId;

  // ── Task state ─────────────────────────────────────────────────────────
  int _taskIndex = 0;
  DateTime? _taskStartTime;
  DateTime? _firstTapTime;

  // Per-segment: null = untouched, true = correct, false = wrong
  late List<bool?> _segmentResults;
  int _listeningIndex = -1;

  // ── Behavioral telemetry (12 C1 features) ─────────────────────────────
  // Touch stream — each element matches TelemetryPayload.TouchEvent schema:
  // {x: float, y: float, pressure: float, timestamp_ms: int}
  final List<Map<String, dynamic>> _touchEvents = [];
  int _corrections = 0;
  int _hints = 0;
  int _replays = 0;
  final List<double> _tapIntervals = [];
  DateTime? _lastTapTime;

  // Acoustic proxies (updated from Web Speech API timing)
  int _pauseMs = 0;        // read_aloud_pause_ms  (int per schema)
  double _syllableRate = 0; // syllable_rate
  int _disfluencyCount = 0; // disfluency_count    (int per schema)
  int _recognizedSegments = 0;
  int _totalAttempts = 0;

  // ── Monitoring display ─────────────────────────────────────────────────
  MBSV? _mbsv;
  final List<Map<String, dynamic>> _logs = []; // {msg: String, color: Color}
  String _lastHeard = '';
  String _micStatus = '';

  late AnimationController _listenPulse;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Session ID: unique per screen open, used by C1 Welford baseline
    _sessionId = 'SESSION_${DateTime.now().millisecondsSinceEpoch}';

    _micStatus = _speechSupported ? '🎤 Ready' : '🚫 No Speech API';

    _listenPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _resetTask();
    _log('🚀 Session started: $_sessionId', Colors.cyan);
    _log('👆 Touch a segment to record your voice', Colors.white70);
    if (!_speechSupported) {
      _log('⚠️ Chrome recommended for Speech API support', Colors.orange);
    }
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

  // ── Logging ────────────────────────────────────────────────────────────
  void _log(String msg, Color color) {
    if (!mounted) return;
    setState(() {
      final now = DateTime.now();
      final ts = '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';
      _logs.insert(0, {'msg': '[$ts] $msg', 'color': color});
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  // ── Touch recording — matches TouchEvent schema exactly ────────────────
  void _recordTouch(Offset pos, {double pressure = 0.5}) {
    _firstTapTime ??= DateTime.now();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (_lastTapTime != null) {
      _tapIntervals.add(
          (nowMs - _lastTapTime!.millisecondsSinceEpoch).toDouble());
    }
    _lastTapTime = DateTime.now();

    _touchEvents.add({
      'x': pos.dx,            // float ✓
      'y': pos.dy,            // float ✓
      'pressure': pressure,   // float [0–1] ✓
      'timestamp_ms': nowMs,  // int ✓
    });
  }

  // ── Speech recognition via Web Speech API ─────────────────────────────
  void _startListeningForSegment(int segIndex) {
    if (!_speechSupported) {
      _log('⚠️ Speech API unavailable — use Chrome', Colors.orange);
      return;
    }

    setState(() {
      _listeningIndex = segIndex;
      _micStatus = '🔴 Recording...';
    });

    final seg = (_kTasks[_taskIndex]['segments'] as List)[segIndex];
    _log('🎙️ Listening for "${seg['text']}" (${seg['romanized']})', Colors.yellow);

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

      recognition['onstart'] = js.allowInterop((_) {
        _log('🔴 Mic active — say: "${seg['text']}"', Colors.red.shade300);
      });

      recognition['onspeechstart'] = js.allowInterop((_) {
        if (mounted) setState(() => _micStatus = '🔴 Speech detected...');
        _log('🗣️ Speech detected!', Colors.greenAccent);
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
            // Pause duration = time from recognition start to final result
            _pauseMs = DateTime.now().difference(speakStart).inMilliseconds;
            _totalAttempts++;

            final matched = _checkMatch(best, seg['text'], seg['romanized']);
            _handleRecognitionResult(segIndex, best, matched, transcripts);
          }
        } catch (e) {
          _log('⚠️ Result parse error: $e', Colors.orange);
        }
      });

      recognition['onnomatch'] = js.allowInterop((_) {
        _log('❓ No match — try again', Colors.orange);
        _disfluencyCount++;
        _totalAttempts++;
        if (mounted) {
          setState(() {
            _listeningIndex = -1;
            _micStatus = '🎤 Ready';
          });
        }
        _sendTelemetry(eventType: 'TAP');
      });

      recognition['onerror'] = js.allowInterop((dynamic event) {
        final err = event['error']?.toString() ?? 'unknown';
        _log('❌ Mic error: $err', Colors.red);
        if (mounted) {
          setState(() {
            _listeningIndex = -1;
            _micStatus = err == 'not-allowed' ? '🚫 Mic denied' : '🎤 Ready';
          });
        }
        if (err == 'not-allowed') _showPermissionDialog();
      });

      recognition['onend'] = js.allowInterop((_) {
        if (mounted) {
          setState(() {
            if (_listeningIndex == segIndex) _listeningIndex = -1;
            if (_micStatus.startsWith('🔴')) _micStatus = '🎤 Ready';
          });
        }
      });

      recognition.callMethod('start');
    } catch (e) {
      _log('❌ Recognition start failed: $e', Colors.red);
      if (mounted) setState(() {
        _listeningIndex = -1;
        _micStatus = '🎤 Ready';
      });
    }
  }

  // ── Fuzzy match: Sinhala text + romanized fallback ─────────────────────
  bool _checkMatch(String heard, String expected, String romanized) {
    final h = heard.trim().toLowerCase();
    final e = expected.trim().toLowerCase();
    final r = romanized.trim().toLowerCase();
    return h == e ||
        h.contains(e) ||
        e.contains(h) ||
        h.contains(r) ||
        r.contains(h) ||
        _jaroWinkler(h, e) > 0.85 ||
        _jaroWinkler(h, r) > 0.85;
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
    final jaro = (matches / s.length +
            matches / t.length +
            (matches - transpositions / 2) / matches) /
        3;
    int prefix = 0;
    for (int i = 0; i < min(min(s.length, t.length), 4); i++) {
      if (s[i] == t[i])
        prefix++;
      else
        break;
    }
    return jaro + prefix * 0.1 * (1 - jaro);
  }

  void _handleRecognitionResult(
      int segIndex, String heard, bool matched, List<String> alternatives) {
    final seg = (_kTasks[_taskIndex]['segments'] as List)[segIndex];

    if (matched) {
      _recognizedSegments++;
      _syllableRate = _recognizedSegments /
          max(1.0, DateTime.now().difference(_taskStartTime!).inSeconds.toDouble());
      setState(() => _segmentResults[segIndex] = true);
      _log('✅ CORRECT! Heard "$heard" → "${seg['text']}"', Colors.greenAccent);
    } else {
      _disfluencyCount++;
      setState(() => _segmentResults[segIndex] = false);
      _log(
        '❌ "${seg['text']}" unmatched. Heard: "$heard"  '
        '(alts: ${alternatives.take(3).join(", ")})',
        Colors.redAccent,
      );
    }

    _sendTelemetry(eventType: 'TAP');

    if (_segmentResults.every((r) => r == true)) {
      _log('🎉 Word "${_kTasks[_taskIndex]['word']}" complete!', Colors.amber);
    }
  }

  // ── Permission dialog ──────────────────────────────────────────────────
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎤 Microphone Permission Required'),
        content: const Text(
          'Allow microphone access in your browser to use speech recognition.\n\n'
          'Click the 🔒 icon in the address bar → Microphone → Allow',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── C1 telemetry — maps all 12 behavioral features to TelemetryPayload ─
  //
  // TelemetryPayload (shared/schemas.py):
  //   student_id, task_id, session_id, timestamp_ms
  //   touch_events: [{x, y, pressure, timestamp_ms}]   ← used by C1 to compute
  //       swipe_velocity, inter_tap_interval, touch_pressure, kalman_innovation
  //   event_type: "TAP"|"SWIPE"|"DRAG"|"HESITATION"|"REPLAY"|"HINT"
  //   session_latency_ms: int   ← total elapsed since task shown
  //   hesitation_ms: int        ← delay before first tap
  //   correction_rate: float    ← corrections / total attempts
  //   replay_count: int
  //   hint_request_count: int
  //   read_aloud_pause_ms: int  ← inter-word silence from speech timing
  //   syllable_rate: float      ← recognized segments / elapsed seconds
  //   disfluency_count: int     ← failed recognitions + onnomatch events
  //   stylus_deviation: float   ← 0.0 (no tracing in this task)
  Future<void> _sendTelemetry({String eventType = 'TAP'}) async {
    if (!mounted) return;

    // hesitation_ms: ms from task shown → first tap (int)
    final int hesitationMs = _firstTapTime != null
        ? (_firstTapTime!.difference(_taskStartTime!).inMilliseconds.abs())
            .clamp(0, 5000)
        : 500;

    // session_latency_ms: total elapsed ms since task shown (int)
    final int sessionLatencyMs = DateTime.now()
        .difference(_taskStartTime!)
        .inMilliseconds
        .clamp(0, 30000);

    final double corrRate = _totalAttempts > 0
        ? (_corrections / _totalAttempts).clamp(0.0, 1.0)
        : 0.0;

    final telemetry = {
      'student_id': studentId,
      'session_id': _sessionId,
      'task_id': 'phonological_task_${_taskIndex + 1}',
      'event_type': eventType,
      // Directly sent scalar fields (matched to TelemetryPayload field names
      // via MonitoringService which maps 'response_latency' → session_latency_ms)
      'hesitation_ms': hesitationMs,           // int ✓
      'correction_rate': corrRate,              // float [0–1] ✓
      'response_latency': sessionLatencyMs,     // int → maps to session_latency_ms ✓
      'replay_count': _replays,                 // int ✓
      'hint_request_count': _hints,             // int ✓
      'stylus_deviation': 0.0,                  // float (no tracing) ✓
      'read_aloud_pause_ms': _pauseMs,          // int ✓
      'syllable_rate': _syllableRate,           // float ✓
      'disfluency_count': _disfluencyCount,     // int ✓
      // Touch stream — C1 computes swipe_velocity, inter_tap_interval,
      // touch_pressure, kalman_innovation from this list
      'touch_events': List<Map<String, dynamic>>.from(_touchEvents),
    };

    final adaptiveState = Provider.of<AdaptiveState>(context, listen: false);
    final mbsv = await adaptiveState.sendTelemetry(telemetry: telemetry);
    if (mounted) setState(() => _mbsv = mbsv);
  }

  // ── Advance to next task ───────────────────────────────────────────────
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
        _resetTask();
      });
      _log('➡️ Task ${_taskIndex + 1}/3: ${_kTasks[_taskIndex]['word']}',
          Colors.cyan);
    } else {
      _log('🎉 All 3 tasks complete!', Colors.amber);
      widget.onComplete?.call();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final task = _kTasks[_taskIndex];
    final segments = task['segments'] as List<Map<String, dynamic>>;
    final allCorrect = _segmentResults.every((r) => r == true);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
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
                Expanded(
                  child: Listener(
                    onPointerDown: (e) =>
                        _recordTouch(e.localPosition, pressure: e.pressure),
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            task['word'],
                            style: GoogleFonts.outfit(
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              color: Colors.indigo.shade900,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            task['meaning'],
                            style: GoogleFonts.outfit(
                                fontSize: 16, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '👆 Touch a segment → speak it aloud',
                            style: GoogleFonts.outfit(
                                fontSize: 14, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 32),
                          Wrap(
                            spacing: 20,
                            runSpacing: 20,
                            alignment: WrapAlignment.center,
                            children: List.generate(segments.length, (i) =>
                                _buildSegmentTile(i, segments[i])),
                          ),
                          const SizedBox(height: 36),
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
                          const SizedBox(height: 32),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              _actionBtn('💡 Hint', Colors.amber.shade600, () {
                                _hints++;
                                _log('💡 Hint #$_hints', Colors.amber);
                                _sendTelemetry(eventType: 'HINT');
                              }),
                              _actionBtn('🔊 Replay', Colors.purple.shade600,
                                  () {
                                _replays++;
                                _log('🔊 Replay #$_replays',
                                    Colors.purple.shade200);
                                _sendTelemetry(eventType: 'REPLAY');
                              }),
                              _actionBtn('❌ Correction', Colors.red.shade600,
                                  () {
                                _corrections++;
                                _log('❌ Correction #$_corrections',
                                    Colors.redAccent);
                                _sendTelemetry(eventType: 'TAP');
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
            width: 310,
            color: const Color(0xFF1A1D2E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelHeader('📊 MBSV — C1 Output', Colors.blue.shade800),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: _mbsv != null
                      ? _buildMbsvSection(_mbsv!)
                      : Text('Waiting for first recognition...',
                          style: GoogleFonts.outfit(
                              color: Colors.white54, fontSize: 12)),
                ),
                _panelHeader('🎙️ Audio Recognition', Colors.purple.shade800),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statRow('Mic', _micStatus),
                      _statRow('Last heard',
                          _lastHeard.isEmpty ? '—' : '"$_lastHeard"'),
                      _statRow('Recognized',
                          '$_recognizedSegments / $_totalAttempts attempts'),
                      _statRow('Disfluencies', '$_disfluencyCount'),
                      _statRow('Pause', '${_pauseMs}ms'),
                      _statRow('Syllable rate',
                          '${_syllableRate.toStringAsFixed(2)}/s'),
                    ],
                  ),
                ),
                _panelHeader('📝 Live Log', Colors.teal.shade800),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Text(
                        _logs[i]['msg'],
                        style: GoogleFonts.inconsolata(
                          fontSize: 10,
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

  // ── Header bar ─────────────────────────────────────────────────────────
  Widget _buildHeader(Map<String, dynamic> task) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.blue.shade500],
        ),
      ),
      child: Row(
        children: [
          const Text('🇱🇰', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'සිංහල ශබ්ද කොටස් කර්තව්‍යය',
                  style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                Text(
                  'Task ${_taskIndex + 1}/3  •  ${task['word']}  •  Touch segment → speak',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _listeningIndex >= 0
                  ? Colors.red.shade600
                  : Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _micStatus,
              style:
                  GoogleFonts.outfit(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── MBSV display section ───────────────────────────────────────────────
  Widget _buildMbsvSection(MBSV m) {
    final epv = m.errorPatternVector;
    final flags = [
      if (epv.length > 0 && epv[0] > 0) 'Reversal',
      if (epv.length > 1 && epv[1] > 0) 'Omission',
      if (epv.length > 2 && epv[2] > 0) 'Substitution',
      if (epv.length > 3 && epv[3] > 0) 'Hesitation',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mbsvBar('🧠 Cognitive Load', m.cognitiveLoadIndex),
        _mbsvBar('🗣️ Phonological Strain', m.phonologicalStrainIndex),
        _mbsvBar('👁️ Visual Strain', m.visualStrainIndex),
        _mbsvBar('😴 Fatigue', m.sessionFatigueIndex),
        _mbsvBar('😊 Engagement', m.engagementIndex, inverse: true),
        _mbsvBar('🛡️ Error Resilience', m.errorResilienceIndex, inverse: true),
        const SizedBox(height: 6),
        Text(
          'Error Patterns:',
          style: GoogleFonts.inconsolata(fontSize: 10, color: Colors.white54),
        ),
        const SizedBox(height: 3),
        Text(
          flags.isEmpty ? 'None detected' : flags.join(' • '),
          style: GoogleFonts.inconsolata(
              fontSize: 10,
              color: flags.isEmpty ? Colors.white38 : Colors.orangeAccent),
        ),
      ],
    );
  }

  // ── Segment tile ───────────────────────────────────────────────────────
  Widget _buildSegmentTile(int i, Map<String, dynamic> seg) {
    final state = _segmentResults[i];
    final isListening = _listeningIndex == i;

    Color bg, border, textColor;
    if (isListening) {
      bg = Colors.red.shade50;
      border = Colors.red.shade400;
      textColor = Colors.red.shade900;
    } else if (state == true) {
      bg = Colors.green.shade50;
      border = Colors.green.shade400;
      textColor = Colors.green.shade900;
    } else if (state == false) {
      bg = Colors.orange.shade50;
      border = Colors.orange.shade400;
      textColor = Colors.orange.shade900;
    } else {
      bg = Colors.blue.shade50;
      border = Colors.blue.shade300;
      textColor = Colors.blue.shade900;
    }

    return GestureDetector(
      // onTapDown fires first — record actual touch coordinates for C1
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
                ? [
                    BoxShadow(
                        color: Colors.red.shade200,
                        blurRadius: 12,
                        spreadRadius: 2)
                  ]
                : state == true
                    ? [BoxShadow(color: Colors.green.shade200, blurRadius: 8)]
                    : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                seg['text'],
                style: GoogleFonts.outfit(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: textColor),
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
            ],
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: GoogleFonts.outfit(fontSize: 14)),
      );

  Widget _panelHeader(String title, Color bg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: bg,
        child: Text(title,
            style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      );

  Widget _mbsvBar(String label, double value, {bool inverse = false}) {
    final display = inverse ? 1 - value : value;
    final Color c = display < 0.4
        ? Colors.green
        : display < 0.7
            ? Colors.orange
            : Colors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style: GoogleFonts.outfit(fontSize: 10, color: Colors.white70)),
            Text(value.toStringAsFixed(2),
                style: GoogleFonts.outfit(
                    fontSize: 10, fontWeight: FontWeight.bold, color: c)),
          ]),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.inconsolata(
                    fontSize: 10, color: Colors.white54)),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inconsolata(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}
