import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dyslexia_app/services/difficulty_profile_service.dart';
import '../utils/sinhala_letter_audio.dart'
  if (dart.library.html) '../utils/sinhala_letter_audio_web.dart';
import '../utils/sinhala_letter_web_speech.dart'
  if (dart.library.html) '../utils/sinhala_letter_web_speech_web.dart';
import 'package:dyslexia_app/models/letter_identification_score.dart';
import '../models/letter_picture_task.dart';
import '../services/letter_identification_service.dart';
import '../services/task_score_service.dart';
import 'package:dyslexia_app/widgets/skip_button.dart';
import 'package:dyslexia_app/utils/logger.dart';
import 'package:dyslexia_app/services/visual_service.dart';
import 'package:dyslexia_app/utils/visual_training_loop.dart';
import 'package:dyslexia_app/models/visual_config.dart';

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

  // Existing variables
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

  // NEW: Phonological awareness tracking
  bool showPhonologicalTask = false;
  bool? phonologicalCorrect;
  DateTime? visualDiscriminationStartTime;
  DateTime? phonologicalAwarenessStartTime;
  late String studentId;
  List<LetterIdentificationScore> sessionScores = [];
  late LetterPictureTask currentPictureTask;
  late List<PictureOption> randomizedPictures;
  TypographyConfig _typographyConfig = TypographyConfig.defaultConfig();

  void checkAnswer(String selectedLetter) {
    setState(() {
      isCorrect = selectedLetter == tasks[currentTaskIndex].targetLetter;
      if (isCorrect == true) {
        // Start phonological awareness task after visual success
        showPhonologicalTask = true;
        phonologicalAwarenessStartTime = DateTime.now();
        
        // Get picture task for this letter
        currentPictureTask = LetterPictureDatabase.getTaskForLetter(tasks[currentTaskIndex].targetLetter) 
          ?? LetterPictureDatabase.tasks.first;
        randomizedPictures = currentPictureTask.getRandomizedPictures();
        
        // Speak the letter sound for phonological task
        Future.delayed(const Duration(milliseconds: 500), () {
          speakLetter(tasks[currentTaskIndex].targetLetter);
        });
      } else {
        showNextLevel = false;
      }
    });
  }

  /// Handle phonological awareness picture selection
  Future<void> checkPhonologicalAnswer(PictureOption selectedPicture) async {
    final phonologicalTime = DateTime.now().difference(phonologicalAwarenessStartTime!).inSeconds;
    final visualTime = visualDiscriminationStartTime!.difference(DateTime.now()).inSeconds.abs();
    
    setState(() {
      phonologicalCorrect = selectedPicture.isCorrect;
    });

    if (phonologicalCorrect == true) {
      // Trigger MAB training loop reward
      VisualTrainingLoop().endLevel(accuracyDelta: 1.0);
    }
    
    // Save score
    final score = LetterIdentificationScore(
      studentId: studentId,
      letter: tasks[currentTaskIndex].targetLetter,
      visualDiscriminationCorrect: true, // We already validated this
      visualDiscriminationTime: visualTime,
      phonologicalAwarenessCorrect: phonologicalCorrect!,
      phonologicalAwarenessTime: phonologicalTime,
      attemptedAt: DateTime.now(),
    );
    
    sessionScores.add(score);
    
    // Save to MongoDB
    await LetterIdentificationService.saveLetterScore(score);

    // Also record a generic task score
    TaskScoreService.saveTaskScore(
      studentId: score.studentId,
      taskName: 'letter_identification',
      score: score.isSuccessful ? 1.0 : 0.0,
      durationSeconds: score.totalTime.toDouble(),
      metadata: {'letter': score.letter},
    ).then((ok) {
      if (ok) AppLogger.info('Task score saved for letter_identification');
    });
    
    // Show result for 1 second then proceed
    await Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        showNextLevel = true;
      });
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
      showPhonologicalTask = false;
      phonologicalCorrect = null;
      visualDiscriminationStartTime = DateTime.now();
    });
  }

  @override
  void initState() {
    super.initState();
    currentTaskIndex = DifficultyProfileService.startTaskIndexForLevel(
      DifficultyProfileService.cachedStartingGameLevel,
      tasks.length,
    );
    visualDiscriminationStartTime = DateTime.now();
    _loadStudentId();
  }

  Future<void> _loadStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      studentId = prefs.getString('student_id') ?? 'student_${DateTime.now().millisecondsSinceEpoch}';
    });
    _fetchAdaptiveTypography();
  }

  Future<void> _fetchAdaptiveTypography() async {
    try {
      final adaptiveData = await VisualService.getAdaptiveTypography('LetterIdentificationTask');
      if (adaptiveData != null && mounted) {
        final response = adaptiveData['response'] as TypographyResponse;
        final visualStrain = adaptiveData['visualStrain'] as double;
        
        setState(() {
          _typographyConfig = response.config;
        });

        // Start MAB training loop
        VisualTrainingLoop().startLevel(
          armId: response.armSelected,
          visualStrainBefore: visualStrain,
          sessionId: 'letter_id_${DateTime.now().millisecondsSinceEpoch}',
          studentId: response.studentId,
        );
      }
    } catch (e) {
      AppLogger.error('Error fetching typography for Letter ID Task: $e');
    }
  }

  Future<void> speakLetter(String letter) async {
    try {
      // Prefer native TTS, then fall back to the platform-specific helpers.
      if (identical(0, 0.0)) {
        final played = await playSinhalaLetterAudio(letter);
        if (!played) {
          await speakSinhalaLetterOnWeb(letter);
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
      AppLogger.error('Error speaking letter: $e');
      final played = await playSinhalaLetterAudio(letter);
      if (!played) {
        await speakSinhalaLetterOnWeb(letter);
      }
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
          actions: [
            SkipButton(taskName: 'letter_identification', onSkipped: nextTask),
          ],
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
                          BoxShadow(color: currentTask.primaryColor.withValues(alpha: 0.3), offset: const Offset(0, 10), blurRadius: 0)
                        ],
                      ),
                      child: Text(
                        currentTask.targetLetter,
                        style: TextStyle(
                          fontSize: _typographyConfig.fontSize + 56, // Large display
                          fontWeight: FontWeight.w900,
                          letterSpacing: _typographyConfig.letterSpacing,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    
                    // Show phonological awareness task if visual discrimination was correct
                    if (showPhonologicalTask) ...[
                      Text(
                        'මෙම ශබ්දයෙන් ආරම්භ වන පින්තූරය තෝරන්න',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: currentTask.primaryColor,
                          shadows: const [
                            Shadow(color: Colors.white, blurRadius: 5, offset: Offset(2, 2))
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
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
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 15,
                        runSpacing: 15,
                        alignment: WrapAlignment.center,
                        children: randomizedPictures.map((picture) {
                          return GestureDetector(
                            onTap: () => checkPhonologicalAnswer(picture),
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: currentTask.primaryColor.withValues(alpha: 0.5), width: 5),
                                boxShadow: [
                                  BoxShadow(
                                    color: currentTask.primaryColor.withValues(alpha: 0.3),
                                    offset: const Offset(0, 6),
                                    blurRadius: 0,
                                  )
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Image.asset(
                                      picture.imagePath,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        Icons.image,
                                        size: 50,
                                        color: currentTask.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // Show result of phonological task
                      if (phonologicalCorrect != null) ...[
                        const SizedBox(height: 20),
                        AnimatedScale(
                          scale: phonologicalCorrect! ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                phonologicalCorrect! ? Icons.star_rounded : Icons.close_rounded,
                                color: phonologicalCorrect! ? Colors.orange : Colors.red,
                                size: 40,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                phonologicalCorrect! ? 'නියමයි!' : 'නැවත උත්සාහ කරන්න',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: phonologicalCorrect! ? Colors.orange : Colors.red,
                                ),
                              )
                            ],
                          ),
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
                      ]
                    ] else ...[
                      // Show visual discrimination task
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
                                border: Border.all(color: currentTask.primaryColor.withValues(alpha: 0.5), width: 5),
                                boxShadow: [
                                  BoxShadow(
                                    color: currentTask.primaryColor.withValues(alpha: 0.3),
                                    offset: const Offset(0, 6),
                                    blurRadius: 0,
                                  )
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: TextStyle(
                                    fontSize: _typographyConfig.fontSize + 16, // Letter options
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: _typographyConfig.letterSpacing,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
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
                                fontSize: _typographyConfig.fontSize + 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: _typographyConfig.letterSpacing,
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


