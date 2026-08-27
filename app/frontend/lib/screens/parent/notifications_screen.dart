import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';

/// Notifications Screen — Milestones, therapist updates, reminders.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // Mock notifications grouped by date
  List<Map<String, dynamic>> get _notifications => [
        {
          'date': 'today',
          'items': [
            {
              'icon': FontAwesomeIcons.trophy,
              'color': AppColors.warmAmber,
              'title': 'milestone achieved!',
              'body': 'Sami completed Level 5 in Letter Recognition!',
              'time': '2 hours ago',
            },
            {
              'icon': FontAwesomeIcons.fire,
              'color': AppColors.softCoral,
              'title': '5 day streak!',
              'body': 'Sami has been learning for 5 days in a row. Keep it up!',
              'time': '4 hours ago',
            },
          ],
        },
        {
          'date': 'yesterday',
          'items': [
            {
              'icon': FontAwesomeIcons.userDoctor,
              'color': AppColors.gentleGreen,
              'title': 'therapist update',
              'body': 'Dr. Nishara Silva reviewed Sami\'s weekly progress report.',
              'time': '1 day ago',
            },
            {
              'icon': FontAwesomeIcons.star,
              'color': AppColors.warmAmber,
              'title': '50 stars earned!',
              'body': 'Sami has collected 50 stars total. Amazing progress!',
              'time': '1 day ago',
            },
          ],
        },
        {
          'date': 'this_week',
          'items': [
            {
              'icon': FontAwesomeIcons.chartLine,
              'color': AppColors.calmBlue,
              'title': 'weekly report ready',
              'body': 'Sami\'s weekly learning report is available. Tap to view.',
              'time': '3 days ago',
            },
            {
              'icon': FontAwesomeIcons.bell,
              'color': AppColors.textSecondary,
              'title': 'daily reminder',
              'body': 'Sami hasn\'t played today yet. A quick session can help!',
              'time': '4 days ago',
            },
          ],
        },
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              ..._notifications.map((group) => _buildDateGroup(group)),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
      }
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warmAmber.withValues(alpha: 0.08),
            AppColors.cream,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              LocalizationService.instance.t('notifications'),
              style: AppTypography.heading(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // Unread count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.softCoral,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '3 ${LocalizationService.instance.t('new')}',
              style: AppTypography.caption(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateGroup(Map<String, dynamic> group) {
    final items = group['items'] as List<Map<String, dynamic>>;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              LocalizationService.instance.t(group['date'] as String),
              style: AppTypography.caption(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.calmBlue,
              ),
            ),
          ),
          ...items.map((item) => _buildNotificationCard(item)),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final color = item['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: FaIcon(item['icon'] as dynamic,
                  size: 18, color: color),
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] as String,
                  style: AppTypography.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['body'] as String,
                  style: AppTypography.body(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['time'] as String,
                  style: AppTypography.caption(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
