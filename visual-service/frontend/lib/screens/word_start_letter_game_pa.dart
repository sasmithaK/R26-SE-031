import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ── Models ───────────────

class WordQuestion {
  final String word;
  final String missingFirstLetterText;
  final String correctLetter;
  final List<String> options;
  final String imagePath;

  WordQuestion({
    required this.word,
    required this.missingFirstLetterText,
    required this.correctLetter,
    required this.options,
    required this.imagePath,
  });
}

// ── Screen ───────────────

class WordStartLetterGamePa extends StatefulWidget {
  const WordStartLetterGamePa({super.key});

  @override
  State<WordStartLetterGamePa> createState() => _WordStartLetterGamePaState();
}

class _WordStartLetterGamePaState extends State<WordStartLetterGamePa> with TickerProviderStateMixin {
  int _currentQuestionIndex = 0;
  bool _answeredCorrectly = false;
  String? _selectedIncorrectLetter;
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  final List<WordQuestion> _questions = [
    WordQuestion(
      word: 'පහ',
      missingFirstLetterText: '_ හ',
      correctLetter: 'ප',
      options: ['ම', 'ග', 'ප', 'ර'],
      imagePath: 'assets/thumbnails/five.jpg',
    ),
    WordQuestion(
      word: 'පනාව',
      missingFirstLetterText: '_ නාව',
      correctLetter: 'ප',
      options: ['ග', 'ම', 'ර', 'ප'],
      imagePath: 'assets/thumbnails/comb.jpg',
    ),
    WordQuestion(
      word: 'පහන',
      missingFirstLetterText: '_ හන',
      correctLetter: 'ප',
      options: ['ප', 'ර', 'ම', 'ග'],
      imagePath: 'assets/thumbnails/OilLamp.jpg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _sendTelemetry(String eventType, Map<String, dynamic> additionalData) async {
    final url = Uri.parse('http://127.0.0.1:8001/telemetry');
    final payload = {
      'game': 'WordStartLetterGamePa',
      'event_type': eventType,
      'timestamp': DateTime.now().toIso8601String(),
      ...additionalData,
    };

    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('Telemetry Error: $e');
    }
  }

  Future<void> _updateMastery(bool correct) async {
    final url = Uri.parse('http://127.0.0.1:8002/api/v1/mastery/update');
    final payload = {
      'subject': 'sinhala_reading',
      'skill': 'start_letter_identification',
      'correct': correct,
    };

    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('Mastery Error: $e');
    }
  }

  void _onOptionTap(String letter) {
    if (_answeredCorrectly) return;

    final question = _questions[_currentQuestionIndex];
    if (letter == question.correctLetter) {
      setState(() {
        _answeredCorrectly = true;
        _selectedIncorrectLetter = null;
      });
      HapticFeedback.lightImpact();
      _sendTelemetry('answer_correct', {'word': question.word, 'letter': letter});
      _updateMastery(true);

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        if (_currentQuestionIndex < _questions.length - 1) {
          setState(() {
            _currentQuestionIndex++;
            _answeredCorrectly = false;
          });
        } else {
          _showVictoryDialog();
        }
      });
    } else {
      setState(() {
        _selectedIncorrectLetter = letter;
      });
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0);
      _sendTelemetry('answer_incorrect', {'word': question.word, 'letter': letter});
      _updateMastery(false);
    }
  }

  void _showVictoryDialog() {
    _sendTelemetry('game_completed', {});
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "නියමයි!", 
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
        ),
        content: const Text(
          "ඔබ සියලුම වචන නිවැරදිව හඳුනාගත්තා!", 
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); 
            },
            child: const Text(
              "ඉදිරියට යන්න", 
              style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + (_answeredCorrectly ? 1 : 0)) / _questions.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.grey, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "රූපයට ගැලපෙන මුල් අකුර තෝරන්න:", 
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    question.imagePath,
                    width: 280,
                    height: 280,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              Center(
                child: Text(
                  _answeredCorrectly ? question.word : question.missingFirstLetterText,
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: _answeredCorrectly ? Colors.green : Colors.black87,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.45, // Further reduce size of the grid layout to make boxes smaller
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: question.options.map((letter) {
                      final isCorrectAnswer = letter == question.correctLetter;
                      final isSelectedIncorrect = letter == _selectedIncorrectLetter;
                      
                      Color bgColor = Colors.white;
                      Color borderColor = Colors.grey[300]!;
                      Color textColor = Colors.black87;

                      if (_answeredCorrectly && isCorrectAnswer) {
                        bgColor = Colors.green;
                        borderColor = Colors.green;
                        textColor = Colors.white;
                      } else if (isSelectedIncorrect) {
                        bgColor = Colors.orange.withOpacity(0.1);
                        borderColor = Colors.orange;
                        textColor = Colors.orange;
                      }

                      Widget buttonWidget = GestureDetector(
                        onTap: () => _onOptionTap(letter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Text(
                                letter,
                                style: TextStyle(
                                  fontSize: 54, // Max size
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );

                      if (isSelectedIncorrect) {
                        return AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_shakeAnimation.value, 0),
                              child: child,
                            );
                          },
                          child: buttonWidget,
                        );
                      }

                      return buttonWidget;
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
  );
}
}

