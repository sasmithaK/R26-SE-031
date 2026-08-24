import 'package:flutter/material.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'therapist_student_detail_screen.dart';
import '../../services/localization_service.dart';

class TherapistStudentsScreen extends StatefulWidget {
  const TherapistStudentsScreen({super.key});

  @override
  State<TherapistStudentsScreen> createState() =>
      _TherapistStudentsScreenState();
}

class _TherapistStudentsScreenState extends State<TherapistStudentsScreen> {
  bool _isLoading = true;
  List<dynamic> _connections = [];

  @override
  void initState() {
    super.initState();
    _fetchConnections();
  }

  Future<void> _fetchConnections() async {
    final connections = await AuthService().getConnections();
    if (mounted) {
      setState(() {
        _connections = connections;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                LocalizationService.instance.t('my_students'),
                style: AppTypography.heading(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: AppLoadingIndicator())
                  : _connections.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_off_rounded,
                            size: 64,
                            color: AppColors.textHint.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No students assigned yet.",
                            style: AppTypography.heading(
                              fontSize: 20,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _connections.length,
                      itemBuilder: (context, index) {
                        final conn = _connections[index];
                        final studentName =
                            conn['student_name'] ?? 'Unknown Student';
                        final studentInitials = studentName.isNotEmpty
                            ? studentName[0].toUpperCase()
                            : '?';

                        final parentName =
                            conn['parent_name'] ?? 'Unknown Parent';
                        final parentEmail =
                            conn['parent_email'] ?? 'No email provided';

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TherapistStudentDetailScreen(student: conn),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.borderLight),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.shadow.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Student Details Row
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppColors.calmBlue
                                        .withValues(alpha: 0.2),
                                    child: Text(
                                      studentInitials,
                                      style: AppTypography.heading(
                                        fontSize: 24,
                                        color: AppColors.calmBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studentName,
                                          style: AppTypography.heading(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${LocalizationService.instance.t('Connected_Since')}: ${conn['connected_at'] != null ? conn['connected_at'].split('T')[0] : LocalizationService.instance.t('recent')}',
                                          style: AppTypography.caption(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.gentleGreen.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      conn['status'] ?? 'Active',
                                      style: AppTypography.caption(
                                        color: AppColors.gentleGreen,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                  color: AppColors.borderLight,
                                  height: 1,
                                ),
                              ),

                              // Parent Details Row
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.slateBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.family_restroom_rounded,
                                      size: 20,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Parent: $parentName',
                                          style: AppTypography.body(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          parentEmail,
                                          style: AppTypography.caption(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ), // Closes Column
                        ), // Closes Container
                        ); // Closes GestureDetector
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
