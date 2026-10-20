import 'package:flutter/material.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/therapist_dashboard_service.dart';
import '../../widgets/dashboard/dashboard_kit.dart';
import 'therapist_student_detail_screen.dart';

class TherapistStudentsScreen extends StatefulWidget {
  const TherapistStudentsScreen({super.key});

  @override
  State<TherapistStudentsScreen> createState() =>
      _TherapistStudentsScreenState();
}

class _TherapistStudentsScreenState extends State<TherapistStudentsScreen> {
  bool _isLoading = true;
  List<dynamic> _connections = [];
  Map<String, Map<String, dynamic>> _learnerById = {};

  @override
  void initState() {
    super.initState();
    _fetchConnections();
  }

  Future<void> _fetchConnections() async {
    final connections = await AuthService().getConnections();
    // Coverage and monitoring prompts come from the therapist summary; the
    // list still renders if that request fails.
    final learners = <String, Map<String, dynamic>>{};
    try {
      final summary = await TherapistDashboardService().getDashboardSummary();
      for (final raw in (summary['learners'] as List<dynamic>? ?? const [])) {
        if (raw is Map && raw['student_id'] != null) {
          learners[raw['student_id'].toString()] = Map<String, dynamic>.from(raw);
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _connections = connections;
        _learnerById = learners;
        _isLoading = false;
      });
    }
  }

  Widget _coverageFor(dynamic conn) {
    final learner = _learnerById[(conn is Map ? conn['student_id'] : null)?.toString() ?? ''];
    if (learner == null) return const SizedBox.shrink();
    final coverage = Map<String, dynamic>.from(learner['coverage'] as Map? ?? const {});
    final alerts = (learner['alerts'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .where((a) => a['severity'] == 'watch')
        .toList();
    int n(dynamic v) => v is num ? v.toInt() : 0;
    final recordings = n(coverage['recordings']);
    final usable = n(coverage['usable_recordings']);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last active: ${DashFormat.date(coverage['last_active_at'], fallback: 'no activity yet')}',
            style: DashText.body(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusChip(
                label: '${n(coverage['activity_sessions'])} activity sessions',
                tone: n(coverage['activity_sessions']) > 0 ? DashTone.good : DashTone.neutral,
                icon: Icons.touch_app_outlined,
              ),
              StatusChip(
                label: recordings == 0 ? 'No reading yet' : '$usable/$recordings clear recordings',
                tone: recordings == 0 ? DashTone.neutral : (usable > 0 ? DashTone.good : DashTone.watch),
                icon: Icons.mic_none_rounded,
              ),
              StatusChip(
                label: 'Questionnaire ${n(coverage['questionnaire_sections_done'])}/${n(coverage['questionnaire_sections_total'])}',
                tone: n(coverage['questionnaire_sections_done']) >= n(coverage['questionnaire_sections_total']) &&
                        n(coverage['questionnaire_sections_total']) > 0
                    ? DashTone.good
                    : DashTone.neutral,
                icon: Icons.assignment_outlined,
              ),
              if (alerts.isNotEmpty)
                StatusChip(
                  label: '${alerts.length} to watch',
                  tone: DashTone.watch,
                  icon: Icons.visibility_outlined,
                ),
            ],
          ),
        ],
      ),
    );
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My students',
                    style: DashText.heading(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.calmBlue),
                    tooltip: 'Reload students',
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _fetchConnections();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: AppLoadingIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchConnections,
                      color: AppColors.calmBlue,
                      child: _connections.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 100),
                                Center(
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
                                        style: DashText.heading(
                                          fontSize: 20,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                                      style: DashText.heading(
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
                                          style: DashText.heading(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Connected: ${conn['connected_at'] != null ? conn['connected_at'].split('T')[0] : 'Recently'}',
                                          style: DashText.caption(
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
                                      style: DashText.caption(
                                        color: AppColors.gentleGreen,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              _coverageFor(conn),
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
                                          style: DashText.body(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          parentEmail,
                                          style: DashText.caption(
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
                        );
                      },
                    ),
          ),
        ),
      ],
    ),
  ),
);
  }
}
