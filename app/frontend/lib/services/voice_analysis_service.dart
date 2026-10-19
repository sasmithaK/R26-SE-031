import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class VoiceAnalysisService {
  static final VoiceAnalysisService _instance =
      VoiceAnalysisService._internal();
  factory VoiceAnalysisService() => _instance;
  VoiceAnalysisService._internal();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  String? _currentRecordingPath;
  String? lastError; // Added to expose the last error to the UI

  Future<String> runHardwareDiagnostic() async {
    StringBuffer log = StringBuffer();
    log.writeln('--- Audio Hardware Diagnostic ---');
    try {
      final status = await Permission.microphone.status;
      log.writeln('Microphone Permission Status: $status');

      if (status != PermissionStatus.granted) {
        final newStatus = await Permission.microphone.request();
        log.writeln('Requested Permission. New Status: $newStatus');
      }

      log.writeln('Initializing FlutterSoundRecorder...');
      await _recorder.openRecorder();
      _isRecorderInitialized = true;
      log.writeln('FlutterSoundRecorder initialized successfully.');

      final dir = await getTemporaryDirectory();
      String path = '${dir.path}/diagnostic_test.wav';

      log.writeln(
        'Attempting to start recording at 16000Hz (Codec.pcm16WAV)...',
      );
      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );
      log.writeln('Started successfully!');

      await Future.delayed(const Duration(milliseconds: 500));

      log.writeln('Attempting to stop recording...');
      final savedPath = await _recorder.stopRecorder();
      log.writeln('Stopped successfully! Path: $savedPath');

      if (savedPath != null && File(savedPath).existsSync()) {
        final bytes = await File(savedPath).length();
        log.writeln('File exists. Size: $bytes bytes');
      } else {
        log.writeln('WARNING: File does not exist at path!');
      }
    } catch (e) {
      log.writeln('\nEXCEPTION CAUGHT:');
      log.writeln(e.toString());
    } finally {
      log.writeln('--- End of Diagnostic ---');
    }

    return log.toString();
  }

  static String get _baseUrl {
    return '${ApiConfig.speechBaseUrl}/stt';
  }

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _initRecorder() async {
    if (_isRecorderInitialized) return;

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }

    await _recorder.openRecorder();
    _isRecorderInitialized = true;
  }

  /// Starts recording audio from the device microphone (Raw WAV for acoustic analysis)
  Future<void> startRecording() async {
    lastError = null;
    try {
      await _initRecorder();

      final dir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${dir.path}/reading_sample_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );
      debugPrint(
        'VoiceAnalysisService: Started recording to $_currentRecordingPath',
      );
    } catch (e) {
      lastError = e.toString();
      debugPrint('VoiceAnalysisService Error: Failed to start recording - $e');
    }
  }

  /// Stops recording and returns the raw audio file
  Future<File?> stopRecording() async {
    try {
      if (!_isRecorderInitialized) return null;

      final path = await _recorder.stopRecorder();
      if (path != null) {
        debugPrint(
          'VoiceAnalysisService: Stopped recording. File saved at $path',
        );
        return File(path);
      } else if (_currentRecordingPath != null) {
        return File(_currentRecordingPath!);
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint('VoiceAnalysisService Error: Failed to stop recording - $e');
    }
    return null;
  }

  /// Analyzes the audio for acoustic features (latency, stuttering, jitter)
  Future<Map<String, dynamic>> analyzeAudio(
    File audioFile,
    String expectedText, {
    String? studentId,
    String? sessionId,
    String? eventId,
    String? attemptId,
    String? skillId,
    String? activityId,
    String? itemId,
    String? roundId,
    String? datasetId,
    String? dataOrigin,
    List<String> allowedVariants = const [],
    int expectedSyllables = 0,
    int tStimulus = 0,
    int tRecordStart = 0,
  }) async {
    debugPrint(
      'VoiceAnalysisService: Sending audio to Acoustic API for analysis...',
    );

    try {
      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/analyze-acoustics'),
      );
      request.headers['Authorization'] = 'Bearer $token';

      if (studentId != null) request.fields['student_id'] = studentId;
      if (sessionId != null) request.fields['session_id'] = sessionId;
      if (eventId != null) request.fields['event_id'] = eventId;
      if (attemptId != null) request.fields['attempt_id'] = attemptId;
      if (skillId != null) request.fields['skill_id'] = skillId;
      if (activityId != null) request.fields['activity_id'] = activityId;
      if (itemId != null) request.fields['item_id'] = itemId;
      if (roundId != null) request.fields['round_id'] = roundId;
      request.fields['dataset_id'] = datasetId ?? 'live:$studentId:$sessionId';
      request.fields['data_origin'] = dataOrigin ?? ApiConfig.dataOrigin;
      request.fields['allowed_variants_json'] = jsonEncode(allowedVariants);
      request.fields['expected_text'] = expectedText;
      request.fields['expected_syllables'] = expectedSyllables.toString();
      request.fields['t_stimulus'] = tStimulus.toString();
      request.fields['t_record_start'] = tRecordStart.toString();

      request.files.add(
        await http.MultipartFile.fromPath('file', audioFile.path),
      );

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 180),
      );
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Acoustic results received for ${data['item_id']}');
        return data;
      } else {
        debugPrint('VoiceAnalysisService API Error: ${response.body}');
        final retryable =
            response.statusCode == 502 ||
            response.statusCode == 503 ||
            response.statusCode == 504;
        lastError = retryable
            ? 'Speech analysis is preparing. Please try again shortly.'
            : 'Speech analysis failed (${response.statusCode}).';
        return {
          'transcription': '',
          'word_error_rate': null,
          'Acoustic_Latency_ms': null,
          'measurement_status': retryable
              ? 'service_warming_up'
              : 'request_failed',
          'retryable': retryable,
          'user_message': lastError,
        };
      }
    } on TimeoutException {
      lastError = 'Speech analysis took too long. Please try again.';
      return {
        'transcription': '',
        'word_error_rate': null,
        'Acoustic_Latency_ms': null,
        'measurement_status': 'service_timeout',
        'retryable': true,
        'user_message': lastError,
      };
    } catch (e) {
      lastError = e.toString();
      debugPrint('VoiceAnalysisService Network Error: $e');
      return {
        'transcription': '',
        'word_error_rate': null,
        'Acoustic_Latency_ms': null,
        'measurement_status': 'request_failed',
        'retryable': true,
        'user_message': 'Could not reach speech analysis. Please try again.',
      };
    }
  }
}
