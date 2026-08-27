import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import '../config/api_config.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();

  String get _baseUrl {
    return ApiConfig.speechBaseUrl;
  }
  
  TtsService._internal();

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    
    try {
      await stop();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/tts/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final filePath = data['file_path'];
        if (filePath != null) {
          final audioUrl = '$_baseUrl$filePath';
          await _audioPlayer.play(UrlSource(audioUrl));
        }
      } else {
        print('TTS Generation failed: ${response.body}');
      }
    } catch (e) {
      print('TTS Service Error: $e');
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }
}
