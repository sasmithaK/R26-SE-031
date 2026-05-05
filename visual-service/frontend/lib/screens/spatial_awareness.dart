import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SpatialAwarenessGame extends StatefulWidget {
  @override
  _SpatialAwarenessGameState createState() => _SpatialAwarenessGameState();
}

class _SpatialAwarenessGameState extends State<SpatialAwarenessGame> {
  final String studentId = "student_001";
  
  final List<Map<String, dynamic>> directions = [
    {"label": "වමට (Left)", "icon": Icons.arrow_back, "direction": "left"},
    {"label": "දකුණට (Right)", "icon": Icons.arrow_forward, "direction": "right"},
    {"label": "ඉහළට (Up)", "icon": Icons.arrow_upward, "direction": "up"},
    {"label": "පහළට (Down)", "icon": Icons.arrow_downward, "direction": "down"},
  ];

  late Map<String, dynamic> currentTarget;
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
      currentTarget = directions[Random().nextInt(directions.length)];
      startTime = DateTime.now();
      errors = 0;
      isCorrect = false;
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
          "task_id": "spatial_awareness_01",
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

  void _handleChoice(String direction) {
    if (direction == currentTarget["direction"]) {
      final responseTime = DateTime.now().difference(startTime!).inSeconds;
      setState(() {
        isCorrect = true;
      });
      _sendTelemetry(responseTime, errors);
      
      Timer(Duration(seconds: 1), () {
        _startNewRound();
      });
    } else {
      setState(() {
        errors++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF9E6), // Friendly yellow background
      appBar: AppBar(
        title: Text("Stage 1: Where is the Lion?", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orangeAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "සිංහයා යන්නේ කොහාටද?",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.orange[800]),
            ),
            SizedBox(height: 10),
            Text(
              currentTarget["label"],
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 40),
            Icon(
              isCorrect ? Icons.check_circle : Icons.pets, 
              size: 100, 
              color: isCorrect ? Colors.green : Colors.orangeAccent
            ),
            SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDirectionButton("left", Icons.arrow_back),
                SizedBox(width: 20),
                Column(
                  children: [
                    _buildDirectionButton("up", Icons.arrow_upward),
                    SizedBox(height: 60), // Space for lion graphic
                    _buildDirectionButton("down", Icons.arrow_downward),
                  ],
                ),
                SizedBox(width: 20),
                _buildDirectionButton("right", Icons.arrow_forward),
              ],
            ),
            if (errors > 0)
              Padding(
                padding: const EdgeInsets.only(top: 30.0),
                child: Text("වැරදියි, නැවත උත්සාහ කරන්න ($errors)", style: TextStyle(color: Colors.red, fontSize: 18)),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionButton(String direction, IconData icon) {
    return InkWell(
      onTap: () => _handleChoice(direction),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isCorrect && direction == currentTarget["direction"] ? Colors.green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, spreadRadius: 2)],
        ),
        child: Icon(icon, size: 40, color: Colors.orangeAccent),
      ),
    );
  }
}
