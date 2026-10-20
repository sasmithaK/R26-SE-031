import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard/dashboard_kit.dart';

/// Placeholder for a future parent-therapist conversation view.
///
/// The constructor is kept so existing navigation still compiles, but the
/// scripted example conversation was removed: no invented messages are shown.
class TherapistChatScreen extends StatelessWidget {
  final String parentName;
  final String studentName;
  final String parentAvatar;

  const TherapistChatScreen({
    super.key,
    required this.parentName,
    required this.studentName,
    required this.parentAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(parentName, style: DashText.heading(fontSize: 19)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          EmptyHint(
            icon: Icons.forum_outlined,
            title: 'Messaging is coming soon',
            message: 'Conversations about $studentName will appear here once in-app messaging is available.',
          ),
        ],
      ),
    );
  }
}
