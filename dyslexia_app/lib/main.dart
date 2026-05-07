import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_signup_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/questionnaire_screen.dart';
import 'screens/questionnaire_report_screen.dart';
import 'screens/student_preferences_screen.dart';
import 'screens/student_dashboard.dart';
import 'screens/letter_identification_task.dart';
import 'screens/word_matching_task.dart';
import 'screens/draw_a_man_test.dart';
import 'screens/story_sequencing_game.dart';
import 'screens/drawing_interpretation_game.dart';
import 'screens/syllable_train_game.dart';
import 'screens/firefly_tracking_game.dart';
import 'screens/reading_fluency_task.dart';
import 'screens/reading_comprehension_task.dart';

void main() {
  runApp(const DyslexiaApp());
}

class DyslexiaApp extends StatelessWidget {
  const DyslexiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dyslexia E-Learning',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        // Set Noto Sans Sinhala as the default font for the entire app
        textTheme: GoogleFonts.notoSansSinhalaTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginSignupScreen(),
        '/': (context) => const WelcomeScreen(),
        '/questionnaire': (context) => const QuestionnaireScreen(),
        '/questionnaire_reports': (context) => const QuestionnaireReportScreen(),
        '/student_preferences': (context) => const StudentPreferencesScreen(),
        '/student_dashboard': (context) => const StudentDashboard(),
        '/letter_id': (context) => const LetterIdentificationTask(),
        '/word_matching': (context) => const WordMatchingTask(),
        '/draw_a_man': (context) => const DrawAManTest(),
        '/story_sequencing': (context) => const StorySequencingGame(),
        '/drawing_interpretation': (context) => const DrawingInterpretationGame(),
        '/syllable_train': (context) => const SyllableTrainGame(),
        '/firefly_tracking': (context) => const FireflyTrackingGame(),
        '/reading_fluency': (context) => const ReadingFluencyTask(),
        '/reading_comprehension': (context) => const ReadingComprehensionTask(),
      },
    );
  }
}
