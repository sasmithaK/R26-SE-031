import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SyllableChallengeGame extends StatefulWidget {
  @override
  _SyllableChallengeGameState createState() => _SyllableChallengeGameState();
}

class _SyllableChallengeGameState extends State<SyllableChallengeGame> {
  final String studentId = "student_001";
  
  final String targetWord = "කමිසය";
  final List<String> correctSyllables = ["ක", "මි", "ස", "ය"];
  List<String> jumbledSyllables = ["ස", "ක", "ය", "මි"];
  List<String> selectedSyllables = [];
  
  DateTime? startTime;
  int errors = 0;
  bool isCompleted = false;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  void _startRound() {
    setState(() {
      selectedSyllables.clear();
      jumbledSyllables.shuffle();
      startTime = DateTime.now();
      errors = 0;
      isCompleted = false;
    });
  }

  Future<void> _sendTelemetry(int responseTime, int errorCount) async {
    final url = Uri.parse('http://127.0.0.1:8001/telemetry');
    try {
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "student_id": studentId,
          "task_id": "syllable_challenge_01",
          "response_time": responseTime.toDouble(),
          "error_count": errorCount,
          "hesitation_count": 0,
          "input_velocity": 0.0
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
          "skill_id": "syllable_blending",
          "is_correct": correct,
          "response_latency_ms": DateTime.now().difference(startTime!).inMilliseconds.toDouble()
        }),
      );
    } catch (e) {
      print("Error updating mastery: $e");
    }
  }

  void _handleTap(String syllable) {
    if (isCompleted) return;

    setState(() {
      int nextExpectedIndex = selectedSyllables.length;
      if (syllable == correctSyllables[nextExpectedIndex]) {
        selectedSyllables.add(syllable);
        
        if (selectedSyllables.length == correctSyllables.length) {
          isCompleted = true;
          final responseTime = DateTime.now().difference(startTime!).inSeconds;
          _sendTelemetry(responseTime, errors);
          _updateMastery(errors == 0); // Correct mastery if no errors made
          
          Timer(Duration(seconds: 2), () {
            _startRound(); // Reset for demo purposes
          });
        }
      } else {
        errors++;
        _updateMastery(false); // Log a failed sub-attempt
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3E5F5), // Light purple
      appBar: AppBar(
        title: Text("Stage 3: Hear & Tap", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.purpleAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "වචනය සාදන්න",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.purple[800]),
            ),
            SizedBox(height: 10),
            Text(
              "ශබ්දය: 'කමිසය'",
              style: TextStyle(fontSize: 22, color: Colors.black54),
            ),
            SizedBox(height: 40),
            
            // Selected Box
            Container(
              height: 100,
              width: 350,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.purpleAccent, width: 3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(correctSyllables.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      index < selectedSyllables.length ? selectedSyllables[index] : "_",
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: isCompleted ? Colors.green : Colors.black),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: 50),
            
            // Jumbled Choices
            Wrap(
              spacing: 20,
              children: jumbledSyllables.map((syllable) {
                bool isSelected = selectedSyllables.contains(syllable);
                return InkWell(
                  onTap: isSelected ? null : () => _handleTap(syllable),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.grey[300] : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: isSelected ? [] : [BoxShadow(color: Colors.black12, blurRadius: 5)],
                    ),
                    child: Center(
                      child: Text(
                        syllable,
                        style: TextStyle(fontSize: 32, color: isSelected ? Colors.grey : Colors.purpleAccent),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            if (errors > 0 && !isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: Text("වැරදි අක්ෂරයකි ($errors)", style: TextStyle(color: Colors.red, fontSize: 18)),
              ),
              
            if (isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: Text("ඉතා හොඳයි!", style: TextStyle(color: Colors.green, fontSize: 28, fontWeight: FontWeight.bold)),
              )
          ],
        ),
      ),
    );
  }
}
