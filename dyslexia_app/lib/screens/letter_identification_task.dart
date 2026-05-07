import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../utils/sinhala_letter_audio.dart'
  if (dart.library.html) '../utils/sinhala_letter_audio_web.dart';

class LetterTask {
  final String targetLetter;
  final List<String> options;
  final String imagePath;
  final Color bgColor;
  final Color primaryColor;
  final IconData defaultIcon;
  final String exampleWord;
  final String exampleWordImage;

  LetterTask({
    required this.targetLetter,
    required this.options,
    required this.imagePath,
    required this.bgColor,
    required this.primaryColor,
    required this.defaultIcon,
    required this.exampleWord,
    required this.exampleWordImage,
  });
}

class LetterIdentificationTask extends StatefulWidget {
  const LetterIdentificationTask({super.key});

  @override
  State<LetterIdentificationTask> createState() => _LetterIdentificationTaskState();
}

class _LetterIdentificationTaskState extends State<LetterIdentificationTask> with SingleTickerProviderStateMixin {
  final FlutterTts flutterTts = FlutterTts();

  final List<LetterTask> tasks = [
    LetterTask(
      targetLetter: 'අ',
      options: ['ආ', 'ඇ', 'අ', 'ඈ'],
      imagePath: 'assets/images/elephant.png',
      bgColor: const Color(0xFFE1F5FE), // Light blue
      primaryColor: Colors.blueAccent,
      defaultIcon: Icons.pets,
      exampleWord: 'අලියා', // aliya (elephant)
      exampleWordImage: 'assets/images/elephant.png',
    ),
    LetterTask(
      targetLetter: 'ඉ',
      options: ['ඊ', 'උ', 'ඉ', 'ඌ'],
      imagePath: 'assets/images/welcome_owl.png',
      bgColor: const Color(0xFFF3E5F5), // Light purple
      primaryColor: Colors.purpleAccent,
      defaultIcon: Icons.flutter_dash,
      exampleWord: 'ඉර', // ira (sun)
      exampleWordImage: 'assets/images/HappySunshineClipart.jpg', // replace with a sun image in assets
    ),
    LetterTask(
      targetLetter: 'ක',
      options: ['ග', 'ක', 'ත', 'ද'],
      imagePath: 'assets/images/apple_character.png',
      bgColor: const Color(0xFFFFF3E0), // Light orange
      primaryColor: Colors.orangeAccent,
      defaultIcon: Icons.cruelty_free,
      exampleWord: 'කපුටා', // kaputa (crow)
      exampleWordImage: 'assets/images/gole.jpg', // replace with a crow image in assets
    ),
    LetterTask(
      targetLetter: 'ම',
      options: ['ය', 'ම', 'ර', 'ල'],
      imagePath: 'assets/images/tree_character.png',
      bgColor: const Color(0xFFE8F5E9), // Light green
      primaryColor: Colors.green,
      defaultIcon: Icons.eco,
      exampleWord: 'මල', // mala (flower)
      exampleWordImage: 'assets/images/download.jpg', // consider replacing with a flower image
    ),
  ];

  int currentTaskIndex = 0;
  bool? isCorrect;
  bool showNextLevel = false;

  void checkAnswer(String selectedLetter) {
    setState(() {
      isCorrect = selectedLetter == tasks[currentTaskIndex].targetLetter;
      if (isCorrect == true) {
        showNextLevel = true;
      } else {
        showNextLevel = false;
      }
    });
  }

  void nextTask() {
    setState(() {
      if (currentTaskIndex < tasks.length - 1) {
        currentTaskIndex++;
      } else {
        // Loop back or show completion
        currentTaskIndex = 0; 
      }
      isCorrect = null;
      showNextLevel = false;
    });
  }

  Future<void> speakLetter(String letter) async {
    try {
      // Check if we're on web platform
      if (identical(0, 0.0)) { // This is a trick to detect if running on web
        final played = await playSinhalaLetterAudio(letter);
        if (!played) {
          _speakOnWeb(letter);
        }
      } else {
        // Native platform
        await flutterTts.stop();
        await flutterTts.setLanguage('si-LK');
        await flutterTts.setSpeechRate(0.45);
        await flutterTts.setPitch(1.0);
        await flutterTts.speak(letter);
      }
    } catch (e) {
      print('Error speaking letter: $e');
      final played = await playSinhalaLetterAudio(letter);
      if (!played) {
        _speakOnWeb(letter); // Try web API as fallback
      }
    }
  }

