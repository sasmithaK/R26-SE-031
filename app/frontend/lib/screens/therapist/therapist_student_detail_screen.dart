import 'package:flutter/material.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../services/student_service.dart';
import '../../services/telemetry_service.dart';
import '../../widgets/telemetry_heatmap.dart';
import '../../services/localization_service.dart';

class TherapistStudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const TherapistStudentDetailScreen({super.key, required this.student});

  @override
  State<TherapistStudentDetailScreen> createState() => _TherapistStudentDetailScreenState();
}

class _TherapistStudentDetailScreenState extends State<TherapistStudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<Map<String, dynamic>> _analyticsFuture;

  // Mock weekly scores (8 weeks) for the chart as we don't have historical arrays yet
  final List<double> _weeklyScores = [42, 48, 45, 55, 52, 60, 63, 68];

  // Mock session history
  final List<Map<String, dynamic>> _sessions = [
    {
      'date': 'Jul 28, 2026',
      'duration': '45 min',
      'type': 'Phonological Awareness',
      'score': 78,
      'notes': 'Excellent progress in syllable segmentation. Struggling with phoneme deletion tasks.',
    },
    {
      'date': 'Jul 25, 2026',
      'duration': '40 min',
      'type': 'Reading Fluency',
      'score': 65,
      'notes': 'Read 42 words per minute (up from 38). Still pausing at multisyllabic words.',
    },
  ];

  String? _selectedLabel;
  bool _isSubmittingLabel = false;
  bool _isDownloadingReport = false;
  bool _isDownloadingAssessment = false;
  final List<String> _labelOptions = ["Low Risk", "Moderate Risk", "Needs Attention"];

  String get _studentId => (widget.student['id'] ?? widget.student['_id']).toString();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _analyticsFuture = StudentService().getCognitiveAnalytics(_studentId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _submitLabel() async {
    if (_selectedLabel == null) return;
    
    setState(() => _isSubmittingLabel = true);
    
    final error = await StudentService().submitClinicianLabel(
      _studentId, 
      _selectedLabel!
    );
    
    if (!mounted) return;
    
    setState(() => _isSubmittingLabel = false);
    
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ground Truth Label submitted successfully!'),
          backgroundColor: AppColors.gentleGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.softCoral,
        ),
      );
    }
  }

  Future<void> _downloadReport() async {
    setState(() => _isDownloadingReport = true);
    final error = await StudentService().downloadClinicalReport(_studentId);
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
    setState(() => _isDownloadingAssessment = true);
    final error = await StudentService().downloadAssessmentReport(_studentId);
    if (!mounted) return;
    setState(() => _isDownloadingAssessment = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.softCoral,
      ));
    }
  }

  Future<void> _showHeatmapsModal() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.calmBlue)),
    );

    final telemetryData = await StudentService().getTelemetry(_studentId);
    
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    if (telemetryData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No telemetry data available for this student yet.'),
        backgroundColor: AppColors.softCoral,
      ));
      return;
    }

    Map<String, List<TouchPoint>> activityPoints = {};
    for (var session in telemetryData) {
      final events = session['events'] as List<dynamic>? ?? [];
      for (var ev in events) {
        final actName = ev['activity_name'] as String? ?? 'Unknown';
        final path = ev['touch_path'] as List<dynamic>? ?? [];
        
        if (!activityPoints.containsKey(actName)) {
          activityPoints[actName] = [];
        }
        for (var pt in path) {
          activityPoints[actName]!.add(TouchPoint(
            xRatio: pt['x_ratio']?.toDouble() ?? 0.0,
            yRatio: pt['y_ratio']?.toDouble() ?? 0.0,
            timestampMs: pt['timestamp_ms'] ?? 0,
          ));
        }
      }
    }

    if (activityPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No touch paths found in the telemetry data.'),
        backgroundColor: AppColors.softCoral,
      ));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildHeatmapBottomSheet(activityPoints),
    );
  }

  Widget _buildHeatmapBottomSheet(Map<String, List<TouchPoint>> activityPoints) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC), // scaffold background
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Interaction Heatmaps',
                      style: AppTypography.heading(fontSize: 20, color: AppColors.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  itemCount: activityPoints.keys.length,
                  itemBuilder: (context, index) {
                    final actName = activityPoints.keys.elementAt(index);
                    final points = activityPoints[actName]!;
                    return HeatmapVisualizer(
                      touchPoints: points,
                      title: 'Activity: $actName',
                      subtitle: 'Aggregated touch precision tracking',
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _analyticsFuture,
          builder: (context, snapshot) {
            
            String risk = student['risk']?.toString() ?? 'pending';
            Map<String, dynamic> analytics = {};
            if (snapshot.hasData && snapshot.data!.isNotEmpty && snapshot.data!['status'] != 'insufficient_data') {
              analytics = snapshot.data!;
              if (analytics['risk_assessment'] != null && analytics['risk_assessment'] is Map) {
                risk = analytics['risk_assessment']['overall_risk']?.toString() ?? risk;
              }
            }

            return Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'student profile',
                          style: AppTypography.heading(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _getRiskColor(risk).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          risk.toLowerCase(),
                          style: AppTypography.caption(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _getRiskColor(risk),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Student Header Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.calmBlueDark.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.slateBg,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(student['avatar'] ?? '👦', style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name'] ?? student['first_name'] ?? student['student_name'] ?? 'Unknown',
                                style: AppTypography.heading(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${student['age'] ?? student['grade'] ?? 'N/A'} · parent: ${student['parent'] ?? student['parent_name'] ?? 'N/A'}',
                                style: AppTypography.caption(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${LocalizationService.instance.t('Connected_Since')} ${student['connected'] ?? student['connected_at']?.toString().split('T')[0] ?? 'N/A'}',
                                style: AppTypography.caption(
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Overall Progress Circle
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: (student['progress'] ?? 0) / 100,
                                strokeWidth: 5,
                                backgroundColor: AppColors.borderLight,
                                valueColor: AlwaysStoppedAnimation(_getRiskColor(risk)),
                              ),
                              Text(
                                '${student['progress'] ?? 0}%',
                                style: AppTypography.caption(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.calmBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: AppTypography.caption(fontSize: 13, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: AppTypography.caption(fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(text: 'progress'),
                      Tab(text: 'sessions'),
                      Tab(text: 'plan'),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Tab Content
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator(color: AppColors.calmBlue))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildProgressTab(analytics),
                            _buildSessionsTab(),
                            _buildPlanTab(analytics),
                          ],
                        ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  // ─── Progress Tab ───
  Widget _buildProgressTab(Map<String, dynamic> analytics) {
    Map<String, dynamic> indices = analytics['cognitive_indices'] ?? {};
    
    // Fallback if no analytics exist yet
    if (indices.isEmpty) {
      indices = {
        'waiting for data': 0.0,
        'needs more play': 0.0,
      };
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Download Report Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isDownloadingReport ? null : _downloadReport,
              icon: _isDownloadingReport
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: Text(
                _isDownloadingReport ? LocalizationService.instance.t('generating_report') : LocalizationService.instance.t('download_clinical_report'),
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
          const SizedBox(height: 12),
          
          // Download Assessment Report Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isDownloadingAssessment ? null : _downloadAssessmentReport,
              icon: _isDownloadingAssessment
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.calmBlue, strokeWidth: 2))
                  : const Icon(Icons.assessment_rounded, size: 20),
              label: Text(
                _isDownloadingAssessment ? LocalizationService.instance.t('generating_assessment') : LocalizationService.instance.t('download_assessment_pdf'),
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
          const SizedBox(height: 12),
          
          // View Interaction Heatmaps Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _showHeatmapsModal,
              icon: const Icon(Icons.touch_app_rounded, size: 20),
              label: Text(
                LocalizationService.instance.t('View_Interaction_Heatmaps'),
                style: AppTypography.body(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.gentleGreen,
                side: const BorderSide(color: AppColors.gentleGreen, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Weekly Progress Chart
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: AppColors.calmBlueDark.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'weekly progress',
                      style: AppTypography.body(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.mintBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.trending_up_rounded, size: 14, color: AppColors.gentleGreen),
                          const SizedBox(width: 4),
                          Text(
                            '+26%',
                            style: AppTypography.caption(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gentleGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 140,
                  child: CustomPaint(
                    size: const Size(double.infinity, 140),
                    painter: _ChartPainter(scores: _weeklyScores),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(8, (i) => Text(
                    'W${i + 1}',
                    style: AppTypography.caption(fontSize: 10, color: AppColors.textHint),
                  )),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Real Cognitive Skill Breakdown
          Text(
            'cognitive breakdown',
            style: AppTypography.body(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          ...indices.entries.map((entry) {
            double value = (entry.value is num) ? (entry.value as num).toDouble() : 0.0;
            // Normalize visual value if it exceeds 1
            double barValue = value > 1.0 ? 1.0 : (value < 0 ? 0.0 : value);
            
            // Format name nicely
            String name = entry.key.replaceAll('_', ' ').toLowerCase();
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: AppTypography.body(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${(value * 100).round()}%',
                          style: AppTypography.caption(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _getSkillColor(barValue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: barValue,
                        minHeight: 8,
                        backgroundColor: AppColors.borderLight,
                        valueColor: AlwaysStoppedAnimation(_getSkillColor(barValue)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Sessions Tab ───
  Widget _buildSessionsTab() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: AppColors.calmBlueDark.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.slateBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_note_rounded, color: AppColors.calmBlue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['type'],
                          style: AppTypography.body(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${session['date']} · ${session['duration']}',
                          style: AppTypography.caption(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getScoreColor(session['score']).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${session['score']}%',
                      style: AppTypography.caption(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _getScoreColor(session['score']),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session['notes'],
                        style: AppTypography.caption(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Intervention Plan Tab ───
  Widget _buildPlanTab(Map<String, dynamic> analytics) {
    List<dynamic> interventions = analytics['recommendations'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clinical Labeling Form for ML Pipeline
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: AppColors.calmBlueDark.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_outlined, color: AppColors.calmBlue, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'provide clinical label',
                      style: AppTypography.body(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your assessment feeds our ML models. Please select the ground-truth risk level for this student based on their data.',
                  style: AppTypography.caption(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLabel,
                      hint: Text(
                        'Select Risk Label',
                        style: AppTypography.caption(fontSize: 14, color: AppColors.textHint),
                      ),
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                      items: _labelOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: AppTypography.body(fontSize: 14, color: AppColors.textPrimary),
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedLabel = newValue;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmittingLabel || _selectedLabel == null ? null : _submitLabel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.calmBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmittingLabel
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : Text(
                            'Submit Ground Truth Label',
                            style: AppTypography.body(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'recommended interventions',
            style: AppTypography.body(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          if (interventions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No interventions generated yet.\nChild needs to play more games.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption(color: AppColors.textHint, fontSize: 14),
                ),
              ),
            ),

          ...interventions.map((intervention) {
            final type = intervention['type'] ?? 'general';
            final title = intervention['title'] ?? 'Strategy';
            final description = intervention['description'] ?? '';
            
            // Map type to visual
            Color cardColor = AppColors.calmBlue;
            IconData cardIcon = Icons.lightbulb_outline_rounded;
            
            if (type == 'cognitive') {
              cardColor = AppColors.warmAmber;
              cardIcon = Icons.psychology_alt_rounded;
            } else if (type == 'sensory') {
              cardColor = AppColors.softCoral;
              cardIcon = Icons.visibility_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.calmBlueDark.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(cardIcon, color: cardColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cardColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            type,
                            style: AppTypography.caption(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: cardColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: AppTypography.body(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: AppTypography.caption(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Color _getRiskColor(String risk) {
    if (risk.toLowerCase().contains('on track') || risk.toLowerCase().contains('low')) {
      return AppColors.gentleGreen;
    } else if (risk.toLowerCase().contains('moderate') || risk.toLowerCase().contains('support')) {
      return AppColors.warmAmber;
    } else {
      return AppColors.softCoral;
    }
  }

  Color _getSkillColor(double value) {
    if (value >= 0.7) return AppColors.gentleGreen;
    if (value >= 0.55) return AppColors.warmAmber;
    return AppColors.softCoral;
  }

  Color _getScoreColor(int score) {
    if (score >= 70) return AppColors.gentleGreen;
    if (score >= 55) return AppColors.warmAmber;
    return AppColors.softCoral;
  }
}

// ─── Custom Chart Painter ───
class _ChartPainter extends CustomPainter {
  final List<double> scores;

  _ChartPainter({required this.scores});

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final maxScore = scores.reduce(max);
    final minScore = scores.reduce(min);
    final range = maxScore - minScore;

    final points = <Offset>[];
    for (int i = 0; i < scores.length; i++) {
      final x = (i / (scores.length - 1)) * size.width;
      final y = size.height - ((scores[i] - minScore) / (range == 0 ? 1 : range)) * (size.height - 20) - 10;
      points.add(Offset(x, y));
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 0.5;

    for (int i = 0; i < 4; i++) {
      final y = (i / 3) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Gradient fill
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x334A90D9), Color(0x004A90D9)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = const Color(0xFF4A90D9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dots
    final dotPaint = Paint()..color = const Color(0xFF4A90D9);
    final dotBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final p in points) {
      canvas.drawCircle(p, 4, dotPaint);
      canvas.drawCircle(p, 4, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
