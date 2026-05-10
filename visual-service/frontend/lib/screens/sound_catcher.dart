import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/intervention_poller.dart';
import '../services/score_service.dart';

class SoundCatcherGame extends StatefulWidget {
  @override
  _SoundCatcherGameState createState() => _SoundCatcherGameState();
}

class _SoundCatcherGameState extends State<SoundCatcherGame>
    with InterventionPollerMixin<SoundCatcherGame> {
  @override
  String get studentId => "student_001";
  String currentTargetSound = "අ";
  List<String> options = ["අ", "ආ", "ඇ", "ඈ"];
  DateTime? startTime;
  int errors = 0;
  bool isCorrect = false;

  @override
  void initState() {
    super.initState();
    _startNewRound();
  }

  void _startNewRound() {
    setState(() {
      currentTargetSound = options[Random().nextInt(options.length)];
      startTime = DateTime.now();
      errors = 0;
      isCorrect = false;
    });
  }

  Future<void> _sendTelemetry(int responseTime, int errorCount) async {
    final url = Uri.parse('http://127.0.0.1:8001/api/v1/telemetry');
    try {
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "student_id": studentId,
          "task_id": "sound_catcher_01",
          "response_time": responseTime.toDouble(),
          "error_count": errorCount,
          "hesitation_count": errors > 1 ? 1 : 0,
          "input_velocity": startTime != null
              ? DateTime.now().difference(startTime!).inMilliseconds.toDouble()
              : 0.0,
        }),
      );
    } catch (e) {
      print("Error sending telemetry: $e");
    }
  }

  Future<void> _updateMastery(bool correct) async {
    final url = Uri.parse('http://127.0.0.1:8002/api/v1/mastery/update');
    try {
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "student_id": studentId,
          "skill_id": "vowel_recognition",
          "is_correct": correct,
          "response_latency_ms": DateTime.now().difference(startTime!).inMilliseconds.toDouble()
        }),
      );
    } catch (e) {
      print("Error updating mastery: $e");
    }
  }

  double _calculateScore(int responseTimeSeconds, int errorCount) {
    final baseScore = 10.0;
    final penalty = (errorCount * 2.0) + (responseTimeSeconds * 0.5);
    final score = baseScore - penalty;
    return score < 0 ? 0 : score;
  }

  void _handleChoice(String choice) {
    if (choice == currentTargetSound) {
      final responseTime = DateTime.now().difference(startTime!).inSeconds;
      setState(() {
        isCorrect = true;
      });
      _sendTelemetry(responseTime, errors);
      _updateMastery(true);
      ScoreService.saveTaskScore(
        studentId: studentId,
        taskId: 'sound_catcher_01',
        taskName: 'Stage 2: Sound Catcher',
        score: _calculateScore(responseTime, errors),
        maxScore: 10,
        durationSeconds: DateTime.now().difference(startTime!).inMilliseconds / 1000,
        metadata: {
          'errors': errors,
          'target_sound': currentTargetSound,
        },
      );
      
      Timer(Duration(seconds: 1), () {
        _startNewRound();
      });
    } else {
      setState(() {
        errors++;
      });
      _updateMastery(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeBackground,
      appBar: AppBar(
        title: Text("Sound Catcher (හඬ අල්ලන්නා)", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "පහත ශබ්දය තෝරන්න:",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: themeText,
                letterSpacing: adaptiveCharSpacing,
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Text(
                currentTargetSound,
                style: TextStyle(fontSize: 80, color: Colors.blueAccent),
              ),
            ),
            SizedBox(height: 40),
            Wrap(
              spacing: 20,
              children: options.map((option) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    backgroundColor: isCorrect && option == currentTargetSound 
                      ? Colors.green 
                      : Colors.white,
                    foregroundColor: Colors.blueAccent,
                  ),
                  onPressed: () => _handleChoice(option),
                  child: Text(option, style: TextStyle(fontSize: 32)),
                );
              }).toList(),
            ),
            if (errors > 0)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("උත්සාහයන්: $errors", style: TextStyle(color: Colors.red, fontSize: 18)),
              )
          ],
        ),
      ),
    );
  }
}
