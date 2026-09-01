import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../services/therapist_dashboard_service.dart';
import '../../utils/avatar_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/trend_chart.dart';
import '../../widgets/research_evidence_panel.dart';
import '../../models/comprehensive_assessment_questions.dart';

class TherapistStudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const TherapistStudentDetailScreen({super.key, required this.student});

  @override
  State<TherapistStudentDetailScreen> createState() => _TherapistStudentDetailScreenState();
}

class _TherapistStudentDetailScreenState extends State<TherapistStudentDetailScreen> {
  final TherapistDashboardService _dashboardService = TherapistDashboardService();
  bool _isLoading = true;
  Map<String, dynamic>? _evidence;
  
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _c1Behavioral;
  Map<String, dynamic>? _c2Speech;
  Map<String, dynamic>? _c3Profile;
  Map<String, dynamic>? _c4Adaptive;
  String? _errorMessage;
  String _selectedAssessmentCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (mounted) setState(() => _isLoading = true);
    final studentId = widget.student['student_id']?.toString() ?? widget.student['id']?.toString() ?? widget.student['_id']?.toString();
    Future<Map<String, dynamic>> capture(Future<Map<String, dynamic>> request) async {
      try { return await request; } catch (e) { return {'_error': e.toString()}; }
    }
    final responses = studentId == null || studentId.isEmpty
        ? List.generate(6, (_) => <String, dynamic>{'_error': 'Invalid student ID'})
        : await Future.wait([
            capture(_dashboardService.getOverview(studentId)),
            capture(_dashboardService.getC1Behavioral(studentId)),
            capture(_dashboardService.getC2Speech(studentId)),
            capture(_dashboardService.getC3Profile(studentId)),
            capture(_dashboardService.getC4Adaptive(studentId)),
            capture(_dashboardService.getResearchEvidence(studentId)),
          ]);
    if (!mounted) return;
    setState(() {
      _overview = responses[0];
      _c1Behavioral = responses[1];
      _c2Speech = responses[2];
      _c3Profile = responses[3];
      _c4Adaptive = responses[4];
      _evidence = responses[5];
      _isLoading = false;
      _errorMessage = null;
    });
  }
  Future<void> _downloadPdf() async {
    final studentId = widget.student['student_id']?.toString() ?? widget.student['id']?.toString() ?? widget.student['_id']?.toString();
    if (studentId == null) return;
    try {
      // Show loading snackbar
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF Report...')));
      // Fetch pdf
      final bytes = await _dashboardService.downloadReport(studentId);
      await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: 'Sipsara_Report.pdf')], fileNameOverrides: ['Sipsara_Report.pdf']));
      // Let's assume standard flutter 'dart:html' downloading for web, but since this is mobile/multi we just show success for now.
      // In a real app we'd use path_provider and open_file, or printing package.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report ready in the share dialog.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error downloading report: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = _overview?['first_name'] ?? _overview?['student_name'] ?? widget.student['first_name'] ?? widget.student['student_name'] ?? widget.student['name'] ?? 'Student';
    final avatar = AvatarUtils.getCorrectedAvatarPath(
        (_overview?['avatar_url'] ?? widget.student['avatar_url']) as String?, 
        'assets/images/characters/human/human_student_1.png');

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.calmBlue),
              tooltip: 'Reload latest data',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refreshing student data...'), duration: Duration(seconds: 1)),
                );
                _loadAllData();
              },
            ),
          ],
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: AssetImage(avatar),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Therapist Student: $name',
                  style: AppTypography.heading(fontSize: 18, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.calmBlue,
            unselectedLabelColor: AppColors.textHint,
            indicatorColor: AppColors.calmBlue,
            tabs: [
              Tab(text: "Overview"),
              Tab(text: "Behavioral Analytics"),
              Tab(text: "Speech & Sinhala Interaction"),
              Tab(text: "Learner Profile & XAI"),
              Tab(text: "Adaptive Learning"),
              Tab(text: "Parent Assessment"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: AppLoadingIndicator())
            : _errorMessage != null 
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                : RefreshIndicator(
                    onRefresh: _loadAllData,
                    color: AppColors.calmBlue,
                    child: TabBarView(
                      children: [
                        DashboardSection(data: _overview, onRetry: _loadAllData, child: _buildOverviewTab()),
                        DashboardSection(data: _c1Behavioral, onRetry: _loadAllData, child: _buildC1BehavioralTab()),
                        DashboardSection(data: _c2Speech, onRetry: _loadAllData, child: _buildC2SpeechTab()),
                        DashboardSection(data: _c3Profile, onRetry: _loadAllData, child: _buildC3ProfileTab()),
                        DashboardSection(data: _c4Adaptive, onRetry: _loadAllData, child: _buildC4AdaptiveTab()),
                        DashboardSection(data: {}, onRetry: _loadAllData, child: _buildAssessmentTab()),
                      ],
                    ),
                  ),
      ),
    );
  }

  // ==========================================
  // 1. OVERVIEW
  // ==========================================
  Widget _buildOverviewTab() {
    final accuracy = _overview?['accuracy'];
    final mastery = _overview?['overall_mastery'];
    final c1Avail = _overview?['c1_available'] == true;
    final c2Avail = _overview?['c2_available'] == true;
    final c3Avail = _overview?['c3_available'] == true;
    final c4Avail = _overview?['c4_available'] == true;
    final recommendation = _overview?['latest_recommendation'] ?? "No recommendation available.";
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildModelInfo(_overview ?? {}),
              if (_overview?['last_active'] != null)
                Text("Last Active: ${_overview!['last_active']}", style: AppTypography.caption()),
            ],
          ),
          const SizedBox(height: 16),
          // ── Child Details Section ──
          _buildChildProfileCard(widget.student),
          const SizedBox(height: 16),
          // Availability Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAvailabilityBadge("Behavioral", c1Avail),
              _buildAvailabilityBadge("Speech", c2Avail),
              _buildAvailabilityBadge("Learner Profile", c3Avail),
              _buildAvailabilityBadge("Adaptive", c4Avail),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard("First-attempt Accuracy", metricText(accuracy, scale: 100, suffix: '%', decimals: 0), FontAwesomeIcons.bullseye, AppColors.gentleGreen),
              _buildStatCard("Mean BKT Estimate", metricText(mastery, scale: 100, suffix: '%', decimals: 0), FontAwesomeIcons.brain, AppColors.calmBlue),
              _buildStatCard("Model Mastery Status", _overview?['reading_fluency_status'] ?? "-", FontAwesomeIcons.chartLine, AppColors.warmAmber),
              _buildStatCard("Fatigue", _overview?['fatigue_status'] ?? "Low", FontAwesomeIcons.batteryHalf, AppColors.softCoral),
              _buildStatCard("Current Pattern", _overview?['current_pattern'] ?? "Unknown", FontAwesomeIcons.puzzlePiece, AppColors.calmBlue),
              _buildStatCard("Completed Sessions", "${_overview?['completed_sessions'] ?? 0}", FontAwesomeIcons.calendarCheck, AppColors.gentleGreen),
            ],
          ),
          const SizedBox(height: 24),
          Text("Latest Recommendation", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.calmBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(recommendation, style: const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          ),
          const SizedBox(height: 24),
          // ── Clinical Therapist Report Export Box ──
          _buildClinicalReportExportCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==========================================
  // 1b. PARENT ASSESSMENT TAB
  // ==========================================
  Widget _buildAssessmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildAssessmentAnswersSection(widget.student),
    );
  }

  // ==========================================
  // 2. C1 — BEHAVIORAL ANALYTICS
  // ==========================================
  Widget _buildC1BehavioralTab() {
    final firstAttemptAcc = _c1Behavioral?['first_attempt_accuracy'];
    final medianLat = _c1Behavioral?['median_response_latency_ms'];
    final retryRate = _c1Behavioral?['retry_rate'];
    final meanAttempts = _c1Behavioral?['mean_attempts_per_round'];
    final medianTimeToCorrect = _c1Behavioral?['median_time_to_correct_ms'];
    final fatigue = _c1Behavioral?['behavioral_fatigue_proxy'];

    final kcPerformance = _c1Behavioral?['kc_performance'] != null ? Map<String, dynamic>.from(_c1Behavioral!['kc_performance']) : <String, dynamic>{};
    final errors = _c1Behavioral?['error_distribution'] != null ? Map<String, dynamic>.from(_c1Behavioral!['error_distribution']) : <String, dynamic>{};
    
    final trends = _c1Behavioral?['trends'] != null ? Map<String, dynamic>.from(_c1Behavioral!['trends']) : <String, dynamic>{};
    final accTrendRaw = trends['accuracy'] as List<dynamic>? ?? [];
    final latTrendRaw = trends['latency'] as List<dynamic>? ?? [];
    final fatTrendRaw = trends['fatigue'] as List<dynamic>? ?? [];
    
    final accTrend = accTrendRaw.map((e) => (e['value'] as num?)?.toDouble()).toList();
    final latTrend = latTrendRaw.map((e) => e['value'] is num ? (e['value'] as num).toDouble() / 1000 : null).toList();
    final fatTrend = fatTrendRaw.map((e) => (e['value'] as num?)?.toDouble()).toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModelInfo(_c1Behavioral ?? {}),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              int cardsPerRow = constraints.maxWidth > 600 ? 3 : 2;
              double spacing = 12.0;
              double cardWidth = (constraints.maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;
              
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(width: cardWidth, child: _buildStatCard("First-Attempt Accuracy", firstAttemptAcc != null ? "${((firstAttemptAcc as num) * 100).toInt()}%" : "Insufficient data", Icons.check_circle_outline, AppColors.gentleGreen)),
                  SizedBox(width: cardWidth, child: _buildStatCard("Retry Rate", retryRate != null ? "${((retryRate as num) * 100).toInt()}%" : "Insufficient data", Icons.replay, AppColors.warmAmber)),
                  SizedBox(width: cardWidth, child: _buildStatCard("Mean Attempts", meanAttempts != null ? (meanAttempts as num).toStringAsFixed(1) : "Insufficient data", Icons.numbers, AppColors.softCoral)),
                  SizedBox(width: cardWidth, child: _buildStatCard("Median Response Time", medianLat != null ? "${((medianLat as num) / 1000).toStringAsFixed(1)} s" : "Insufficient data", Icons.timer, AppColors.calmBlue)),
                  SizedBox(width: cardWidth, child: _buildStatCard("Time to Correct", medianTimeToCorrect != null ? "${((medianTimeToCorrect as num) / 1000).toStringAsFixed(1)} s" : "Insufficient data", Icons.hourglass_bottom, AppColors.calmBlue)),
                  SizedBox(width: cardWidth, child: _buildStatCard("Behavioral Fatigue Indicator", fatigue != null ? (fatigue as num).toStringAsFixed(2) : "Insufficient data", Icons.battery_alert, AppColors.softCoral)),
                ],
              );
            },
          ),
          
          const SizedBox(height: 24),
          Text("Attempt Behavior", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 12),
          _buildAttemptBehaviorBar(firstAttemptAcc, retryRate),
          
          const SizedBox(height: 24),
          Text("Knowledge Component Performance", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 12),
          _buildHorizontalBar("Akshara Identity", kcPerformance['KC_AKSHARA_IDENTITY'], AppColors.calmBlue),
          _buildHorizontalBar("Phoneme–Grapheme", kcPerformance['KC_PHONEME_GRAPHEME'], AppColors.gentleGreen),
          _buildHorizontalBar("Word Recognition", kcPerformance['KC_WORD_RECOGNITION'], AppColors.warmAmber),
          _buildHorizontalBar("Spelling Sequence", kcPerformance['KC_SPELLING_SEQUENCE'], AppColors.softCoral),
          _buildHorizontalBar("Sentence Language", kcPerformance['KC_SENTENCE_LANGUAGE'], AppColors.calmBlue),
          _buildHorizontalBar("Reading Comprehension", kcPerformance['KC_READING_COMPREHENSION'], AppColors.gentleGreen),
          const SizedBox(height: 16),
          Text("Supportive Measure", style: AppTypography.heading(fontSize: 14)),
          const SizedBox(height: 8),
          _buildHorizontalBar("Visual Support", kcPerformance['KC_VISUAL_SUPPORT'], AppColors.warmAmber),
          _buildHorizontalBar("Letter Sequence Memory", kcPerformance['KC_ORTHOGRAPHIC_MEMORY'], AppColors.calmBlue),
          _buildHorizontalBar("Oral Reading", kcPerformance['KC_ORAL_READING_FLUENCY'], AppColors.calmBlue),
          
          const SizedBox(height: 24),
          Text("Observed Error Pattern", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 12),
          _buildErrorPattern(errors),
          
          const SizedBox(height: 32),
          Text("Performance Across Sessions", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 12),
          if (accTrend.length < 2 && latTrend.length < 2 && fatTrend.length < 2)
            const Text("Complete more sessions to view this trend.", style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary))
          else ...[
            if (accTrend.length >= 2) ...[
              TrendChart(title: "First-Attempt Accuracy", dataPoints: accTrend, labels: accTrendRaw.map((e) => e['session'].toString()).toList(), lineColor: AppColors.gentleGreen, minY: 0),
              const SizedBox(height: 24),
            ],
            if (latTrend.length >= 2) ...[
              TrendChart(title: "Median Response Time (s)", dataPoints: latTrend, labels: latTrendRaw.map((e) => e['session'].toString()).toList(), lineColor: AppColors.calmBlue, minY: 0),
              const SizedBox(height: 24),
            ],
            if (fatTrend.length >= 2) ...[
              TrendChart(title: "Behavioral Fatigue Indicator", dataPoints: fatTrend, labels: fatTrendRaw.map((e) => e['session'].toString()).toList(), lineColor: AppColors.softCoral),
            ],
          ]
        ],
      ),
    );
  }

  Widget _buildAttemptBehaviorBar(dynamic firstAttemptAcc, dynamic retryRate) => Column(children: [
    _buildHorizontalBar('First-attempt success', firstAttemptAcc, AppColors.gentleGreen),
    _buildHorizontalBar('Trials with retries', retryRate, AppColors.warmAmber),
    const Text('Separate rates with the same trial denominator; they are not normalized into a 100% stacked chart.'),
  ]);

  Widget _buildErrorPattern(Map<String, dynamic> errors) {
    if (errors.isEmpty) {
      return const Text("No error-pattern data available yet.", style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary));
    }
    
    // Check if everything is null
    bool hasData = false;
    for (var key in ['visual_confusion', 'phonological_confusion', 'sequence_error', 'unknown_error']) {
      if (errors[key] != null) hasData = true;
    }
    if (!hasData) {
      return const Text("No error-pattern data available yet.", style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary));
    }

    double visual = (errors['visual_confusion'] as num?)?.toDouble() ?? 0.0;
    double phono = (errors['phonological_confusion'] as num?)?.toDouble() ?? 0.0;
    double seq = (errors['sequence_error'] as num?)?.toDouble() ?? 0.0;
    double unk = (errors['unknown_error'] as num?)?.toDouble() ?? 0.0;
    
    if (visual == 0 && phono == 0 && seq == 0 && unk == 0) {
      return const Text("No first-attempt errors observed in this session.", style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.gentleGreen));
    }
    
    return Column(
      children: [
        _buildHorizontalBar("Visual Confusion", errors['visual_confusion'], AppColors.calmBlue),
        _buildHorizontalBar("Phonological Confusion", errors['phonological_confusion'], AppColors.gentleGreen),
        _buildHorizontalBar("Sequence Error", errors['sequence_error'], AppColors.warmAmber),
        _buildHorizontalBar("Unknown / Unclassified", errors['unknown_error'], AppColors.softCoral),
      ],
    );
  }

  // ==========================================
  // 3. C2 — SPEECH & SINHALA INTERACTION
  // ==========================================
  Widget _buildC2SpeechTab() {
    final latest = _c2Speech?['latest'] ?? {};
    final trends = _c2Speech?['trends'] ?? {};
    final latTrendRaw = trends['latency'] as List<dynamic>? ?? [];
    final latTrend = latTrendRaw.map((e) => (e['value'] as num?)?.toDouble()).toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModelInfo(_c2Speech ?? {}),
          const SizedBox(height: 16),
          
          // Hero Card: Combined Reading Evidence
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.calmBlue, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Text("READING & SPEECH EVENT", style: AppTypography.heading(fontSize: 18, color: AppColors.calmBlue))),
                const Divider(height: 32, thickness: 2),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("STT EVIDENCE", style: AppTypography.caption(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          _buildEvidenceRow("WER", metricText(latest['wer'])),
                          _buildEvidenceRow("Confidence", metricText(latest['stt_confidence'], scale: 100, suffix: '%')),
                        ],
                      )
                    ),
                    Container(width: 1, height: 80, color: AppColors.borderLight, margin: const EdgeInsets.symmetric(horizontal: 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("ACOUSTIC EVIDENCE", style: AppTypography.caption(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          _buildEvidenceRow("Latency", metricText(latest['acoustic_latency_ms'], scale: .001, suffix: ' s')),
                          _buildEvidenceRow("Silence", metricText(latest['silence_ratio'])),
                          _buildEvidenceRow("Peak Δ", metricText(latest['peak_delta'])),
                          _buildEvidenceRow("Quality", "${latest['recording_quality'] ?? 'Unknown'}"),
                        ],
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(child: const Icon(Icons.arrow_downward, color: AppColors.textHint)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.gentleGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Text("Reading Evidence", style: AppTypography.caption(color: AppColors.textSecondary)),
                      Text(latest['measurement_status']?.toString() ?? "Unavailable", style: AppTypography.heading(fontSize: 20, color: AppColors.gentleGreen)),
                    ],
                  ),
                )
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          _buildEvidenceRow('Thresholded pauses (200–3000 ms)', metricText(latest['pause_count'], decimals: 0)),
          _buildEvidenceRow('Mean detected pause', metricText(latest['mean_pause_duration_ms'], suffix: ' ms')),
          _buildEvidenceRow('Detected pause ratio', metricText(latest['pause_ratio'])),
          _buildEvidenceRow('Active-span duration', metricText(latest['speech_duration_ms'], suffix: ' ms')),
          const Text('Thresholded acoustic intervals, not validated linguistic pause or syllable annotations.'),
          Text("Expected vs Recognized", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(color: AppColors.cardSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Expected')),
                DataColumn(label: Text('Recognized')),
                DataColumn(label: Text('Result')),
              ],
              rows: [
                DataRow(cells: [
                  DataCell(Text(latest['expected_text']?.toString() ?? '-')), 
                  DataCell(Text(latest['transcription']?.toString() ?? '-')), 
                  DataCell(Text((latest['wer'] ?? 1.0) == 0.0 ? '✓' : '⚠', style: TextStyle(color: (latest['wer'] ?? 1.0) == 0.0 ? Colors.green : Colors.orange)))
                ]),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStatCard("Current Jitter", metricText(latest['jitter']), Icons.multiline_chart, AppColors.calmBlue)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard("Current Shimmer", metricText(latest['shimmer']), Icons.waves, AppColors.calmBlue)),
            ],
          ),
          
          const SizedBox(height: 24),
          if (latTrend.isNotEmpty) ...[
            TrendChart(title: "Acoustic Latency (ms)", dataPoints: latTrend, lineColor: AppColors.warmAmber, minY: 0),
          ],
          const SizedBox(height: 24),
          if (trends['wer'] != null) ...[
            TrendChart(title: "Word Error Rate (WER)", dataPoints: (trends['wer'] as List).map((e) => (e['value'] as num?)?.toDouble()).toList(), lineColor: AppColors.softCoral, minY: 0),
          ]
        ],
      ),
    );
  }

  // ==========================================
  // 4. C3 — LEARNER PROFILE & XAI
  // ==========================================
  Widget _buildC3ProfileTab() {
    final probs = _c3Profile?['probabilities'] ?? {};
    final shap = _c3Profile?['shap_explanations'] as List<dynamic>? ?? [];
    final pattern = _c3Profile?['primary_pattern'] ?? 'Unknown';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModelInfo(_c3Profile ?? {}),
          const SizedBox(height: 16),
          Text("Learning Pattern Probabilities", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 12),
          _buildHorizontalBar("Typical", probs['Typical'], AppColors.calmBlue),
          _buildHorizontalBar("Visual-Orthographic", probs['Visual-Orthographic'], AppColors.calmBlue),
          _buildHorizontalBar("Phonological", probs['Phonological'], pattern == 'Phonological' ? AppColors.softCoral : AppColors.calmBlue),
          _buildHorizontalBar("Combined", probs['Combined'], pattern == 'Combined' ? AppColors.softCoral : AppColors.calmBlue),
          
          const SizedBox(height: 32),
          Text("Model Evidence (SHAP)", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 12),
          ...shap.map((s) {
            final featureName = s['feature'] ?? '';
            final impact = (s['contribution'] as num?)?.toDouble() ?? 0.0;
            final direction = s['direction'] ?? '';
            final obs = s['observed_value'];
            
            String title = featureName;
            if (obs != null) {
              title += " (Observed: $obs $direction)";
            }
            
            return ListTile(contentPadding: EdgeInsets.zero, title: Text(title),
              subtitle: Text(impact >= 0 ? 'Increases explained model score (raw margin)' : 'Decreases explained model score (raw margin)'),
              trailing: Text('${impact >= 0 ? '+' : ''}${impact.toStringAsFixed(3)}'));
          }).toList(),
          
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          if (_c3Profile?['llm_summary'] != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.calmBlue.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.calmBlue),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.calmBlue, size: 20),
                      const SizedBox(width: 8),
                      Text("Experimental Model Summary", style: AppTypography.heading(fontSize: 16, color: AppColors.calmBlue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_c3Profile!['llm_summary'], style: AppTypography.body(fontSize: 14)),
                  const SizedBox(height: 16),
                  Text("Recommendations", style: AppTypography.heading(fontSize: 14, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(_c3Profile!['llm_recommendations'] ?? '', style: AppTypography.body(fontSize: 14)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.cardSurface, border: Border.all(color: AppColors.borderLight), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Interpretation", style: AppTypography.caption(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    "No generated interpretation is available. SHAP describes model behavior; it does not establish a cause or a learning difficulty.",
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }

  // ==========================================
  // 5. C4 — ADAPTIVE LEARNING
  // ==========================================
  Widget _buildC4AdaptiveTab() {
    final kcs = _c4Adaptive?['knowledge_components'] as List<dynamic>? ?? [];
    final history = _c4Adaptive?['history'] as List<dynamic>? ?? [];
    final theta = _c4Adaptive?['theta'];
    final thetaSe = _c4Adaptive?['theta_se'];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModelInfo(_c4Adaptive ?? {}),
          const SizedBox(height: 16),
          
          // Current Decision Card
          if (history.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.cardSurface, border: Border.all(color: AppColors.calmBlue, width: 2), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Text("LATEST RECOMMENDATION (NOT APPLIED IN GAME)", style: AppTypography.heading(fontSize: 16, color: AppColors.calmBlue))),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Difficulty", style: AppTypography.caption()),
                          Text("${metricText(history.last['previous_difficulty'])} → ${metricText(history.last['selected_difficulty'])}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Scaffold", style: AppTypography.caption()),
                          Text("Level ${history.last['scaffold_level'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text("Next Activity", style: AppTypography.caption()),
                  Text("${history.last['next_activity'] ?? 'Unknown'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text("Reason", style: AppTypography.caption()),
                  Text("${history.last['reason'] ?? 'N/A'}", style: const TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          Text("Estimated KC Mastery (BKT)", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 12),
          ...kcs.map((kc) => _buildHorizontalBar(kc['name'] ?? '', (kc['mastery'] as num).toDouble(), AppColors.gentleGreen)).toList(),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard("IRT Ability (θ)", metricText(theta), Icons.person, AppColors.calmBlue)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard("IRT SE", metricText(thetaSe), Icons.error_outline, AppColors.textSecondary)),
            ],
          ),
          
          const SizedBox(height: 32),
          Text("Adaptive Decision Timeline", style: AppTypography.heading(fontSize: 18)),
          const SizedBox(height: 16),
          
          // Timeline
          ...history.asMap().entries.map((entry) {
            int idx = entry.key;
            var dec = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.borderLight)),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: AppColors.calmBlue, shape: BoxShape.circle),
                    child: Center(child: Text("${idx + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Mastery ${metricText(dec['mastery_after'])}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("Difficulty ${metricText(dec['selected_difficulty'])}", style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if ((dec['scaffold_level'] ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.warmAmber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text("Scaffold ON", style: TextStyle(color: AppColors.warmAmber, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED WIDGETS
  // ==========================================
  Widget _buildAvailabilityBadge(String title, bool isAvailable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAvailable ? AppColors.gentleGreen.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        border: Border.all(color: isAvailable ? AppColors.gentleGreen : Colors.grey),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAvailable ? Icons.check_circle : Icons.cancel, size: 14, color: isAvailable ? AppColors.gentleGreen : Colors.grey),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: isAvailable ? AppColors.gentleGreen : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEvidenceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textDark)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHorizontalBar(String label, dynamic rawValue, Color color, {String prefix = ""}) {
    final value = rawValue != null ? (rawValue as num).toDouble() : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Container(height: 16, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(4))),
                if (value != null)
                  FractionallySizedBox(
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                  ),
              ],
            ),
          ),
          SizedBox(width: 40, child: Text(value != null ? " $prefix${(value * 100).toInt()}%" : "N/A", textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: value != null ? Colors.black : Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, dynamic icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon is IconData ? Icon(icon, color: color, size: 20) : FaIcon(icon as FaIconData, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.heading(fontSize: 16, color: AppColors.textPrimary)),
          Text(label, style: AppTypography.caption(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildModelInfo(Map<String, dynamic> data) {
    if (data['model_version'] == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.borderLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(FontAwesomeIcons.microchip, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            "Model: ${data['model_version']} | Features: ${data['feature_version']}",
            style: AppTypography.caption(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CHILD PROFILE DETAILS CARD
  // ==========================================
  Widget _buildChildProfileCard(Map<String, dynamic> student) {
    final firstName = _overview?['first_name'] ?? student['first_name'] ?? _overview?['student_name'] ?? student['student_name'] ?? 'Student';
    final lastName = _overview?['last_name'] ?? student['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final grade = _overview?['grade'] ?? student['grade'] ?? 'Grade 1';
    final rawAge = _overview?['age'] ?? student['age'];
    final age = rawAge != null ? "$rawAge Years" : "6 Years";
    final studentId = student['student_id'] ?? student['id'] ?? student['_id'] ?? _overview?['student_id'] ?? 'N/A';
    final parentName = _overview?['parent_name'] ?? student['consent_parent_name'] ?? student['parent_name'] ?? 'Parent / Guardian';
    final consentDate = student['consent_date'] ?? 'Registered';
    final avatar = AvatarUtils.getCorrectedAvatarPath(
        (_overview?['avatar_url'] ?? student['avatar_url']) as String?, 
        'assets/images/characters/human/human_student_1.png');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.calmBlue.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.calmBlue.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: AssetImage(avatar),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: AppTypography.heading(fontSize: 20, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$grade • Age: $age',
                      style: AppTypography.body(fontSize: 14, color: AppColors.calmBlue),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.gentleGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gentleGreen.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.verified_user_rounded, color: AppColors.gentleGreen, size: 16),
                    SizedBox(width: 4),
                    Text('Active Student', style: TextStyle(color: AppColors.gentleGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: AppColors.borderLight),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildDetailChip(Icons.badge_outlined, "Student ID", studentId.toString()),
              _buildDetailChip(Icons.family_restroom_rounded, "Parent / Guardian", parentName.toString()),
              _buildDetailChip(Icons.calendar_today_rounded, "Consent Date", consentDate.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('$label: ', style: AppTypography.caption(color: AppColors.textSecondary)),
        Flexible(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textDark), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ==========================================
  // CLINICAL REPORT EXPORT CARD (ABOVE PARENT SECTION)
  // ==========================================
  Widget _buildClinicalReportExportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.calmBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.calmBlue.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: AppColors.calmBlue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Clinical Therapist Summary Report",
                  style: AppTypography.heading(fontSize: 16, color: AppColors.textPrimary),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text("Share Report (PDF)"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.calmBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.calmBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: AppColors.calmBlue, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Note: The Clinical Report includes behavioral analytics, speech interaction metrics, and AI learner profile data. Parent Questionnaire responses below are managed separately and exported as individual medical review PDFs.",
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAssessmentReviewed(String categoryKey, bool currentStatus) async {
    final studentId = widget.student['student_id']?.toString() ?? widget.student['id']?.toString() ?? widget.student['_id']?.toString();
    if (studentId == null) return;
    try {
      final newStatus = !currentStatus;
      setState(() {
        final revMap = Map<String, dynamic>.from(_overview?['reviewed_assessments'] ?? {});
        revMap[categoryKey] = newStatus;
        if (_overview != null) {
          _overview!['reviewed_assessments'] = revMap;
        }
      });
      await _dashboardService.markAssessmentReviewed(studentId, categoryKey, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'Assessment marked as reviewed!' : 'Assessment review status updated.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update review status: $e'), backgroundColor: Colors.red),
      );
      _loadAllData();
    }
  }

  // ==========================================
  // PARENT ASSESSMENT ANSWERS SECTION (ALL 4 ASSESSMENTS)
  // ==========================================
  Widget _buildAssessmentAnswersSection(Map<String, dynamic> student) {
    final basicResults = (_overview?['assessment_results'] as List?)?.cast<bool>() ?? 
                         (student['assessment_results'] as List?)?.cast<bool>() ?? [];

    final compMap = (_overview?['comprehensive_assessment_results'] as Map?)?.cast<String, dynamic>() ?? 
                    (student['comprehensive_assessment_results'] as Map?)?.cast<String, dynamic>() ?? {};

    final readingResults = (compMap['reading'] as List?)?.cast<bool>() ?? [];
    final writingResults = (compMap['writing'] as List?)?.cast<bool>() ?? [];
    final otherResults = (compMap['other'] as List?)?.cast<bool>() ?? [];

    final totalCompleted = (basicResults.isNotEmpty ? 1 : 0) +
        (readingResults.isNotEmpty ? 1 : 0) +
        (writingResults.isNotEmpty ? 1 : 0) +
        (otherResults.isNotEmpty ? 1 : 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("දෙමාපිය දැනුවත් කිරීමේ ප්‍රශ්නාවලිය", style: AppTypography.sinhala(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                "Parent Awareness Questionnaires ($totalCompleted/4 Completed) — Tap to Expand Details",
                style: AppTypography.caption(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Category Filter Chips for All 4 Assessments
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('all', 'සියල්ල (All 4)', totalCompleted),
                const SizedBox(width: 8),
                _buildCategoryChip('basic', '1. මූලික පරීක්ෂණය (14)', basicResults.isNotEmpty ? 1 : 0),
                const SizedBox(width: 8),
                _buildCategoryChip('reading', '2. කියවීම හා දෘශ්‍ය (10)', readingResults.isNotEmpty ? 1 : 0),
                const SizedBox(width: 8),
                _buildCategoryChip('writing', '3. ලිවීම (6)', writingResults.isNotEmpty ? 1 : 0),
                const SizedBox(width: 8),
                _buildCategoryChip('other', '4. වෙනත් (12)', otherResults.isNotEmpty ? 1 : 0),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Render Collapsible Cards for Selected Category or All 4 Categories
          if (_selectedAssessmentCategory == 'all' || _selectedAssessmentCategory == 'basic')
            _buildCollapsibleAssessmentCard(
              student: student,
              categoryKey: 'basic',
              titleSi: "1. මූලික ඩිස්ලෙක්සියා පරීක්ෂණය (14)",
              titleEn: "1. Basic Dyslexia Screening",
              questions: ComprehensiveAssessmentData.basicAssessment,
              answers: basicResults,
            ),

          if (_selectedAssessmentCategory == 'all' || _selectedAssessmentCategory == 'reading')
            _buildCollapsibleAssessmentCard(
              student: student,
              categoryKey: 'reading',
              titleSi: "2. කියවීම හා දෘශ්‍ය සංජානන සම්බන්ධ අපහසුතා (10)",
              titleEn: "2. Reading & Visual Perception",
              questions: ComprehensiveAssessmentData.readingAssessment,
              answers: readingResults,
            ),

          if (_selectedAssessmentCategory == 'all' || _selectedAssessmentCategory == 'writing')
            _buildCollapsibleAssessmentCard(
              student: student,
              categoryKey: 'writing',
              titleSi: "3. ලිවීම සම්බන්ධ අපහසුතා (6)",
              titleEn: "3. Writing Difficulties",
              questions: ComprehensiveAssessmentData.writingAssessment,
              answers: writingResults,
            ),

          if (_selectedAssessmentCategory == 'all' || _selectedAssessmentCategory == 'other')
            _buildCollapsibleAssessmentCard(
              student: student,
              categoryKey: 'other',
              titleSi: "4. වෙනත් සම්බන්ධ අපහසුතා (12)",
              titleEn: "4. Other Associated / Health & Speech",
              questions: ComprehensiveAssessmentData.otherAssessment,
              answers: otherResults,
            ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleAssessmentCard({
    required Map<String, dynamic> student,
    required String categoryKey,
    required String titleSi,
    required String titleEn,
    required List<ComprehensiveQuestion> questions,
    required List<bool> answers,
  }) {
    final isCompleted = answers.isNotEmpty;
    final revMap = (_overview?['reviewed_assessments'] as Map?)?.cast<String, dynamic>() ?? 
                   (student['reviewed_assessments'] as Map?)?.cast<String, dynamic>() ?? {};
    final isReviewed = revMap[categoryKey] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCompleted ? AppColors.calmBlue.withValues(alpha: 0.3) : AppColors.borderLight, width: 1.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleSi, style: AppTypography.sinhala(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(titleEn, style: AppTypography.caption(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.gentleGreen.withValues(alpha: 0.15) : AppColors.warmAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isCompleted ? AppColors.gentleGreen : AppColors.warmAmber),
                ),
                child: Text(
                  isCompleted ? "Finished ✓" : "Pending",
                  style: TextStyle(
                    color: isCompleted ? AppColors.gentleGreen : AppColors.warmAmber,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (isCompleted) ...[
                  InkWell(
                    onTap: () => _toggleAssessmentReviewed(categoryKey, isReviewed),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isReviewed ? AppColors.calmBlue.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isReviewed ? AppColors.calmBlue : AppColors.textHint),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isReviewed ? Icons.check_circle_rounded : Icons.outlined_flag_rounded,
                              size: 13, color: isReviewed ? AppColors.calmBlue : AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            isReviewed ? "Reviewed ✓" : "Mark as Reviewed",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isReviewed ? AppColors.calmBlue : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const Text("Not Submitted", style: TextStyle(fontSize: 11, color: AppColors.textHint, fontStyle: FontStyle.italic)),
                ],
                InkWell(
                  onTap: () => _exportAssessmentMedicalReport(student, categoryKey),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.calmBlue.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.picture_as_pdf_rounded, size: 13, color: AppColors.calmBlue),
                        SizedBox(width: 4),
                        Text(
                          "Export PDF",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.calmBlue),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 16),
            _buildAssessmentCategoryTable(
              titleSi: titleSi,
              titleEn: titleEn,
              questions: questions,
              answers: answers,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String categoryKey, String label, int statusCount) {
    final isSelected = _selectedAssessmentCategory == categoryKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
      selected: isSelected,
      selectedColor: AppColors.calmBlue.withValues(alpha: 0.2),
      backgroundColor: AppColors.cream,
      side: BorderSide(color: isSelected ? AppColors.calmBlue : AppColors.borderLight, width: 1.5),
      onSelected: (bool selected) {
        if (selected) {
          setState(() => _selectedAssessmentCategory = categoryKey);
        }
      },
    );
  }

  Widget _buildAssessmentCategoryTable({
    required String titleSi,
    required String titleEn,
    required List<ComprehensiveQuestion> questions,
    required List<bool> answers,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header Title
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.calmBlue.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            border: Border.all(color: AppColors.calmBlue.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SelectableText("$titleSi ($titleEn)", style: AppTypography.sinhala(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.calmBlueDark)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: answers.isNotEmpty ? AppColors.gentleGreen : Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  answers.isNotEmpty ? "${answers.length}/${questions.length} Saved" : "Not Done",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Table Header
        Table(
          border: TableBorder.all(color: AppColors.borderLight),
          columnWidths: const {
            0: FixedColumnWidth(40),
            1: FlexColumnWidth(4),
            2: FixedColumnWidth(65),
            3: FixedColumnWidth(65),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
              children: const [
                TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Padding(padding: EdgeInsets.all(6), child: Text("අංකය\n(No)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)))),
                TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Padding(padding: EdgeInsets.all(6), child: Text("ප්‍රශ්නය (Question)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Padding(padding: EdgeInsets.all(6), child: Text("ඔව්\n(Yes)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.softCoral)))),
                TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Padding(padding: EdgeInsets.all(6), child: Text("නැත\n(No)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.gentleGreen)))),
              ],
            ),
            for (int i = 0; i < questions.length; i++)
              _buildTableRowItem(
                index: i + 1,
                question: questions[i],
                answer: i < answers.length ? answers[i] : null,
              ),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRowItem({
    required int index,
    required ComprehensiveQuestion question,
    required bool? answer,
  }) {
    return TableRow(
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: SelectableText("$index", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(question.textSi, style: AppTypography.sinhala(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                SelectableText(question.textEn, style: AppTypography.caption(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        // Column 1: ඔව් (Yes)
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Center(
            child: answer == true
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFFFF3ED), shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.softCoral, size: 20),
                  )
                : const Icon(Icons.check_box_outline_blank_rounded, color: Colors.black26, size: 18),
          ),
        ),
        // Column 2: නැත (No)
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Center(
            child: answer == false
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFEFF9F0), shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.gentleGreen, size: 20),
                  )
                : const Icon(Icons.check_box_outline_blank_rounded, color: Colors.black26, size: 18),
          ),
        ),
      ],
    );
  }

  Future<void> _exportAssessmentMedicalReport(Map<String, dynamic> student, String categoryKey) async {
    final firstName = student['first_name'] ?? 'Student';
    final lastName = student['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final grade = student['grade'] ?? 'Grade 1';
    final age = student['age'] != null ? "${student['age']} Years" : "6 Years";
    final studentId = student['student_id'] ?? student['id'] ?? student['_id'] ?? 'N/A';
    final parentName = student['consent_parent_name'] ?? student['parent_name'] ?? 'Parent / Guardian';

    final basicResults = (_overview?['assessment_results'] as List?)?.cast<bool>() ?? 
                         (student['assessment_results'] as List?)?.cast<bool>() ?? [];

    final compMap = (_overview?['comprehensive_assessment_results'] as Map?)?.cast<String, dynamic>() ?? 
                    (student['comprehensive_assessment_results'] as Map?)?.cast<String, dynamic>() ?? {};

    final readingResults = (compMap['reading'] as List?)?.cast<bool>() ?? [];
    final writingResults = (compMap['writing'] as List?)?.cast<bool>() ?? [];
    final otherResults = (compMap['other'] as List?)?.cast<bool>() ?? [];

    final StringBuffer buffer = StringBuffer();
    buffer.writeln("==========================================================================================");
    buffer.writeln("                             දෙමාපිය දැනුවත් කිරීමේ ප්‍රශ්නාවලිය");
    buffer.writeln("   Parent Awareness Questionnaire — Basic Dyslexia Screening (for medical review)");
    buffer.writeln("==========================================================================================");
    buffer.writeln("දරුවාගේ නම (Child Name): $fullName | වයස (Age): $age ($grade) | දිනය (Date): ${DateTime.now().toString().split(' ')[0]}");
    buffer.writeln("Student ID: $studentId | Parent/Guardian: $parentName");
    buffer.writeln("==========================================================================================");
    buffer.writeln("උපදෙස්: කරුණාකර පහත එක් එක් ප්‍රශ්නය සඳහා දරුවා පිළිබඳ ඔබේ නිරීක්ෂණයට අනුව");
    buffer.writeln("\"ඔව්\", \"නැත\" හෝ \"හඳුනාගත නොහැක\" යන කොටුවලින් එකක් ලකුණු කරන්න.");
    buffer.writeln("------------------------------------------------------------------------------------------\n");

    void formatCategoryTable(String sectionTitle, List<ComprehensiveQuestion> questions, List<bool> answers) {
      buffer.writeln("------------------------------------------------------------------------------------------");
      buffer.writeln(sectionTitle);
      buffer.writeln("------------------------------------------------------------------------------------------");
      buffer.writeln("| අංකය | ප්‍රශ්නය                                               | ඔව්(Yes) | නැත(No) |");
      buffer.writeln("+------+-------------------------------------------------------+----------+---------+");

      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        final bool? val = i < answers.length ? answers[i] : null;
        final String colYes = val == true ? "[ X ]" : "[   ]";
        final String colNo = val == false ? "[ X ]" : "[   ]";

        final numStr = (i + 1).toString().padLeft(2, '0');
        buffer.writeln("|  $numStr  | ${q.textSi}");
        buffer.writeln("|      | (${q.textEn})".padRight(63) + "|  $colYes  |  $colNo  |");
        buffer.writeln("+------+-------------------------------------------------------+----------+---------+");
      }
      buffer.writeln();
    }

    if (categoryKey == 'all' || categoryKey == 'basic') {
      formatCategoryTable("1. මූලික ඩිස්ලෙක්සියා පරීක්ෂණය (Basic Dyslexia Screening — 14 Questions)", ComprehensiveAssessmentData.basicAssessment, basicResults);
    }
    if (categoryKey == 'all' || categoryKey == 'reading') {
      formatCategoryTable("2. කියවීම හා දෘශ්‍ය සංජානන සම්බන්ධ අපහසුතා (Reading & Visual Perception — 10 Questions)", ComprehensiveAssessmentData.readingAssessment, readingResults);
    }
    if (categoryKey == 'all' || categoryKey == 'writing') {
      formatCategoryTable("3. ලිවීම සම්බන්ධ අපහසුතා (Writing Difficulties — 6 Questions)", ComprehensiveAssessmentData.writingAssessment, writingResults);
    }
    if (categoryKey == 'all' || categoryKey == 'other') {
      formatCategoryTable("4. වෙනත් සම්බන්ධ අපහසුතා (Other Associated / Health & Speech — 12 Questions)", ComprehensiveAssessmentData.otherAssessment, otherResults);
    }

    buffer.writeln("------------------------------------------------------------------------------------------");
    buffer.writeln("වෛද්‍ය නිරීක්ෂණ / අදහස් (Doctor Notes & Medical Observations):");
    buffer.writeln("------------------------------------------------------------------------------------------");
    buffer.writeln("1. ____________________________________________________________________________________");
    buffer.writeln("2. ____________________________________________________________________________________");
    buffer.writeln("3. ____________________________________________________________________________________\n");

    try {
      final reportText = buffer.toString();
      final XFile file = XFile.fromData(
        Uint8List.fromList(reportText.codeUnits),
        mimeType: 'text/plain',
        name: '${fullName.replaceAll(' ', '_')}_Medical_Questionnaire.txt',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          text: 'Parent Awareness Questionnaire (Medical Review Report) for $fullName',
          subject: 'Medical Questionnaire - $fullName',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting medical questionnaire: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
