import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

/// Speech for the reading-helper UI.
///
/// - **Sinhala text** is spoken by the intervention-service backend (gTTS)
///   because Chrome on Windows has no Sinhala voice. The audio is cached
///   as mp3 on the server and replayed instantly afterwards.
/// - **English / non-Sinhala text** (e.g. "Try again!") falls back to the
///   on-device flutter_tts engine.
/// - Adjustable slow / normal rate (rate is sent as an `audioplayers`
///   playback rate for backend audio, and as TTS speech rate for Web TTS).
class ReadingAudioService {
  ReadingAudioService._();
  static final ReadingAudioService instance = ReadingAudioService._();

  /// Where the intervention-service is reachable from the device.
  /// In flutter web on the dev machine this is localhost.
  String backendBase = 'http://127.0.0.1:8000';

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;
  double _rate = 0.45;

  final ValueNotifier<TtsStatus> status =
      ValueNotifier<TtsStatus>(TtsStatus.initial());

  static const _preferred = <String>[
    'si-LK', 'si-IN',
    'en-IN', 'en-US', 'en-GB',
  ];

  Future<void> init() async {
    if (_ready) return;

    _tts.setStartHandler(() {
      status.value = status.value.copyWith(speaking: true, error: null);
    });
    _tts.setCompletionHandler(() {
      status.value = status.value.copyWith(speaking: false);
    });
    _tts.setCancelHandler(() {
      status.value = status.value.copyWith(speaking: false);
    });
    _tts.setErrorHandler((msg) {
      status.value =
          status.value.copyWith(speaking: false, error: msg.toString());
      debugPrint('[tts] error: $msg');
    });

    _player.onPlayerStateChanged.listen((s) {
      if (s == PlayerState.completed || s == PlayerState.stopped) {
        status.value = status.value.copyWith(speaking: false);
      } else if (s == PlayerState.playing) {
        status.value = status.value.copyWith(speaking: true, error: null);
      }
    });

    List<String> available = const [];
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final raw = await _tts.getLanguages;
        if (raw is List) {
          available = raw.map((e) => e.toString()).toList(growable: false);
        }
      } catch (e) {
        debugPrint('[tts] getLanguages failed: $e');
      }
      if (available.isNotEmpty) break;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    debugPrint('[tts] available languages: $available');

    String picked = 'browser default';
    bool sinhala = false;

    if (available.isNotEmpty) {
      for (final code in _preferred) {
        if (available.contains(code)) {
          try {
            await _tts.setLanguage(code);
            picked = code;
            sinhala = code.toLowerCase().startsWith('si');
            break;
          } catch (_) {
            continue;
          }
        }
      }
      if (picked == 'browser default') {
        final fallback = available.firstWhere(
          (l) => l.toLowerCase().startsWith('en'),
          orElse: () => available.first,
        );
        try {
          await _tts.setLanguage(fallback);
          picked = fallback;
        } catch (_) {}
      }
    }

    await _tts.setSpeechRate(_rate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    if (!kIsWeb) {
      try {
        await _tts.awaitSpeakCompletion(true);
      } catch (_) {}
    }

    status.value = TtsStatus(
      ttsLanguage: picked,
      ttsSinhalaSupported: sinhala,
      availableCount: available.length,
      backendOnline: false,
      lastSource: TtsSource.none,
      speaking: false,
      error: null,
    );

    // Optimistic backend health check (non-blocking-ish).
    unawaited(_pingBackend());

    _ready = true;
  }

  Future<void> _pingBackend() async {
    try {
      final r = await http
          .get(Uri.parse('$backendBase/health'))
          .timeout(const Duration(seconds: 2));
      final ok = r.statusCode == 200;
      status.value = status.value.copyWith(backendOnline: ok);
      debugPrint('[tts] backend /health -> ${r.statusCode}');
    } catch (e) {
      status.value = status.value.copyWith(backendOnline: false);
      debugPrint('[tts] backend offline: $e');
    }
  }

  double get rate => _rate;

  Future<void> setRate(double rate) async {
    await init();
    _rate = rate.clamp(0.2, 0.9);
    await _tts.setSpeechRate(_rate);
    try {
      await _player.setPlaybackRate(_rate < 0.35 ? 0.75 : 1.0);
    } catch (_) {}
  }

  /// Speak `text`. Sinhala text is routed to the backend gTTS cache for
  /// accurate pronunciation; everything else uses on-device TTS.
  ///
  /// `kind` lets the backend tune output: `"syllable"` and `"first_sound"`
  /// switch on gTTS slow mode + duplication so a single syllable is loud
  /// enough to hear (otherwise gTTS produces a near-inaudible clip).
  Future<void> speak(String text, {String? kind}) async {
    if (text.trim().isEmpty) return;
    await init();
    final resolvedKind = kind ?? _autoKind(text);
    if (_containsSinhala(text)) {
      final ok = await _speakViaBackend(text, lang: 'si', kind: resolvedKind);
      if (ok) return;
    }
    await _speakViaTts(text);
  }