  Future<void> _speakOnWeb(String letter) async {
    try {
      final speechSynthesis = web.window.speechSynthesis;
      
      // Cancel any ongoing speech
      speechSynthesis.cancel();
      
      // Log available voices count
      final voicesCount = speechSynthesis.getVoices().length;
      print('Available voices: $voicesCount');
      
      // Speak the actual Sinhala letter and prefer a Sinhala voice if the
      // browser has one available.
      if (voicesCount == 0) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Create utterance
      final utterance = web.SpeechSynthesisUtterance(letter);
      
      // Set properties for optimal audio output
      utterance.lang = 'si-LK';
      utterance.rate = 1.0; // Normal speed
      utterance.pitch = 1.0;
      utterance.volume = 1.0; // Maximum volume
      
      // Add event listeners for debugging
      utterance.onstart = ((web.SpeechSynthesisEvent event) {
        print('Speech started');
      }).toJS;
      
      utterance.onerror = ((web.SpeechSynthesisErrorEvent event) {
        print('Speech error: ${event.error}');
      }).toJS;
      
      utterance.onend = ((web.SpeechSynthesisEvent event) {
        print('Speech ended');
      }).toJS;
      
      // Speak the text
      print('Speaking Sinhala letter: $letter');
      speechSynthesis.speak(utterance);
    } catch (e) {
      print('Web Speech API error: $e');
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTask = tasks[currentTaskIndex];

    return Container(
      decoration: BoxDecoration(
        color: currentTask.bgColor,
        image: DecorationImage(
          image: AssetImage(currentTask.imagePath),
          opacity: 0.05,
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('අකුරු හඳුනාගනිමු - මට්ටම ${currentTaskIndex + 1}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'මේ අකුර හොයන්න!', // Find this letter!
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: currentTask.primaryColor,
                        shadows: const [
                          Shadow(color: Colors.white, blurRadius: 5, offset: Offset(2, 2))
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => speakLetter(currentTask.targetLetter),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentTask.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 6,
                      ),
                      icon: const Icon(Icons.volume_up_rounded, size: 30),
                      label: const Text(
                        'සවන් දෙන්න',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: currentTask.primaryColor, width: 8),
                        boxShadow: [
                          BoxShadow(color: currentTask.primaryColor.withOpacity(0.3), offset: const Offset(0, 10), blurRadius: 0)
                        ],
                      ),
                      child: Text(
                        currentTask.targetLetter,
                        style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 25),
                    if (isCorrect != null)
                      AnimatedScale(
                        scale: isCorrect! ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isCorrect! ? Icons.star_rounded : Icons.close_rounded,
                                    color: isCorrect! ? Colors.orange : Colors.red,
                                    size: 40,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isCorrect! ? 'නියමයි!' : 'නැවත උත්සාහ කරන්න',
                                    style: TextStyle(
                                      fontSize: 22, 
                                      fontWeight: FontWeight.w900,
                                      color: isCorrect! ? Colors.orange : Colors.red,
                                    ),
                                  )
                                ],
                              ),
                              if (showNextLevel) ...[
                                const SizedBox(height: 15),
                                ElevatedButton.icon(
                                  onPressed: nextTask,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: currentTask.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 5,
                                  ),
                                  icon: const Icon(Icons.arrow_forward_rounded, size: 24),
                                  label: const Text('ඊළඟ මට්ටම', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 15,
                      runSpacing: 15,
                      alignment: WrapAlignment.center,
                      children: currentTask.options.map((letter) {
                        return GestureDetector(
                          onTap: () {
                            checkAnswer(letter);
                          },
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: currentTask.primaryColor.withOpacity(0.5), width: 5),
                              boxShadow: [
                                BoxShadow(
                                  color: currentTask.primaryColor.withOpacity(0.3),
                                  offset: const Offset(0, 6),
                                  blurRadius: 0,
                                )
                              ],
                            ),
                            child: Center(
                              child: Text(
                                letter,
                                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black87),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: Image.asset(
                                currentTask.exampleWordImage,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  currentTask.defaultIcon,
                                  size: 96,
                                  color: currentTask.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              currentTask.exampleWord,
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                color: currentTask.primaryColor,
                                shadows: const [
                                  Shadow(color: Colors.white, blurRadius: 8, offset: Offset(2, 2)),
                                  Shadow(color: Colors.white, blurRadius: 8, offset: Offset(-2, -2)),
                                ],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


