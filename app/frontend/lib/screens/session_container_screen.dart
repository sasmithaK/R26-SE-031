import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import '../services/session_manager.dart';
import '../services/telemetry_service.dart';

class SessionContainerScreen extends StatefulWidget {
  final Map<String, dynamic>? studentData;

  const SessionContainerScreen({super.key, this.studentData});

  @override
  State<SessionContainerScreen> createState() => _SessionContainerScreenState();
}

class _SessionContainerScreenState extends State<SessionContainerScreen> {
  late List<SessionActivity> _playlist;
  int _currentIndex = 0;
  bool _isSessionFinished = false;

  @override
  void initState() {
    super.initState();
    
    final studentId = widget.studentData?['student_id'] ?? widget.studentData?['id'] ?? widget.studentData?['_id'];
    if (studentId == null || studentId.toString().trim().isEmpty || studentId == 'STU001' || studentId == 'unknown_student') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Data Capture Error'),
            content: const Text('A valid student ID is strictly required to begin an activity session.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        );
      });
      return;
    }

    _playlist = SessionManager().generateDailySession();
    
    // Start telemetry
    TelemetryService().startSession();

    // Give it a brief moment before starting the first game
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _launchNextActivity();
      });
    });
  }

  Future<void> _launchNextActivity() async {
    if (_currentIndex >= _playlist.length) {
      // Session complete
      setState(() {
        _isSessionFinished = true;
      });
      // Submit telemetry
      final studentId = widget.studentData?['id'] ?? widget.studentData?['_id'];
      if (studentId != null && studentId.toString().isNotEmpty) {
        await TelemetryService().endSessionAndSubmit(studentId.toString());
      } else {
        debugPrint('Telemetry session submission skipped: No active student ID provided.');
      }
      return;
    }

    final activity = _playlist[_currentIndex];
    
    // Log telemetry activity start
    TelemetryService().startActivity(activity.title);

    // Push the activity screen on top
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => activity.screen),
    );

    // When the activity pops, it either completed successfully or the user backed out.
    if (!mounted) return;

    if (result == true) {
      // Success, move to next
      setState(() {
        _currentIndex++;
      });
      // Short delay before launching the next one
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && !_isSessionFinished) {
          _launchNextActivity();
        }
      });
    } else {
      // User pressed back button or cancelled
      // Submit what we have so far
      final studentId = widget.studentData?['id'] ?? 'unknown_student';
      TelemetryService().endSessionAndSubmit(studentId.toString());
      Navigator.pop(context); // Go back to dashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSessionFinished) {
      return Scaffold(
        backgroundColor: AppColors.mintBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(FontAwesomeIcons.medal, size: 80, color: AppColors.warmAmber),
              const SizedBox(height: 24),
              Text(
                'හොඳයි!', // "Great job!"
                style: AppTypography.sinhala(fontSize: 32, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text(
                'අද පාඩම අවසන්.', // "Today's lesson is finished."
                style: AppTypography.sinhala(fontSize: 24),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.calmBlue,
                ),
                child: Text('ආපසු', style: AppTypography.sinhala(fontSize: 20, color: Colors.white)), // "Back"
              ),
            ],
          ),
        ),
      );
    }

    // Interstitial screen between activities
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.calmBlue),
            const SizedBox(height: 24),
            Text(
              'සූදානම් වන්න...', // "Get ready..."
              style: AppTypography.sinhala(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_currentIndex < _playlist.length)
              Text(
                '${_currentIndex + 1} / ${_playlist.length}',
                style: AppTypography.heading(fontSize: 20, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
