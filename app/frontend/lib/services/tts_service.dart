import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _deviceTts = FlutterTts();
  bool _deviceTtsConfigured = false;

  static const Set<String> _deviceSinhalaSkills = {
    'skill_sinhala_vowels',
    'skill_sinhala_consonants',
    'skill_6', // Textbook reading, currently the seventh curriculum skill.
  };

  String get _baseUrl {
    return ApiConfig.speechBaseUrl;
  }

  TtsService._internal();

  /// These activities use the phone's Sinhala voice so reference audio does
  /// not depend on a live cloud TTS request during the demo.
  Future<bool> speakForSkill(
    String text, {
    required String skillId,
    String folder = 'general',
    bool waitUntilComplete = false,
    double playbackRate = 1.0,
  }) {
    if (_deviceSinhalaSkills.contains(skillId)) {
      return speakOnDevice(
        text,
        waitUntilComplete: waitUntilComplete,
        playbackRate: playbackRate,
      );
    }
    return speak(
      text,
      folder: folder,
      waitUntilComplete: waitUntilComplete,
      playbackRate: playbackRate,
    );
  }

  /// Speak using an installed Sinhala voice on the device. Returns false when
  /// the selected Android TTS engine has no Sinhala locale installed.
  Future<bool> speakOnDevice(
    String text, {
    bool waitUntilComplete = false,
    double playbackRate = 1.0,
  }) async {
    if (text.trim().isEmpty) return false;
    try {
      await stop();
      if (!_deviceTtsConfigured) {
        final dynamic languageResult = await _deviceTts.getLanguages;
        final languages = languageResult is List ? languageResult : const [];
        String? sinhalaLocale;
        for (final language in languages) {
          final locale = language.toString();
          if (locale.toLowerCase().replaceAll('_', '-').startsWith('si')) {
            sinhalaLocale = locale;
            if (locale.toLowerCase().replaceAll('_', '-') == 'si-lk') break;
          }
        }
        if (sinhalaLocale == null) {
          print('Device TTS: no installed Sinhala voice/locale was found.');
          return false;
        }
        final languageSet = await _deviceTts.setLanguage(sinhalaLocale);
        if (languageSet != 1 && languageSet != true) {
          print('Device TTS: Sinhala locale $sinhalaLocale is unavailable.');
          return false;
        }
        await _deviceTts.setVolume(1.0);
        await _deviceTts.setPitch(1.0);
        _deviceTtsConfigured = true;
      }

      await _deviceTts.setSpeechRate(
        (0.42 * playbackRate).clamp(0.25, 0.6).toDouble(),
      );
      await _deviceTts.awaitSpeakCompletion(waitUntilComplete);
      final result = await _deviceTts.speak(text);
      return result == 1 || result == true;
    } catch (e) {
      print('Device Sinhala TTS error: $e');
      return false;
    }
  }

  Future<bool> speak(
    String text, {
    String folder = 'general',
    bool waitUntilComplete = false,
    double playbackRate = 1.0,
  }) async {
    if (text.isEmpty) return false;

    try {
      await stop();

      final dir = await getTemporaryDirectory();
      // Create a unique, safe filename for this specific text
      final String safeName = base64UrlEncode(
        utf8.encode(text),
      ).replaceAll('=', '');
      final file = File('${dir.path}/tts_${folder}_$safeName.wav');

      // 1. ZERO LATENCY CACHE: Play instantly if we already downloaded it!
      if (await file.exists()) {
        print('TTS: ⚡ Playing INSTANTLY from local cache: ${file.path}');
        await _playFile(
          file.path,
          waitUntilComplete: waitUntilComplete,
          playbackRate: playbackRate,
        );
        return true;
      }

      print('TTS: ☁️ Not in cache. Asking Azure for new audio...');
      // 2. Otherwise, fetch from Azure
      final response = await http.post(
        Uri.parse('$_baseUrl/tts/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'folder': folder}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final filePath = data['file_path'];
        if (filePath != null) {
          final audioUrl = '$_baseUrl$filePath';
          print('TTS: 📥 Downloading audio from Azure: $audioUrl');
          // Fix for iOS AVPlayer: Download the audio to a temp file and play locally
          final audioRes = await http.get(Uri.parse(audioUrl));
          if (audioRes.statusCode == 200) {
            print(
              'TTS: ✅ Download complete! Size: ${audioRes.bodyBytes.length} bytes. Saving to ${file.path} and playing...',
            );
            // Save to our cache file for future instant playbacks
            await file.writeAsBytes(audioRes.bodyBytes);
            await _playFile(
              file.path,
              waitUntilComplete: waitUntilComplete,
              playbackRate: playbackRate,
            );
            return true;
          } else {
            print('TTS: ❌ Audio download failed: ${audioRes.statusCode}');
          }
        } else {
          print('TTS: ❌ Azure returned 200 but file_path was null!');
        }
      } else {
        print('TTS: ❌ Generation failed: ${response.body}');
      }
    } catch (e) {
      print('TTS Service Error: $e');
    }
    return false;
  }

  Future<void> _playFile(
    String filePath, {
    required bool waitUntilComplete,
    required double playbackRate,
  }) async {
    final completion = waitUntilComplete
        ? _audioPlayer.onPlayerComplete.first
        : null;
    await _audioPlayer.play(DeviceFileSource(filePath));
    await _audioPlayer.setPlaybackRate(playbackRate.clamp(0.5, 2.0));
    if (completion != null) {
      try {
        await completion.timeout(const Duration(seconds: 30));
      } on TimeoutException {
        // Playback already started successfully. A missing completion callback
        // must not turn that successful delivery into a TTS failure.
        print('TTS: Playback completion event timed out.');
      }
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    if (_deviceTtsConfigured) {
      try {
        await _deviceTts.stop();
      } catch (_) {
        // The native TTS engine may have been disposed by the platform.
      }
    }
  }
}
