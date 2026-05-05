import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GamifiedOnboardingScreen extends StatefulWidget {
  @override
  _GamifiedOnboardingScreenState createState() => _GamifiedOnboardingScreenState();
}

class _GamifiedOnboardingScreenState extends State<GamifiedOnboardingScreen> {
  int step = 0; // 0: Font Size, 1: Color Theme
  String selectedFontSize = "Medium";
  String selectedTheme = "Light";

  // Visual Service Backend (Mocked for now, just sending a dummy request to show telemetry)
  final String visualServiceUrl = 'http://127.0.0.1:8004/api/v1/preferences/update';

  void savePreferencesAndStart() async {
    // Attempt to send baseline UI preferences to Visual Service
    try {
      await http.post(
        Uri.parse(visualServiceUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': 'grade1_student_01',
          'preferred_font_size': selectedFontSize,
          'preferred_theme': selectedTheme,
        }),
      );
    } catch (e) {
      print("Visual Service not running or unreachable, continuing anyway.");
    }
    
    // Navigate to the Main Menu
    Navigator.pushReplacementNamed(context, '/');
  }

  Widget _buildFontSizeStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Let's get ready! Tap the balloon that is easiest to read.",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 50),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBalloon("අ", "Small", 30),
            _buildBalloon("අ", "Medium", 50),
            _buildBalloon("අ", "Large", 80),
          ],
        )
      ],
    );
  }

  Widget _buildBalloon(String text, String sizeName, double fontSize) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFontSize = sizeName;
          step = 1; // Move to next step
        });
      },
      child: Container(
        width: 120,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.all(Radius.elliptical(120, 150)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            )
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(fontSize: fontSize, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Great! Now tap your favorite room color.",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 50),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildColorRoom("Daylight", Colors.yellow[100]!),
            _buildColorRoom("Calm Blue", Colors.blue[100]!),
            _buildColorRoom("High Contrast", Colors.black87, textColor: Colors.white),
          ],
        )
      ],
    );
  }

  Widget _buildColorRoom(String themeName, Color color, {Color textColor = Colors.black}) {
    return GestureDetector(
      onTap: () {
        selectedTheme = themeName;
        savePreferencesAndStart();
      },
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey, width: 2),
        ),
        child: Center(
          child: Text(
            themeName,
            style: TextStyle(fontSize: 20, color: textColor, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 500),
            child: step == 0 ? _buildFontSizeStep() : _buildThemeStep(),
          ),
        ),
      ),
    );
  }
}
