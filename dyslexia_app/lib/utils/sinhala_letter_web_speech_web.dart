import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> speakSinhalaLetterOnWeb(String letter) async {
  try {
    final speechSynthesis = web.window.speechSynthesis;

    speechSynthesis.cancel();

    final voicesCount = speechSynthesis.getVoices().length;
    print('Available voices: $voicesCount');

    if (voicesCount == 0) {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final utterance = web.SpeechSynthesisUtterance(letter);
    utterance.lang = 'si-LK';
    utterance.rate = 1.0;
    utterance.pitch = 1.0;
    utterance.volume = 1.0;

    utterance.onstart = ((web.SpeechSynthesisEvent event) {
      print('Speech started');
    }).toJS;

    utterance.onerror = ((web.SpeechSynthesisErrorEvent event) {
      print('Speech error: ${event.error}');
    }).toJS;

    utterance.onend = ((web.SpeechSynthesisEvent event) {
      print('Speech ended');
    }).toJS;

    print('Speaking Sinhala letter: $letter');
    speechSynthesis.speak(utterance);
  } catch (e) {
    print('Web Speech API error: $e');
  }
}