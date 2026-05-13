import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/adaptive_state.dart';
import 'screens/word_matching_task.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdaptiveState()),
      ],
      child: const DyslexiaAdaptiveApp(),
    ),
  );
}

class DyslexiaAdaptiveApp extends StatelessWidget {
  const DyslexiaAdaptiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AVLI Adaptive Interface',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.blueAccent,
        useMaterial3: true,
      ),
      home: const WordMatchingTask(),
    );
  }
}
