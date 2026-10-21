import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard/dashboard_kit.dart';

/// Parent notifications.
///
/// The earlier version listed invented notifications ("5 day streak",
/// "weekly report ready"). Until real notifications are generated from stored
/// activity, this screen points parents to the progress view and the PDF
/// learning summary instead.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text('Notifications', style: DashText.heading(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          EmptyHint(
            icon: Icons.notifications_none_rounded,
            title: 'No notifications yet',
            message:
                'Open your child\'s learning summary to see recent practice, and download '
                'the PDF summary to share with a teacher or therapist.',
          ),
        ],
      ),
    );
  }
}
