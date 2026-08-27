import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class VoiceAnalysisService {
  static final VoiceAnalysisService _instance = VoiceAnalysisService._internal();
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
      
      log.writeln('Attempting to start recording at 16000Hz (Codec.pcm16WAV)...');
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

    } catch (e, stacktrace) {
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
      _currentRecordingPath = '${dir.path}/reading_sample_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      await _recorder.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );
      print('VoiceAnalysisService: Started recording to $_currentRecordingPath');
    } catch (e) {
      lastError = e.toString();
      print('VoiceAnalysisService Error: Failed to start recording - $e');
    }
  }

  /// Stops recording and returns the raw audio file
  Future<File?> stopRecording() async {
    try {
      if (!_isRecorderInitialized) return null;
      
      final path = await _recorder.stopRecorder();
      if (path != null) {
        print('VoiceAnalysisService: Stopped recording. File saved at $path');
        return File(path);
      } else if (_currentRecordingPath != null) {
        return File(_currentRecordingPath!);
      }
    } catch (e) {
      lastError = e.toString();
      print('VoiceAnalysisService Error: Failed to stop recording - $e');
    }
    return null;
  }

  /// Analyzes the audio for acoustic features (latency, stuttering, jitter)
  Future<Map<String, dynamic>> analyzeAudio(
    File audioFile, 
    String expectedText,
    {
      int expectedSyllables = 0,
      int tStimulus = 0,
      int tRecordStart = 0,
    }
  ) async {
    print('VoiceAnalysisService: Sending audio to Acoustic API for analysis...');
    
    try {
      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/analyze-acoustics'));
      request.headers['Authorization'] = 'Bearer $token';
      
      request.fields['expected_text'] = expectedText;
      request.fields['expected_syllables'] = expectedSyllables.toString();
      request.fields['t_stimulus'] = tStimulus.toString();
      request.fields['t_record_start'] = tRecordStart.toString();
      
      request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Acoustic Results: $data');
        return data;
      } else {
        print('VoiceAnalysisService API Error: ${response.body}');
        return {
          'transcription': '',
          'word_error_rate': 1.0,
          'Acoustic_Latency_ms': 0,
        };
      }
    } catch (e) {
      print('VoiceAnalysisService Network Error: $e');
      return {
        'transcription': '',
        'word_error_rate': 1.0,
        'Acoustic_Latency_ms': 0,
      };
    }
  }
}
