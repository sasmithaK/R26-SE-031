import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard/dashboard_kit.dart';

/// Messaging between therapists and parents is not implemented yet.
///
/// The previous screen showed scripted example conversations. It now shows an
/// honest placeholder until a real messages API exists, so no invented
/// clinical content appears in the app.
class TherapistMessagesScreen extends StatelessWidget {
  const TherapistMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text('Messages', style: DashText.heading(fontSize: 24)),
            const SizedBox(height: 16),
            const EmptyHint(
              icon: Icons.forum_outlined,
              title: 'Messaging is coming soon',
              message:
                  'In-app messages with parents are not available in this version. '
                  'Use each learner\'s evidence tabs and the shared PDF report, and contact '
                  'parents through your usual channel for now.',
            ),
          ],
        ),
      ),
    );
  }
}
