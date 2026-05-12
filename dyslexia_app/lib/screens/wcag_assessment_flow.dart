import 'package:flutter/material.dart';
import 'reading_comprehension_task.dart';
import 'reading_fluency_task.dart';
import 'story_reading_game.dart';
import 'word_matching_task.dart';

class WCAGAssessmentFlow extends StatefulWidget {
  const WCAGAssessmentFlow({super.key});

  @override
  State<WCAGAssessmentFlow> createState() => _WCAGAssessmentFlowState();
}

class _WCAGAssessmentFlowState extends State<WCAGAssessmentFlow> {
  int _currentStep = 0; // 0: Story Reading, 1: Word Matching, 2: Reading Fluency, 3: Reading Comprehension

  void _completeStoryReading() {
    setState(() {
      _currentStep = 1;
    });
  }

  void _completeWordMatching() {
    setState(() {
      _currentStep = 2;
    });
  }

  void _completeReadingFluency() {
    setState(() {
      _currentStep = 3;
    });
  }

  void _completeReadingComprehension() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    Navigator.pushReplacementNamed(
      context,
      '/student_dashboard',
      arguments: {
        'preferredColorIndex': args?['preferredColorIndex'] ?? 0,
        'preferredFontSize': args?['preferredFontSize'] ?? 20.0,
        'studentName': args?['studentName'] ?? '',
        'studentAge': args?['studentAge'] ?? '',
        'studentGrade': args?['studentGrade'] ?? '',
        'totalScore': args?['totalScore'] ?? 0,
        'tier': args?['tier'] ?? 'Tier 1',
        'isNewStudent': args?['isNewStudent'] ?? false,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 0) {
      return StoryReadingGame(onComplete: _completeStoryReading);
    } else if (_currentStep == 1) {
      return WordMatchingTask(onComplete: _completeWordMatching);
    } else if (_currentStep == 2) {
      return ReadingFluencyTask(onComplete: _completeReadingFluency);
    } else {
      return ReadingComprehensionTask(onComplete: _completeReadingComprehension);
    }
  }
}
