import 'dart:html' as html;
import 'logger.dart';


String _buildTtsUrl(String letter) {
  final query = Uri.encodeComponent(letter);
  return 'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=si&q=$query';
}

Future<bool> playSinhalaLetterAudio(String letter) async {
  try {
    final audio = html.AudioElement(_buildTtsUrl(letter));
    audio.preload = 'auto';
    audio.autoplay = true;
    await audio.play();
    return true;
  } catch (e) {
    AppLogger.error('Web audio playback failed', error: e, tag: 'SinhalaAudioWeb');
    return false;
  }
}