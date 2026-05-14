import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:http/http.dart' as http;
import '../services/adaptive_state.dart';
import '../services/avli_service.dart';
import '../models/mbsv.dart';
import '../models/typography_config.dart';

// ── Theme Tokens ────────────────────────────────────────────────────────
class _Tokens {
  static const bg = Color(0xFF0D0E14);
  static const bg2 = Color(0xFF13141D);
  static const bg3 = Color(0xFF1A1C28);
  static const surf = Color(0xFF20233A);
  static const surf2 = Color(0xFF282B42);
  static const bdr = Color(0x0FFFFFFF);
  static const bdr2 = Color(0x1FFFFFFF);
  static const accent = Color(0xFF6366F1);
  static const accentGlow = Color(0x336366F1);
  static const text = Color(0xFFE2E8F0);
  static const textMuted = Color(0xFF94A3B8);
}

// ── UCSC high-confusion letter set (De Silva et al. 2025) ─────────────────
const Set<String> _kUcscConfusionZone = {'ග', 'ල', 'ය', 'ට', 'ක', 'ප', 'ළ', 'ත', 'ද', 'ඒ', 'බ', 'ඵ'};

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
    'word': 'බසය',
    'meaning': '(bus)',
    'segments': [
      {'text': 'බ', 'romanized': 'ba'},
      {'text': 'ස', 'romanized': 'sa'},
      {'text': 'ය', 'romanized': 'ya'},
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
  DateTime? _lastHoverTime;
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

  // ── C4 SinBERT state ───────────────────────────────────────────────────
  static const String _c4Base = 'http://127.0.0.1:8004/api/v1';
  String? _c4WinnerClass;
  Map<String, double> _c4Confidences = {};
  String _c4Classifier = '';
  double _whisperWer = -1.0; // -1 = not yet computed
  int _c4CallCount = 0;

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
          final jsEvent = js.JsObject.fromBrowserObject(event);
          if (jsEvent['results'] == null) return;
          final results = jsEvent['results'];
          final int? length = results['length'] as int?;
          if (length == null || length == 0) return;
          
          final lastResult = results[length - 1];
          if (lastResult == null) return;
          
          final isFinal = lastResult['isFinal'] as bool? ?? false;
          final altCount = lastResult['length'] as int? ?? 1;

          final List<String> transcripts = [];
          for (int a = 0; a < altCount; a++) {
            final t = lastResult[a]['transcript']?.toString().trim() ?? '';
            if (t.isNotEmpty) transcripts.add(t);
          }
          final best = transcripts.isNotEmpty ? transcripts.first : '';

          // --- STRICT SINHALA FILTERING ---
          // Unicode range for Sinhala: \u0D80-\u0DFF
          // We allow spaces as they are common between words
          final sinhalaRegex = RegExp(r'^[\u0D80-\u0DFF\s]+$');
          if (best.isNotEmpty && !sinhalaRegex.hasMatch(best)) {
            _log('⚠️ Ignored non-Sinhala: "$best"', Colors.orange, 'mic');
            if (mounted) {
              setState(() => _micStatus = '⚠️ Sinhala only, please');
            }
            return;
          }
          // --------------------------------

          if (mounted) {
            setState(() {
              _lastHeard = best;
              _micStatus = isFinal ? '✅ Heard: $best' : '🔄 Interim: $best';
            });
          }

          // --- BEHAVIORAL FEATURE: FILLER DETECTION ---
          final sinhalaFillers = ['අ', 'අහ්', 'හ්ම්', 'ම්ම්', 'එතකොට', 'ඔව්...', '...අ'];
          bool isFiller = sinhalaFillers.contains(best);
          if (isFiller) {
            _disfluencyCount++;
            _log('🧠 Hesitation detected (filler): "$best"', Colors.amber, 'mic');
          }
          // --------------------------------------------

          if (isFinal && best.isNotEmpty) {
            final now = DateTime.now();
            _pauseMs = now.difference(speakStart).inMilliseconds;
            
            // Refined hesitation: from hover-start to first speech detection if possible
            // But speakStart is already the time when _startListeningForSegment was called (on hover)
            
            _totalAttempts++;
            final matched = _checkMatch(best, seg['text'], seg['romanized']);
            _handleRecognitionResult(segIndex, best, matched, transcripts);
          }
        } catch (e) {
          _log('⚠️ Result parse error', Colors.orange, 'mic');
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
        final jsEvent = js.JsObject.fromBrowserObject(event);
        final err = jsEvent['error']?.toString() ?? 'unknown';
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
    
    // Check for full word match first
    final String fullWord = _kTasks[_taskIndex]['word'].toString().trim().toLowerCase();
    if (h == fullWord || _jaroWinkler(h, fullWord) > 0.88) return true;

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
    final String fullWord = _kTasks[_taskIndex]['word'].toString().trim().toLowerCase();
    final String h = heard.trim().toLowerCase();
    
    // Determine if they said the whole word
    bool fullWordMatched = (h == fullWord || _jaroWinkler(h, fullWord) > 0.88);

    if (fullWordMatched) {
      _log('🌟 FULL WORD MATCHED: "$heard"', Colors.amber, 'mic');
      // Mark ALL segments for this word as correct
      for (int i = 0; i < _segmentResults.length; i++) {
        if (_segmentResults[i] != true) {
          _recognizedSegments++;
          _segmentResults[i] = true;
        }
      }
      matched = true; 
    }

    final seg = (_kTasks[_taskIndex]['segments'] as List)[segIndex];
    if (matched) {
      if (!fullWordMatched) {
        // Normal segment match
        if (_segmentResults[segIndex] != true) {
          _recognizedSegments++;
          setState(() => _segmentResults[segIndex] = true);
        }
        _log('✅ CORRECT: "$heard" → "${seg['text']}"', Colors.greenAccent, 'mic');
      }
      
      _syllableRate = _recognizedSegments /
          max(1.0, DateTime.now().difference(_taskStartTime!).inSeconds.toDouble());
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
      
      // AUTO-ADVANCE: Move to next task after a short delay
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _segmentResults.every((r) => r == true)) {
          _advanceTask();
        }
      });
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
    final int hesitationMs = _pauseMs > 0 ? _pauseMs : 500;
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

    // ── Step 4: C4 → SinBERT error classification ─────────────────────────
    await _c4Classify(accuracyDelta: accuracyDelta, eventType: eventType);
  }

  // ── Step 4: C4 SinBERT error classification ──────────────────────────────
  Future<void> _c4Classify({
    required double accuracyDelta,
    required String eventType,
  }) async {
    if (!mounted) return;

    final word = _kTasks[_taskIndex]['word'] as String;
    final errorType = _disfluencyCount > 2
        ? 'substitution'
        : _disfluencyCount > 0
            ? 'omission'
            : 'hesitation';
    final contextSentence =
        'Student reading "$word" — ${eventType.toLowerCase()} event, '
        'disfluencies=$_disfluencyCount, accuracy_delta=${accuracyDelta.toStringAsFixed(2)}';

    // Whisper WER proxy — simulated since web demo has no audio stream.
    // In production the audio_base64 field is populated by the Flutter mic capture.
    final simulatedWer =
        (0.12 + _disfluencyCount * 0.09 + (_pauseMs > 2000 ? 0.1 : 0.0))
            .clamp(0.0, 1.0);

    _log(
      '⬆️ C4: error_type=$errorType  context="$word · $eventType"',
      Colors.indigo.shade300,
      'C4',
    );

    try {
      final response = await http.post(
        Uri.parse('$_c4Base/intervention/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'task_id': 'phonological_task_${_taskIndex + 1}',
          'error_type': errorType,
          'context_sentence': contextSentence,
          'syllable': word,
        }),
      );

      if (response.statusCode == 200) {
        final d = jsonDecode(response.body) as Map<String, dynamic>;
        final rawWinner = ((d['error_type'] as String?) ?? 'UNFAMILIAR')
            .toUpperCase()
            .replaceAll(' ', '_');
        final winnerConf = (d['confidence'] as num?)?.toDouble() ?? 0.75;
        final classifier = (d['classifier_model'] as String?) ?? 'rule_based';

        _applyC4Result(rawWinner, winnerConf, classifier, simulatedWer);
        _log(
          '⬇️ C4 $classifier → $rawWinner '
          '(${(winnerConf * 100).toInt()}%)  stage=${d['stage'] ?? '?'}',
          Colors.indigo.shade200,
          'C4',
        );
      } else {
        _log('⚠️ C4 ${response.statusCode} — rule-based fallback', Colors.orange, 'C4');
        _c4FallbackByErrorType(errorType, simulatedWer);
      }
    } catch (_) {
      _log('⚠️ C4 unreachable — simulated classification', Colors.orange, 'C4');
      _c4Simulated(simulatedWer);
    }
  }

  void _applyC4Result(
      String winner, double winnerConf, String classifier, double wer) {
    const all = ['LONG_WORD', 'VOWEL_CONFUSION', 'CONSONANT_CONFUSION', 'UNFAMILIAR'];
    final rem = (1 - winnerConf) / (all.length - 1);
    final confs = {for (final c in all) c: c == winner ? winnerConf : rem};
    if (!mounted) return;
    setState(() {
      _c4WinnerClass = winner;
      _c4Confidences = confs;
      _c4Classifier = classifier;
      _whisperWer = wer;
      _c4CallCount++;
    });
  }

  void _c4FallbackByErrorType(String errorType, double wer) {
    const mapping = {
      'substitution': 'CONSONANT_CONFUSION',
      'omission': 'VOWEL_CONFUSION',
      'hesitation': 'UNFAMILIAR',
    };
    _applyC4Result(mapping[errorType] ?? 'UNFAMILIAR', 0.78, 'rule_based', wer);
  }

  void _c4Simulated(double wer) {
    const classes = ['LONG_WORD', 'VOWEL_CONFUSION', 'CONSONANT_CONFUSION', 'UNFAMILIAR'];
    final winnerIdx = _disfluencyCount > 2 ? 2 : _disfluencyCount > 0 ? 1 : 3;
    _applyC4Result(classes[winnerIdx], 0.72, 'simulated', wer);
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
        return _Tokens.surf; // default dark mode surface
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final task = _kTasks[_taskIndex];
    final segments = task['segments'] as List<Map<String, dynamic>>;
    final allCorrect = _segmentResults.every((r) => r == true);

    return Scaffold(
      backgroundColor: _Tokens.bg,
      body: Stack(
        children: [
          // ── Background Glows ───────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-1.0, -1.0),
                  radius: 1.2,
                  colors: [Color(0x0F6366F1), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(1.0, 1.0),
                  radius: 1.2,
                  colors: [Color(0x0F8B5CF6), Colors.transparent],
                ),
              ),
            ),
          ),

          Row(
            children: [
              // ── Left: Task area ────────────────────────────────────────────
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    _buildHeader(task),
                    LinearProgressIndicator(
                      value: (_taskIndex + 1) / _kTasks.length,
                      backgroundColor: _Tokens.bg2,
                      color: _Tokens.accent,
                      minHeight: 4,
                    ),
                    // Gamification banner
                    if (_gameTrigger)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            const Text('🎮', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'ENGAGEMENT RECOVERY ACTIVE: Difficulty $_gameDifficulty',
                                style: GoogleFonts.dmMono(
                                    fontSize: 11,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: Colors.amber),
                              onPressed: () =>
                                  setState(() => _gameTrigger = false),
                              visualDensity: VisualDensity.compact,
                            ),
                          ]),
                        ),
                      ),
                    Expanded(
                      child: Listener(
                        onPointerDown: (e) =>
                            _recordTouch(e.localPosition, pressure: e.pressure),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 600,
                            constraints: const BoxConstraints(minHeight: 450),
                            decoration: BoxDecoration(
                              color: _taskBgColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: _Tokens.bdr2, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                )
                              ],
                            ),
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Word display with C2 typography applied
                                Transform.translate(
                                  offset: Offset(0, _typo.diacriticOffset),
                                  child: Text(
                                    task['word'],
                                    style: GoogleFonts.notoSansSinhala(
                                      fontSize: _typo.fontSize.clamp(40.0, 80.0),
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _typo.backgroundContrast == 'WCAG_AAA'
                                              ? Colors.indigo.shade900
                                              : _Tokens.text,
                                      letterSpacing: _typo.letterSpacing +
                                          _typo.glyphPadding,
                                      wordSpacing: _typo.wordSpacing,
                                      height: _typo.lineHeight,
                                    ),
                                  ),
                                ),
                                Text(
                                  task['meaning'],
                                  style: GoogleFonts.dmMono(
                                      fontSize: 14, color: _Tokens.textMuted),
                                ),
                                if (_armId >= 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'C2 Arm #$_armId  •  '
                                      '${_typo.fontSize.toStringAsFixed(0)}px  •  '
                                      'ls=${_typo.letterSpacing.toStringAsFixed(1)}  •  '
                                      '${_typo.backgroundContrast}',
                                      style: GoogleFonts.dmMono(
                                          fontSize: 11,
                                          color: _typo.backgroundContrast ==
                                                  'WCAG_AAA'
                                              ? Colors.black54
                                              : _Tokens.textMuted),
                                    ),
                                  ),
                                // UCSC confusion zone badge
                                if (task['word'].toString().split('').any(
                                    (c) => _kUcscConfusionZone.contains(c)))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.purpleAccent
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.purpleAccent
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        '📚 UCSC CONFUSION ZONE · DE SILVA ET AL. (2025)',
                                        style: GoogleFonts.dmMono(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purpleAccent),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                Text(
                                  '✨ Hover over a segment → speak it aloud',
                                  style: GoogleFonts.notoSansSinhala(
                                      fontSize: 14,
                                      color:
                                          _typo.backgroundContrast == 'WCAG_AAA'
                                              ? Colors.black54
                                              : _Tokens.textMuted),
                                ),
                                const SizedBox(height: 28),
                                Wrap(
                                  spacing: 20,
                                  runSpacing: 20,
                                  alignment: WrapAlignment.center,
                                  children: List.generate(
                                      segments.length,
                                      (i) => _buildSegmentTile(i, segments[i])),
                                ),
                                const SizedBox(height: 32),
                                if (_lastHeard.isNotEmpty)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color:
                                          _Tokens.accent.withValues(alpha: 0.1),
                                      border: Border.all(
                                          color: _Tokens.accent
                                              .withValues(alpha: 0.3)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.mic,
                                            size: 18, color: _Tokens.accent),
                                        const SizedBox(width: 10),
                                        Text(
                                          'HEARD: "$_lastHeard"',
                                          style: GoogleFonts.dmMono(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _Tokens.accent),
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
                                    _actionBtn('💡 Hint', Colors.amberAccent,
                                        () {
                                      _hints++;
                                      _log('💡 Hint #$_hints', Colors.amber,
                                          'student');
                                      _pipeline(
                                          accuracyDelta: -0.1,
                                          eventType: 'HINT');
                                    }),
                                    _actionBtn('🔊 Replay', Colors.purpleAccent,
                                        () {
                                      _replays++;
                                      _log(
                                          '🔊 Replay #$_replays',
                                          Colors.purpleAccent.shade100,
                                          'student');
                                      _pipeline(
                                          accuracyDelta: -0.05,
                                          eventType: 'REPLAY');
                                    }),
                                    _actionBtn('❌ Correction', Colors.redAccent,
                                        () {
                                      _corrections++;
                                      _log('❌ Correction #$_corrections',
                                          Colors.redAccent, 'student');
                                      _pipeline(
                                          accuracyDelta: -0.2,
                                          eventType: 'TAP');
                                    }),
                                    if (allCorrect ||
                                        _segmentResults.any((r) => r != null))
                                      _actionBtn(
                                        allCorrect
                                            ? '🎉 Next Task →'
                                            : '⏭ Skip →',
                                        allCorrect
                                            ? Colors.greenAccent
                                            : _Tokens.textMuted,
                                        _advanceTask,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Right: Monitoring panel ────────────────────────────────────
              Container(
                width: 340,
                decoration: BoxDecoration(
                  color: _Tokens.bg2.withValues(alpha: 0.8),
                  border: const Border(left: BorderSide(color: _Tokens.bdr)),
                ),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _pipelineConnection(),
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                // ── C1 MBSV ─────────────────────────────────────────────
                                _panelHeader('📊 C1 — BEHAVIORAL SIGNALS (MBSV)', Colors.blueAccent,
                                    Icons.analytics_outlined),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                  child: _mbsv != null
                                      ? _buildMbsvSection(_mbsv!)
                                      : Center(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 20),
                                            child: Text('Waiting for speech input...',
                                                style: GoogleFonts.dmMono(
                                                    color: _Tokens.textMuted,
                                                    fontSize: 13)),
                                          ),
                                        ),
                                ),

                                // ── C2 AVLI ─────────────────────────────────────────────
                                _panelHeader('🎨 C2 — AVLI Typography',
                                    Colors.purpleAccent, Icons.auto_fix_high_outlined),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                  child: _buildAvliSection(),
                                ),

                                // ── C4 SinBERT ──────────────────────────────────────────
                                _panelHeader('🧠 C4 — SinBERT Classification',
                                    const Color(0xFF818CF8), Icons.psychology_outlined),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                  child: _buildC4Section(),
                                ),

                                // ── Audio recognition ────────────────────────────────────
                                _panelHeader('🎙️ Audio Recognition', Colors.tealAccent,
                                    Icons.mic_external_on_outlined),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                  child: Column(
                                    children: [
                                      _statRow('Mic', _micStatus),
                                      _statRow('Last heard',
                                          _lastHeard.isEmpty ? '—' : '"$_lastHeard"'),
                                      _statRow('Recognized',
                                          '$_recognizedSegments/$_totalAttempts'),
                                      _statRow('Disfluencies', '$_disfluencyCount'),
                                      _statRow('Pause', '${_pauseMs}ms'),
                                      _statRow('Syllable rate',
                                          '${_syllableRate.toStringAsFixed(2)}/s'),
                                      _statRow(
                                        '🎙 Whisper WER',
                                        _whisperWer >= 0
                                            ? _whisperWer.toStringAsFixed(2)
                                            : '—',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Live log ─────────────────────────────────────────────
                        _buildLogHeader(),
                        Expanded(
                          flex: 3, // Increased flex for logs
                          child: _buildLogPanel(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader(Map<String, dynamic> task) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: const BoxDecoration(
          color: _Tokens.surf,
          border: Border(bottom: BorderSide(color: _Tokens.bdr2)),
        ),
        child: Row(children: [
          const Text('🇱🇰', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('සිංහල ශබ්ද කොටස් කර්තව්‍යය',
                        style: GoogleFonts.notoSansSinhala(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _Tokens.text)),
                    const SizedBox(width: 12),
                    _liveBadge(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    'Task ${_taskIndex + 1}/3  •  ${task['word']}  •  '
                    'C1:MBSV + C2:AVLI + C4:SinBERT',
                    style: GoogleFonts.dmMono(
                        fontSize: 11, color: _Tokens.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('SESSION: $_sessionId',
                  style: GoogleFonts.dmMono(fontSize: 10, color: _Tokens.textMuted)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _listeningIndex >= 0
                      ? Colors.red.withValues(alpha: 0.15)
                      : _Tokens.bg3,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _listeningIndex >= 0 ? Colors.redAccent : _Tokens.bdr2,
                      width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_listeningIndex >= 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    Text(_micStatus.toUpperCase(),
                        style: GoogleFonts.dmMono(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold,
                            color: _listeningIndex >= 0 ? Colors.redAccent : _Tokens.text)),
                  ],
                ),
              ),
            ],
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
          style: GoogleFonts.dmMono(fontSize: 9, color: _Tokens.textMuted)),
      Text(
        flags.isEmpty ? 'None' : flags.join(' • '),
        style: GoogleFonts.dmMono(
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
        _chip('Arm #$_armId', Colors.purpleAccent),
        const SizedBox(width: 6),
        _chip(
          'R: ${_lastReward >= 0 ? "+" : ""}${_lastReward.toStringAsFixed(3)}',
          _lastReward >= 0 ? Colors.greenAccent : Colors.redAccent,
        ),
        const SizedBox(width: 6),
        _chip('ΣR: ${_cumulativeReward.toStringAsFixed(2)}',
            Colors.blueGrey),
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
          style: GoogleFonts.dmMono(
              fontSize: 10,
              color: _gameTrigger ? Colors.amber : _Tokens.textMuted),
        ),
      ]),
      const SizedBox(height: 3),
      Text('C2 calls: $_avliCallCount',
          style: GoogleFonts.dmMono(fontSize: 9, color: Colors.white24)),
    ]);
  }

  // ── C4 SinBERT panel ───────────────────────────────────────────────────
  static const _c4ClassLabels = {
    'LONG_WORD':           'Long Word',
    'VOWEL_CONFUSION':     'Vowel Confusion',
    'CONSONANT_CONFUSION': 'Consonant Confusion',
    'UNFAMILIAR':          'Unfamiliar',
  };
  static const _c4ClassColors = {
    'LONG_WORD':           Colors.blue,
    'VOWEL_CONFUSION':     Colors.orange,
    'CONSONANT_CONFUSION': Colors.red,
    'UNFAMILIAR':          Colors.purple,
  };

  Widget _buildC4Section() {
    if (_c4WinnerClass == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('Awaiting first recognition...',
              style: GoogleFonts.dmMono(color: _Tokens.textMuted, fontSize: 11)),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Confidence bars for all 4 classes
      for (final cls in _c4ClassLabels.keys) ...[
        _c4Bar(cls),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 6),
      // Badges row
      Wrap(spacing: 6, runSpacing: 6, children: [
        _c4Badge(
          '🤖 ${_c4Classifier == 'sinbert' ? 'SinBERT' : _c4Classifier}',
          Colors.indigoAccent.withValues(alpha: 0.1),
          Colors.indigoAccent.withValues(alpha: 0.3),
          Colors.indigoAccent.shade100,
        ),
        _c4Badge(
          '🎙 WER: ${_whisperWer >= 0 ? _whisperWer.toStringAsFixed(2) : "—"}',
          Colors.tealAccent.withValues(alpha: 0.1),
          Colors.tealAccent.withValues(alpha: 0.3),
          Colors.tealAccent.shade100,
        ),
      ]),
      const SizedBox(height: 8),
      Text(
        'Perera & Sumanathilaka (2025) · arXiv:2510.04750',
        style: GoogleFonts.dmMono(fontSize: 8, color: Colors.white24),
      ),
    ]);
  }

  Widget _c4Bar(String cls) {
    final conf = _c4Confidences[cls] ?? 0.0;
    final isWinner = cls == _c4WinnerClass;
    final color = _c4ClassColors[cls]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (isWinner)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.auto_awesome, size: 10, color: Colors.amber),
            ),
          Text(
            _c4ClassLabels[cls]!,
            style: GoogleFonts.dmMono(
              fontSize: 10,
              color: isWinner ? Colors.white : _Tokens.textMuted,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ]),
        Text(
          '${(conf * 100).toInt()}%',
          style: GoogleFonts.dmMono(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isWinner ? color : _Tokens.textMuted,
          ),
        ),
      ]),
      const SizedBox(height: 4),
      _premiumProgressBar(conf, color, isWinner, showTicks: true),
    ]);
  }

  Widget _premiumProgressBar(double value, Color color, bool isWinner, {bool showTicks = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              if (showTicks)
                Row(
                  children: List.generate(
                      10,
                      (i) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              height: 2,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          )),
                ),
              // Progress fill
              FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.6), color],
                    ),
                    boxShadow: isWinner
                        ? [
                            BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 1)
                          ]
                        : [],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _c4Badge(String label, Color bg, Color border, Color text) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Text(label,
            style: GoogleFonts.dmMono(fontSize: 8.5, color: text)),
      );

  // ── Segment tile ───────────────────────────────────────────────────────
  Widget _buildSegmentTile(int i, Map<String, dynamic> seg) {
    final state = _segmentResults[i];
    final isListening = _listeningIndex == i;

    final isHighContrast = _typo.backgroundContrast == 'WCAG_AAA';
    final double contrastWeight = isHighContrast ? 1.0 : 0.0;
    
    final Color defaultTextColor = Color.lerp(_Tokens.text, Colors.black87, contrastWeight)!;
    final Color defaultBorderColor = Color.lerp(_Tokens.bdr2, Colors.black26, contrastWeight)!;
    final Color defaultBgColor = Color.lerp(_Tokens.surf2, Colors.black.withValues(alpha: 0.05), contrastWeight)!;

    Color bg, border, textColor;
    List<BoxShadow> shadow = [];
    if (isListening) {
      bg = Colors.redAccent.withValues(alpha: 0.1); 
      border = Colors.redAccent; 
      textColor = isHighContrast ? Colors.red.shade900 : Colors.redAccent.shade100;
      shadow = [
        BoxShadow(
          color: Colors.redAccent.withValues(alpha: 0.4 * _listenPulse.value), 
          blurRadius: 15 + (10 * _listenPulse.value), 
          spreadRadius: 2 + (4 * _listenPulse.value)
        )
      ];
    } else if (state == true) {
      bg = Colors.greenAccent.withValues(alpha: 0.05); 
      border = isHighContrast ? Colors.green.shade700 : Colors.greenAccent.withValues(alpha: 0.5); 
      textColor = isHighContrast ? Colors.green.shade900 : Colors.greenAccent;
      shadow = [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.1), blurRadius: 10)];
    } else if (state == false) {
      bg = Colors.orangeAccent.withValues(alpha: 0.05); 
      border = isHighContrast ? Colors.orange.shade700 : Colors.orangeAccent.withValues(alpha: 0.5); 
      textColor = isHighContrast ? Colors.orange.shade900 : Colors.orangeAccent;
      shadow = [BoxShadow(color: Colors.orangeAccent.withValues(alpha: 0.1), blurRadius: 10)];
    } else {
      bg = defaultBgColor; 
      border = defaultBorderColor; 
      textColor = defaultTextColor;
    }

    return MouseRegion(
      onEnter: (_) {
        final bool wordComplete = _segmentResults.every((r) => r == true);
        if (_listeningIndex < 0 && !wordComplete) {
          _lastHoverTime = DateTime.now();
          _startListeningForSegment(i);
        }
      },
      cursor: SystemMouseCursors.click,
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
            border: Border.all(color: border, width: isListening ? 3 : 1),
            borderRadius: BorderRadius.circular(16),
            boxShadow: shadow,
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
              Text('✨ Hover',
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: Colors.blue.shade400)),
          ]),
        ),
      ),
    );
  }

  // ── Log header with Copy All button ───────────────────────────────────
  Widget _buildLogHeader() {
    return Container(
      width: double.infinity,
      color: Colors.blueGrey.shade800,
      padding: const EdgeInsets.fromLTRB(12, 5, 6, 5),
      child: Row(children: [
        Text('📝 LIVE LOG',
            style: GoogleFonts.dmMono(
                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
        const Spacer(),
        Tooltip(
          message: 'Copy all log entries to clipboard',
          child: InkWell(
            onTap: _copyAllLogs,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Row(children: [
                Icon(Icons.copy_all_rounded, size: 13, color: Colors.white60),
                const SizedBox(width: 4),
                Text('COPY ALL',
                    style: GoogleFonts.dmMono(
                        fontSize: 11, color: Colors.white70)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: 'Clear log',
          child: InkWell(
            onTap: () => setState(() => _logs.clear()),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Icon(Icons.delete_sweep_rounded,
                  size: 13, color: Colors.white38),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Selectable log panel ────────────────────────────────────────────────
  // Each entry is a SelectableText so the user can highlight and Ctrl+C
  // individual lines. The panel background flashes on "Copy all".
  Widget _buildLogPanel() {
    if (_logs.isEmpty) {
      return Container(
        color: const Color(0xFF111320),
        alignment: Alignment.center,
        child: Text('Monitoring active. Waiting for events...',
            style: GoogleFonts.dmMono(fontSize: 13, color: _Tokens.textMuted)),
      );
    }
    return Container(
      color: const Color(0xFF111320),
      child: SelectionArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          itemCount: _logs.length,
          itemBuilder: (_, i) {
            final entry = _logs[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.0),
              child: Text(
                entry['msg'] as String,
                style: GoogleFonts.dmMono(
                  fontSize: 13.5, // Increased from 12.0
                  color: entry['color'] as Color,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _copyAllLogs() {
    if (_logs.isEmpty) return;
    final text = _logs.reversed
        .map((e) => e['msg'] as String)
        .join('\n');
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      _log('📋 Copied ${_logs.length} entries to clipboard', Colors.white54, 'system');
    });
  }

  // ── UI helpers ─────────────────────────────────────────────────────────
  Widget _actionBtn(String label, Color color, VoidCallback onTap) =>
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
            backgroundColor: color.withValues(alpha: 0.08),
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(label.toUpperCase(), 
              style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
      );

  Widget _panelHeader(String title, Color accent, IconData icon) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _Tokens.surf2.withValues(alpha: 0.5),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 10),
            Text(title.toUpperCase(),
                style: GoogleFonts.dmMono(
                    fontSize: 13.5, 
                    fontWeight: FontWeight.bold, 
                    color: _Tokens.text, 
                    letterSpacing: 1.0)),
          ],
        ),
      );

  Widget _chip(String label, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.15), 
            border: Border.all(color: bg.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            style: GoogleFonts.dmMono(
                fontSize: 12, color: bg, fontWeight: FontWeight.bold)),
      );

  Widget _mbsvBar(String label, double value, {bool inverse = false}) {
    final display = inverse ? 1 - value : value;
    final Color c = display < 0.4
        ? Colors.greenAccent
        : display < 0.7 ? Colors.orangeAccent : Colors.redAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: GoogleFonts.dmMono(fontSize: 12.5, color: _Tokens.text, fontWeight: FontWeight.w500)),
          Text(value.toStringAsFixed(2),
              style: GoogleFonts.dmMono(
                  fontSize: 12.5, fontWeight: FontWeight.bold, color: c)),
        ]),
        const SizedBox(height: 4),
        _premiumProgressBar(value, c, display > 0.6, showTicks: true),
      ]),
    );
  }

  Widget _pipelineConnection() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _Tokens.bg2,
          border: const Border(bottom: BorderSide(color: _Tokens.bdr)),
        ),
        child: Row(
          children: [
            _statusDot(true),
            const SizedBox(width: 10),
            Text('PIPELINE: ACTIVE',
                style: GoogleFonts.dmMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent)),
            const Spacer(),
            Text('EST. RTT: 42MS',
                style: GoogleFonts.dmMono(fontSize: 11, color: _Tokens.textMuted)),
          ],
        ),
      );

  Widget _statusDot(bool active) => AnimatedBuilder(
        animation: _listenPulse,
        builder: (context, child) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.greenAccent.withValues(alpha: 0.6 + (0.4 * _listenPulse.value)) : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: active ? [
              BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.4 * _listenPulse.value),
                  blurRadius: 6)
            ] : [],
          ),
        ),
      );

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.dmMono(
                    fontSize: 13, color: _Tokens.textMuted)),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.dmMono(
                      fontSize: 13,
                      color: _Tokens.text,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );

  Widget _liveBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _listenPulse,
              builder: (context, child) => Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: _listenPulse.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.5 * _listenPulse.value),
                        blurRadius: 4)
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'LIVE TELEMETRY',
              style: GoogleFonts.dmMono(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent),
            ),
          ],
        ),
      );
}
