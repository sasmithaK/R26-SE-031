import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();

  String get _baseUrl {
    return ApiConfig.speechBaseUrl;
  }
  
  TtsService._internal();

  Future<void> speak(String text, {String folder = 'general'}) async {
    if (text.isEmpty) return;
    
    try {
      await stop();
      
      final dir = await getTemporaryDirectory();
      // Create a unique, safe filename for this specific text
      final String safeName = base64UrlEncode(utf8.encode(text)).replaceAll('=', '');
      final file = File('${dir.path}/tts_${folder}_$safeName.wav');
      
      // 1. ZERO LATENCY CACHE: Play instantly if we already downloaded it!
      if (await file.exists()) {
        print('TTS: ⚡ Playing INSTANTLY from local cache: ${file.path}');
        await _audioPlayer.play(DeviceFileSource(file.path));
        return;
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
            print('TTS: ✅ Download complete! Size: ${audioRes.bodyBytes.length} bytes. Saving to ${file.path} and playing...');
            // Save to our cache file for future instant playbacks
            await file.writeAsBytes(audioRes.bodyBytes);
            await _audioPlayer.play(DeviceFileSource(file.path));
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
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }
}
