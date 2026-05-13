import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'logger.dart';

Future<void> speakSinhalaLetterOnWeb(String letter) async {
  try {
    final speechSynthesis = web.window.speechSynthesis;

    speechSynthesis.cancel();

    final voicesCount = speechSynthesis.getVoices().length;
    AppLogger.info('Available voices: $voicesCount', tag: 'WebSpeech');

    if (voicesCount == 0) {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final utterance = web.SpeechSynthesisUtterance(letter);
    utterance.lang = 'si-LK';
    utterance.rate = 1.0;
    utterance.pitch = 1.0;
    utterance.volume = 1.0;

    utterance.onstart = ((web.SpeechSynthesisEvent event) {
      AppLogger.info('Speech started', tag: 'WebSpeech');
    }).toJS;

    utterance.onerror = ((web.SpeechSynthesisErrorEvent event) {
      AppLogger.error('Speech error: ${event.error}', tag: 'WebSpeech');
    }).toJS;

    utterance.onend = ((web.SpeechSynthesisEvent event) {
      AppLogger.info('Speech ended', tag: 'WebSpeech');
    }).toJS;

    AppLogger.info('Speaking Sinhala letter: $letter', tag: 'WebSpeech');
    speechSynthesis.speak(utterance);
  } catch (e) {
    AppLogger.error('Web Speech API error', error: e, tag: 'WebSpeech');
  }
}