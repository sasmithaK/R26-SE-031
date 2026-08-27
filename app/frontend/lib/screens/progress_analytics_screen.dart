import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/app_loading_indicator.dart';
import '../theme/app_theme.dart';
import '../models/curriculum_models.dart';
import '../services/progress_service.dart';
import '../services/student_service.dart';

class ProgressAnalyticsScreen extends StatefulWidget {
  final Map<String, dynamic>? studentData;

  const ProgressAnalyticsScreen({super.key, this.studentData});

  @override
  State<ProgressAnalyticsScreen> createState() => _ProgressAnalyticsScreenState();
}

class _ProgressAnalyticsScreenState extends State<ProgressAnalyticsScreen> {
  CurriculumIndex? _curriculum;
  final Map<String, SkillDetail> _skillDetails = {};
  bool _isLoading = true;
  bool _isDownloadingReport = false;
  bool _isDownloadingAssessment = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await CurriculumIndex.load();
      // Load all skill details to get activities
      for (var skill in data.skills) {
        final detail = await SkillDetail.load(skill.file);
        _skillDetails[skill.id] = detail;
      }
      if (mounted) {
        setState(() {
          _curriculum = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ප්‍රගති දත්ත ලබා ගැනීමේ දෝෂයකි: $e')));
      }
    }
  }
  
  Future<void> _downloadReport() async {
    if (widget.studentData == null || widget.studentData!['id'] == null) return;
    
    setState(() => _isDownloadingReport = true);
    final error = await StudentService().downloadClinicalReport(widget.studentData!['id']);
    if (!mounted) return;
    setState(() => _isDownloadingReport = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.softCoral,
      ));
    }
  }

  Future<void> _downloadAssessmentReport() async {
    if (widget.studentData == null || widget.studentData!['id'] == null) return;
    
    setState(() => _isDownloadingAssessment = true);
    final error = await StudentService().downloadAssessmentReport(widget.studentData!['id']);
    if (!mounted) return;
    setState(() => _isDownloadingAssessment = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.softCoral,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = widget.studentData?['first_name'] ?? 'සිසුවා';

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.calmBlue,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'සිසු ප්‍රගතිය',
          style: AppTypography.heading(fontSize: 20, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator())
          : _curriculum == null
              ? const Center(child: Text("දත්ත නොමැත"))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (widget.studentData?['id'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isDownloadingReport ? null : _downloadReport,
                            icon: _isDownloadingReport
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.picture_as_pdf_rounded, size: 20),
                            label: Text(
                              _isDownloadingReport ? 'වාර්තාව සකසමින්...' : 'සායනික වාර්තාව බාගත කරන්න',
                              style: AppTypography.body(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.calmBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    if (widget.studentData?['id'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isDownloadingAssessment ? null : _downloadAssessmentReport,
                            icon: _isDownloadingAssessment
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.calmBlue, strokeWidth: 2))
                                : const Icon(Icons.assessment_rounded, size: 20),
                            label: Text(
                              _isDownloadingAssessment ? 'ඇගයීම සකසමින්...' : 'ඇගයීම් PDF බාගත කරන්න',
                              style: AppTypography.body(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.calmBlue,
                              side: const BorderSide(color: AppColors.calmBlue, width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ..._curriculum!.skills.map((skill) {
                      final detail = _skillDetails[skill.id];
                      return _buildSkillProgressCard(skill, detail);
                    }),
                  ],
                ),
    );
  }

  Widget _buildSkillProgressCard(SkillSummary skill, SkillDetail? detail) {
    final double progress = ProgressService().getSkillProgress(skill.id, skill.totalActivities);
    final int rawCompletedCount = ProgressService().getCompletedActivitiesCount(skill.id);
    final int completedCount = math.min(rawCompletedCount, skill.totalActivities);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      shadowColor: Colors.black26,
      color: Colors.white,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor: AppColors.calmBlue.withValues(alpha: 0.1),
          radius: 25,
          child: Icon(Icons.star_rounded, color: AppColors.warmAmber, size: 30),
        ),
        title: Text(
          skill.title,
          style: AppTypography.heading(fontSize: 16, color: AppColors.textPrimary),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completedCount / ${skill.totalActivities} ක් සම්පූර්ණයි',
                  style: AppTypography.caption(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: AppTypography.caption(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gentleGreen),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.borderLight,
              color: AppColors.gentleGreen,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: detail == null
                ? const Text("විස්තර නොමැත")
                : Column(
                    children: detail.activities.map((activity) {
                      bool isCompleted = ProgressService().isActivityCompleted(skill.id, activity.id);
                      int score = ProgressService().getActivityScore(skill.id, activity.id);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isCompleted ? AppColors.gentleGreen : AppColors.borderLight,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                activity.title,
                                style: AppTypography.body(
                                  fontSize: 14,
                                  color: isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warmAmber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'ලකුණු: $score%',
                                  style: AppTypography.caption(
                                    fontSize: 12,
                                    color: AppColors.orangeDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
