import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dyslexia_app/models/comprehension_progress.dart';
import 'package:dyslexia_app/services/comprehension_service.dart';

class ReadingComprehensionTask extends StatefulWidget {
  const ReadingComprehensionTask({super.key});

  @override
  State<ReadingComprehensionTask> createState() =>
      _ReadingComprehensionTaskState();
}

class _ReadingComprehensionTaskState extends State<ReadingComprehensionTask>
    with SingleTickerProviderStateMixin {
  // Sentences by level with corresponding correct picture index (0, 1, or 2)
  final Map<int, List<Map<String, dynamic>>> sentencesByLevel = {
    1: [
      {
        'sentence': 'බල්ලා දිවයි.',
        'correctImageIndex': 0, // running dog
        'images': ['🐕‍🦺 Running dog', '🐕 Sitting dog', '🐕 Eating dog'],
      },
      {
        'sentence': 'මල් පිපේ.',
        'correctImageIndex': 0, // blooming flower
        'images': ['🌸 Blooming flower', '🌵 Cactus', '🍃 Leaves'],
      },
      {
        'sentence': 'අම්මා එයි.',
        'correctImageIndex': 0, // mother
        'images': ['👩 Mother', '👨 Father', '👨‍⚕️ Doctor'],
      },
    ],
    2: [
      {
        'sentence': 'ගෙදර ළඟ ගසක් තිබේ.',
        'correctImageIndex': 0, // house with tree
        'images': ['🏠🌳 House with tree', '🏫🌳 School with tree', '🏠 House alone'],
      },
      {
        'sentence': 'අපි පාසල යමු.',
        'correctImageIndex': 0, // going to school
        'images': ['👨‍👩‍👧‍👦➡️🏫 Going to school', '👨‍👩‍👧‍👦➡️🏠 Going home', '👨‍👩‍👧‍👦➡️🏪 Going to store'],
      },
      {
        'sentence': 'ගුරුවරයා පොත ඉතුරුවයි.',
        'correctImageIndex': 0, // teacher teaching book
        'images': ['👨‍🏫📖 Teacher with book', '👨‍🏫❌ Teacher pointing no', '👨‍🏫🎨 Teacher drawing'],
      },
    ],
    3: [
      {
        'sentence': 'ළමයා ගෙදර ගොස් කෑම කෑවා.',
        'correctImageIndex': 0, // child eating at home
        'images': ['👧🏠🍴 Child eating at home', '👧🏫🍴 Child eating at school', '👧🏠🏃 Child running home'],
      },
      {
        'sentence': 'අම්මා කෑම හදගෙන වනවා.',
        'correctImageIndex': 0, // mom cooking
        'images': ['👩‍🍳🍳 Mom cooking', '👩‍⚕️💉 Mom at doctor', '👩 Mom reading'],
      },
      {
        'sentence': 'ගස් මතින් පතුරු වැටෙනවා.',
        'correctImageIndex': 0, // leaves falling from tree
        'images': ['🌳🍃⬇️ Leaves falling', '🌳☀️ Sunny tree', '🌳❄️ Snowy tree'],
      },
    ],
  };

  late String studentId;
  int currentLevel = 1;
  int currentSentenceIndex = 0;
  late String currentSentence;
  late List<String> words;
  List<bool> wordRead = [];
  int correctAnswers = 0;
  int totalAnswers = 0;

  Timer? _timer;
  DateTime? _startTime;
  Duration readingTime = Duration.zero;
  bool showingImages = false;
  int? selectedImageIndex;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.95,
      upperBound: 1.06,
    )..repeat(reverse: true);
    _loadStats();
    _loadNextSentence();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    studentId = prefs.getString('student_id') ??
        'student_${DateTime.now().millisecondsSinceEpoch}';

    // Try to load from MongoDB
    final progress = await ComprehensionService.getComprehensionProgress(studentId);
    if (progress != null) {
      setState(() {
        currentLevel = progress.highestLevelReached;
      });
    }
  }

  void _loadNextSentence() {
    if (currentSentenceIndex < sentencesByLevel[currentLevel]!.length) {
      final sentenceData = sentencesByLevel[currentLevel]![currentSentenceIndex];
      setState(() {
        currentSentence = sentenceData['sentence'];
        words = currentSentence.split(' ');
        wordRead = List<bool>.filled(words.length, false);
        readingTime = Duration.zero;
        showingImages = false;
        selectedImageIndex = null;
        _startTime = DateTime.now();
      });
    } else {
      _moveToNextLevel();
    }
  }

  void _toggleWord(int index) {
    setState(() {
      wordRead[index] = !wordRead[index];
    });

    // Check if all words are marked as read
    if (wordRead.every((read) => read)) {
      _recordReadingTime();
    }
  }

  void _recordReadingTime() {
    if (_startTime != null) {
      readingTime = DateTime.now().difference(_startTime!);
      _timer?.cancel();
      _showImages();
    }
  }

  void _showImages() {
    setState(() {
      showingImages = true;
    });
  }

  void _selectImage(int index) {
    setState(() {
      selectedImageIndex = index;
    });

    // Check if correct
    final sentenceData = sentencesByLevel[currentLevel]![currentSentenceIndex];
    final isCorrect = index == sentenceData['correctImageIndex'];

    if (isCorrect) {
      correctAnswers++;
    }
    totalAnswers++;

    // Show result briefly then move to next sentence
    Future.delayed(const Duration(milliseconds: 800), () {
      currentSentenceIndex++;
      if (currentSentenceIndex < sentencesByLevel[currentLevel]!.length) {
        _loadNextSentence();
      } else {
        _showLevelResults();
      }
    });
  }

  void _showLevelResults() {
    final accuracy = (correctAnswers / totalAnswers * 100).toStringAsFixed(1);
    final avgReadingTime = (readingTime.inMilliseconds / 1000).toStringAsFixed(2);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('මට්ටම සම්පූර්ණයි!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('මට්ටම: $currentLevel'),
            Text('නිවැරදි පිළිතුරු: $correctAnswers/${totalAnswers}'),
            Text('නිවැරදි ප්‍රතිශතය: $accuracy%'),
            Text('සාමාන්‍ය කියවීමේ වේලාව: ${avgReadingTime}s'),
          ],
        ),
        actions: [
          if (currentLevel < 3)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _moveToNextLevel();
              },
              child: const Text('ඊළඟ මට්ටමට යන්න'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveProgress();
              Navigator.pop(context);
            },
            child: const Text('අවසන් කරන්න'),
          ),
        ],
      ),
    );
  }

  void _moveToNextLevel() {
    if (currentLevel < 3) {
      setState(() {
        currentLevel++;
        currentSentenceIndex = 0;
        correctAnswers = 0;
        totalAnswers = 0;
      });
      _loadNextSentence();
    } else {
      _saveProgress();
      Navigator.pop(context);
    }
  }

  Future<void> _saveProgress() async {
    final accuracy = totalAnswers > 0 ? (correctAnswers / totalAnswers * 100) : 0.0;
    final avgReadingTime = totalAnswers > 0 ? readingTime.inSeconds / totalAnswers : 0.0;

    final progress = ComprehensionProgress(
      studentId: studentId,
      sessionsCompleted: 1,
      avgReadingTimeSeconds: avgReadingTime,
      comprehensionAccuracy: accuracy,
      highestLevelReached: currentLevel,
      failureLevel: 0,
      lastUpdated: DateTime.now(),
    );

    await ComprehensionService.saveComprehensionProgress(progress);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('rc_level', currentLevel);
    await prefs.setDouble('rc_accuracy', accuracy);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('කියවීමේ වටහා ගැනීම'),
            Text(
              'මට්ටම $currentLevel',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: !showingImages ? _buildSentenceReading() : _buildImageSelection(),
      ),
    );
  }

  Widget _buildSentenceReading() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.menu_book, size: 64, color: Colors.purple),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            children: [
              const Text(
                'පැහැදිලිවෙන් කියවන්න',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(words.length, (index) {
                  return GestureDetector(
                    onTap: () => _toggleWord(index),
                    child: ScaleTransition(
                      scale: wordRead[index]
                          ? AlwaysStoppedAnimation(1.0)
                          : _pulseController,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: wordRead[index]
                              ? Colors.green.shade200
                              : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: wordRead[index]
                                ? Colors.green
                                : Colors.blue.shade400,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          words[index],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: wordRead[index] ? Colors.green.shade900 : Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'සියලු වචන ටැප් කරන්න: ${wordRead.where((r) => r).length}/${words.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageSelection() {
    final sentenceData = sentencesByLevel[currentLevel]![currentSentenceIndex];
    final images = sentenceData['images'] as List<String>;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.image, size: 64, color: Colors.orange),
        const SizedBox(height: 32),
        const Text(
          'කුමන පින්තූරයද එය නිරූපණ කරයි?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            childAspectRatio: 3,
            mainAxisSpacing: 12,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final isSelected = selectedImageIndex == index;
            return GestureDetector(
              onTap: selectedImageIndex == null
                  ? () => _selectImage(index)
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.green : Colors.grey.shade400,
                    width: isSelected ? 3 : 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    images[index],
                    style: const TextStyle(fontSize: 32),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