  /// Treat very short Sinhala fragments as syllables so the backend
  /// applies slow + repeat. Tweakable in one place.
  static String _autoKind(String text) {
    final n = text.trim().length;
    if (_containsSinhala(text) && n <= 4) return 'syllable';
    return 'word';
  }

  Future<bool> _speakViaBackend(String text,
      {required String lang, required String kind}) async {
    try {
      final uri = Uri.parse('$backendBase/api/v1/c4/tts').replace(
        queryParameters: {'text': text, 'lang': lang, 'kind': kind},
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) {
        debugPrint('[tts] backend tts ${r.statusCode}: ${r.body}');
        status.value = status.value.copyWith(backendOnline: false);
        return false;
      }
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final relUrl = body['url'] as String?;
      if (relUrl == null) return false;
      final fullUrl = relUrl.startsWith('http') ? relUrl : '$backendBase$relUrl';
      
      // Ensure any previous audio is completely stopped before playing the next
      await _player.stop();
      await Future.delayed(const Duration(milliseconds: 50));
      
      try {
        await _player.setVolume(1.0);
      } catch (_) {}
      await _player.play(UrlSource(fullUrl));
      status.value = status.value.copyWith(
        backendOnline: true,
        lastSource: TtsSource.backend,
        speaking: true,
        error: null,
      );
      debugPrint('[tts] playing backend mp3: $fullUrl');
      return true;
    } catch (e) {
      debugPrint('[tts] backend speak failed: $e');
      status.value = status.value.copyWith(backendOnline: false);
      return false;
    }
  }

  Future<void> _speakViaTts(String text) async {
    if (kIsWeb && status.value.availableCount == 0) {
      await _refreshVoices();
    }
    try {
      await _tts.stop();
      final result = await _tts.speak(text);
      status.value = status.value.copyWith(lastSource: TtsSource.deviceTts);
      debugPrint('[tts] speak("$text") -> $result '
          '(lang=${status.value.ttsLanguage})');
    } catch (e) {
      debugPrint('[tts] speak failed: $e');
      status.value =
          status.value.copyWith(error: e.toString(), speaking: false);
    }
  }

  Future<void> _refreshVoices() async {
    try {
      final raw = await _tts.getLanguages;
      if (raw is! List) return;
      final available = raw.map((e) => e.toString()).toList(growable: false);
      if (available.isEmpty) return;
      String picked = status.value.ttsLanguage;
      bool sinhala = status.value.ttsSinhalaSupported;
      for (final code in _preferred) {
        if (available.contains(code)) {
          try {
            await _tts.setLanguage(code);
            picked = code;
            sinhala = code.toLowerCase().startsWith('si');
            break;
          } catch (_) {
            continue;
          }
        }
      }
      status.value = status.value.copyWith(
        ttsLanguage: picked,
        ttsSinhalaSupported: sinhala,
        availableCount: available.length,
      );
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    status.value = status.value.copyWith(speaking: false);
  }

  Future<void> refreshBackend() async => _pingBackend();

  void dispose() {
    _player.dispose();
    status.dispose();
  }

  static bool _containsSinhala(String text) {
    for (final r in text.runes) {
      if (r >= 0x0D80 && r <= 0x0DFF) return true;
    }
    return false;
  }
}

enum TtsSource { none, backend, deviceTts }

@immutable
class TtsStatus {
  const TtsStatus({
    required this.ttsLanguage,
    required this.ttsSinhalaSupported,
    required this.availableCount,
    required this.backendOnline,
    required this.lastSource,
    required this.speaking,
    required this.error,
  });

  factory TtsStatus.initial() => const TtsStatus(
        ttsLanguage: '...',
        ttsSinhalaSupported: false,
        availableCount: 0,
        backendOnline: false,
        lastSource: TtsSource.none,
        speaking: false,
        error: null,
      );

  final String ttsLanguage;
  final bool ttsSinhalaSupported;
  final int availableCount;
  final bool backendOnline;
  final TtsSource lastSource;
  final bool speaking;
  final String? error;

  TtsStatus copyWith({
    String? ttsLanguage,
    bool? ttsSinhalaSupported,
    int? availableCount,
    bool? backendOnline,
    TtsSource? lastSource,
    bool? speaking,
    Object? error = _unset,
  }) {
    return TtsStatus(
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      ttsSinhalaSupported: ttsSinhalaSupported ?? this.ttsSinhalaSupported,
      availableCount: availableCount ?? this.availableCount,
      backendOnline: backendOnline ?? this.backendOnline,
      lastSource: lastSource ?? this.lastSource,
      speaking: speaking ?? this.speaking,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

const Object _unset = Object();
