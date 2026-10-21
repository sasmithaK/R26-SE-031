import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/starter_baseline_models.dart';
import '../services/starter_baseline_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_utils.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/floating_shapes.dart';
import '../widgets/gradient_button.dart';
import '../widgets/speech_bubble.dart';
import 'dashboard_screen.dart';

enum _StarterStage { loading, intro, tutorial, tasks, complete }

class StarterLearningProfileScreen extends StatefulWidget {
  const StarterLearningProfileScreen({
    super.key,
    required this.studentData,
    this.initialStatus,
    this.repository,
  });

  final Map<String, dynamic> studentData;
  final StarterBaselineStatus? initialStatus;
  final StarterBaselineRepository? repository;

  @override
  State<StarterLearningProfileScreen> createState() =>
      _StarterLearningProfileScreenState();
}

class _StarterLearningProfileScreenState
    extends State<StarterLearningProfileScreen>
    with TickerProviderStateMixin {
  late final StarterBaselineRepository _repository;
  _StarterStage _stage = _StarterStage.loading;
  StarterBaselineStatus? _status;
  int _tutorialIndex = 0;
  int _tutorialAttemptCount = 0;
  bool _tutorialAdvancing = false;
  int _taskIndex = 0;
  final List<String> _selectedIds = [];
  String? _tutorialMessage;
  bool _submitting = false;
  bool _audioPreparing = false;
  DateTime _taskStartedAt = DateTime.now();
  DateTime? _firstTouchAt;
  int _audioReplayCount = 0;
  int _touchCount = 0;
  Map<String, dynamic>? _pendingResponse;

  // Animation controllers for enhanced transitions
  late AnimationController _stageTransitionController;
  late Animation<double> _stageTransitionAnimation;
  late AnimationController _celebrationController;
  late Animation<double> _celebrationScale;

  String get _studentId => widget.studentData['id']?.toString() ?? '';
  String get _studentName =>
      widget.studentData['first_name']?.toString() ?? 'පුංචි යාළුවා';
  String get _studentAvatarPath => AvatarUtils.getCorrectedAvatarPath(
    widget.studentData['avatar_url']?.toString(),
    'assets/images/characters/human/human_student_1.png',
  );

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StarterBaselineService();

    _stageTransitionController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _stageTransitionAnimation = CurvedAnimation(
      parent: _stageTransitionController,
      curve: Curves.easeOutCubic,
    );
    _stageTransitionController.forward();

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _celebrationScale = CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.elasticOut,
    );

    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(TtsService().stop());
    _stageTransitionController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final status =
          widget.initialStatus ?? await _repository.getStatus(_studentId);
      if (!mounted) return;
      setState(() {
        _status = status;
        _taskIndex = status.nextItemIndex.clamp(0, starterBaselineTasks.length);
        if (status.status == 'completed' || status.status == 'insufficient') {
          _stage = _StarterStage.complete;
          _celebrationController.forward();
        } else {
          _stage = _StarterStage.intro;
        }
      });
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'පුංචි ඉගෙනුම් පියවර දැන් විවෘත කරන්න බැහැ. නැවත උත්සාහ කරන්න.',
      );
      await Navigator.maybePop(context);
    }
  }

  Future<void> _animateStageTransition() async {
    _stageTransitionController.reset();
    await _stageTransitionController.forward();
  }

  Future<void> _startOrResume() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      var status = _status;
      if (status?.status != 'in_progress') {
        final sessionId = 'starter-$_studentId-${const Uuid().v4()}';
        status = await _repository.start(_studentId, sessionId);
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _taskIndex = status!.nextItemIndex.clamp(
          0,
          starterBaselineTasks.length,
        );
        _submitting = false;
        _stage = _taskIndex > 0 ? _StarterStage.tasks : _StarterStage.tutorial;
      });
      unawaited(_animateStageTransition());
      if (_stage == _StarterStage.tasks) _prepareCurrentTask();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage('සම්බන්ධතාවයේ ගැටලුවක් තිබෙනවා. නැවත උත්සාහ කරමු.');
    }
  }

  Future<void> _handleTutorialChoice(String id) async {
    if (_tutorialIndex == 0) {
      if (_tutorialAdvancing) return;
      setState(() {
        _selectedIds
          ..clear()
          ..add(id);
        _tutorialMessage = null;
        _tutorialAdvancing = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted || _tutorialIndex != 0 || !_selectedIds.contains(id)) return;
      setState(() => _tutorialAdvancing = false);
      _finishTutorial();
      return;
    }
    setState(() {
      _tutorialMessage = null;
      final nextSelection = updateStarterSequenceSelection(
        currentSelection: _selectedIds,
        tappedId: id,
        requiredCount: 2,
      );
      _selectedIds
        ..clear()
        ..addAll(nextSelection);
    });
  }

  void _finishTutorial() {
    final requiredSelectionCount = _tutorialIndex == 0 ? 1 : 2;
    if (_selectedIds.length != requiredSelectionCount) {
      setState(() {
        _tutorialMessage = _tutorialIndex == 0
            ? 'තරුවක් තෝරලා ඉදිරියට යමු.'
            : 'වචන දෙකම පිළිවෙළට තෝරමු.';
      });
      return;
    }

    final isCorrect = _tutorialIndex == 0
        ? _selectedIds.single == 'blue_star'
        : _selectedIds.join('|') == 'ගස|උසයි';
    final nextAttemptCount = _tutorialAttemptCount + 1;

    // Practice is intentionally unscored. Give one gentle retry, then move on
    // after the second attempt so a young learner is never trapped here.
    if (!isCorrect && nextAttemptCount < 2) {
      setState(() {
        _tutorialAttemptCount = nextAttemptCount;
        _selectedIds.clear();
        _tutorialMessage = _tutorialIndex == 0
            ? 'තවත් වරක් හොඳින් බලලා තෝරමු.'
            : 'තවත් වරක් පිළිවෙළට තෝරමු.';
      });
      return;
    }

    if (_tutorialIndex == 0) {
      setState(() {
        _tutorialIndex = 1;
        _tutorialAttemptCount = 0;
        _tutorialAdvancing = false;
        _selectedIds.clear();
        _tutorialMessage = null;
      });
      return;
    }

    setState(() {
      _stage = _StarterStage.tasks;
      _tutorialAttemptCount = 0;
      _selectedIds.clear();
      _tutorialMessage = null;
    });
    unawaited(_animateStageTransition());
    _prepareCurrentTask();
  }

  void _prepareCurrentTask() {
    if (_taskIndex >= starterBaselineTasks.length) {
      setState(() => _stage = _StarterStage.complete);
      _celebrationController.forward();
      return;
    }
    final task = starterBaselineTasks[_taskIndex];
    setState(() {
      _selectedIds.clear();
      _firstTouchAt = null;
      _audioReplayCount = 0;
      _touchCount = 0;
      _pendingResponse = null;
      _audioPreparing = task.hasAudio;
      _taskStartedAt = DateTime.now();
    });
    unawaited(_animateStageTransition());
    if (task.hasAudio) {
      unawaited(_playInitialAudio(task));
    }
  }

  Future<void> _playInitialAudio(StarterBaselineTask task) async {
    await TtsService().speak(
      task.spokenPrompt ?? task.prompt,
      folder: 'starter_profile',
      waitUntilComplete: true,
    );
    if (!mounted || _taskIndex >= starterBaselineTasks.length) return;
    if (starterBaselineTasks[_taskIndex].itemId != task.itemId) return;
    setState(() {
      _audioPreparing = false;
      _taskStartedAt = DateTime.now();
    });
  }

  Future<void> _replayAudio() async {
    if (_audioPreparing || _submitting) return;
    final task = starterBaselineTasks[_taskIndex];
    setState(() => _audioReplayCount += 1);
    await TtsService().speak(
      task.spokenPrompt ?? task.prompt,
      folder: 'starter_profile',
    );
  }

  void _selectBaselineChoice(String id) {
    if (_audioPreparing || _submitting) return;
    final task = starterBaselineTasks[_taskIndex];
    final now = DateTime.now();
    setState(() {
      _firstTouchAt ??= now;
      _touchCount += 1;
      if (task.isSequence) {
        final nextSelection = updateStarterSequenceSelection(
          currentSelection: _selectedIds,
          tappedId: id,
          requiredCount: task.correctAnswerIds.length,
        );
        _selectedIds
          ..clear()
          ..addAll(nextSelection);
      } else {
        _selectedIds
          ..clear()
          ..add(id);
      }
    });
  }

  Future<void> _submitCurrent({bool skipped = false}) async {
    if (_submitting || (!skipped && _selectedIds.isEmpty)) return;
    final task = starterBaselineTasks[_taskIndex];
    final presentedChoices = orderedStarterChoices(
      task,
      _status?.sessionId ?? _studentId,
    );
    final now = DateTime.now();
    final firstTouch = _firstTouchAt ?? now;
    final sessionId = _status?.sessionId;
    if (sessionId == null) return;
    setState(() => _submitting = true);
    try {
      _pendingResponse ??= {
        'event_id': '$sessionId:${task.itemId}:${now.microsecondsSinceEpoch}',
        'session_id': sessionId,
        'item_id': task.itemId,
        'selected_answer_ids': skipped
            ? <String>[]
            : List<String>.from(_selectedIds),
        'presented_option_ids': presentedChoices
            .map((choice) => choice.id)
            .toList(),
        'response_status': skipped ? 'skipped' : 'answered',
        'first_touch_latency_ms': firstTouch
            .difference(_taskStartedAt)
            .inMilliseconds
            .clamp(0, 300000),
        'total_latency_ms': now
            .difference(_taskStartedAt)
            .inMilliseconds
            .clamp(0, 300000),
        'audio_replay_count': _audioReplayCount,
        'misclick_count': 0,
        'hesitation_count': now.difference(_taskStartedAt).inSeconds > 30
            ? 1
            : 0,
        'touch_count': _touchCount,
      };
      final status = await _repository.submitResponse(
        _studentId,
        _pendingResponse!,
      );
      if (!mounted) return;
      setState(() {
        _status = status;
        _taskIndex = status.nextItemIndex.clamp(0, starterBaselineTasks.length);
        _submitting = false;
        _pendingResponse = null;
        _stage = status.isTerminal
            ? _StarterStage.complete
            : _StarterStage.tasks;
      });
      if (_stage == _StarterStage.complete) {
        _celebrationController.forward();
      }
      if (_stage == _StarterStage.tasks) _prepareCurrentTask();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage('පිළිතුර සුරකින්න බැරි වුණා. නැවත උත්සාහ කරමු.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _handleExit() async {
    if (_stage == _StarterStage.complete) {
      _openDashboard();
      return false;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.borderBlue.withValues(alpha: 0.75),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStudentAvatar(
                size: 84,
                key: const ValueKey('starter-exit-student-avatar'),
              ),
              const SizedBox(height: 14),
              Text(
                'දැන් මොකද කරන්නේ?',
                textAlign: TextAlign.center,
                style: AppTypography.sinhala(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ඔයා කරපු දේ සුරැකෙනවා. දැන් ඉතිරි ටික කරමු, නැත්නම් පසුව මෙතැනින්ම පටන් ගමු.',
                textAlign: TextAlign.center,
                style: AppTypography.sinhala(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, 'continue'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.calmBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    'දැන් ඉතිරි ටික කරමු',
                    style: AppTypography.sinhala(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, 'later'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gentleGreenDark,
                    backgroundColor: AppColors.gentleGreen.withValues(
                      alpha: 0.08,
                    ),
                    side: BorderSide(
                      color: AppColors.gentleGreenDark,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.schedule_rounded, size: 22),
                  label: Text(
                    'පසුව කරමු',
                    style: AppTypography.sinhala(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gentleGreenDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return false;
    if (choice == 'later') {
      Navigator.pop(context);
    }
    return false;
  }

  void _openDashboard() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(studentData: widget.studentData),
      ),
    );
  }

  // ─── Skill-themed colors ───
  Color _skillColor(int skill) {
    return switch (skill) {
      1 => AppColors.calmBlue,
      2 => AppColors.gentleGreenDark,
      3 => AppColors.warmAmber,
      _ => AppColors.softCoral,
    };
  }

  Color _skillBgColor(int skill) {
    return switch (skill) {
      1 => AppColors.slateBg,
      2 => AppColors.mintBg,
      3 => const Color(0xFFFFF3E0),
      _ => const Color(0xFFFCE4EC),
    };
  }

  String _taskLabel(StarterTaskKind kind) {
    return switch (kind) {
      StarterTaskKind.imageChoice => 'පින්තූර හඳුනාගැනීම',
      StarterTaskKind.shadowChoice => 'සෙවණැලි ගැළපීම',
      StarterTaskKind.textChoice => 'අකුරු හඳුනාගැනීම',
      StarterTaskKind.audioChoice => 'අකුරු අසා හඳුනාගැනීම',
      StarterTaskKind.imageWordChoice => 'වචන හඳුනාගැනීම',
      StarterTaskKind.audioSequence => 'වචන සකස් කිරීම',
      StarterTaskKind.sentenceChoice => 'වාක්‍ය හඳුනාගැනීම',
      StarterTaskKind.sentenceSequence => 'වාක්‍ය සකස් කිරීම',
    };
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleExit());
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Blurred background
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Image.asset(
                  'assets/images/backgrounds/map_bg.png',
                  fit: BoxFit.cover,
                  color: AppColors.cream.withValues(alpha: 0.76),
                  colorBlendMode: BlendMode.srcOver,
                ),
              ),
            ),
            // Floating shapes for playful feel
            if (_stage != _StarterStage.loading)
              const Positioned.fill(child: FloatingShapes(count: 8)),
            SafeArea(child: _buildStage()),
          ],
        ),
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _StarterStage.loading:
        return const Center(child: AppLoadingIndicator());
      case _StarterStage.intro:
        return _buildIntro();
      case _StarterStage.tutorial:
        return _buildTutorial();
      case _StarterStage.tasks:
        return _buildTask();
      case _StarterStage.complete:
        return _buildComplete();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // INTRO STAGE — Welcome screen with mascot & speech bubble
  // ═══════════════════════════════════════════════════════════════
  Widget _buildIntro() {
    final isResume = (_status?.nextItemIndex ?? 0) > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: Column(
        children: [
          // Top bar with back button
          Align(
            alignment: Alignment.centerLeft,
            child: _hudCircleButton(Icons.arrow_back_rounded, _handleExit),
          ),
          const Spacer(),

          // Speech bubble above mascot
          SpeechBubble(
            text: isResume
                ? 'ආයුබෝවන්, $_studentName! නැවත හමුවීම සතුටක්.'
                : 'ආයුබෝවන්, $_studentName! අපි එකට ඉගෙන ගනිමු 🌟',
            maxWidth: 300,
            delay: const Duration(milliseconds: 300),
          ),
          const SizedBox(height: 6),

          // Keep the child's selected character throughout the baseline.
          _buildStudentAvatar(
            size: 140,
            key: const ValueKey('starter-intro-student-avatar'),
          ),
          const SizedBox(height: 20),

          // Info card
          _glassCard(
            child: Column(
              children: [
                // Badge pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.blueButtonGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.calmBlue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '$_studentNameගේ ඉගෙනුම් ගමන',
                    style: AppTypography.sinhala(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  isResume
                      ? 'ඔයා කරපු දේ සුරැකිලා තියෙනවා. ඉතිරි ටික මෙතැනින්ම කරමු.'
                      : 'හොඳින් බලලා, අහලා, ඔයාට හිතෙන පිළිතුර තෝරන්න.',
                  textAlign: TextAlign.center,
                  style: AppTypography.sinhala(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Preserve one row and scale it down only on compact phones.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _infoPill(
                        Icons.sports_esports_rounded,
                        'පුංචි වැඩ 8ක්',
                        AppColors.calmBlue,
                      ),
                      const SizedBox(width: 10),
                      _infoPill(
                        Icons.favorite_rounded,
                        'වැරදුණත් කමක් නැහැ',
                        AppColors.softCoral,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Start button
          GradientButton(
            text: _submitting
                ? 'සූදානම් වෙනවා…'
                : (isResume ? 'ඉතිරි ටික කරමු' : 'අරඹමු  🚀'),
            icon: Icons.play_arrow_rounded,
            fontWeight: FontWeight.w600,
            onPressed: _startOrResume,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TUTORIAL STAGE — Practice rounds with game-like HUD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTutorial() {
    final isFirst = _tutorialIndex == 0;
    return FadeTransition(
      opacity: _stageTransitionAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          children: [
            // Game HUD header
            _buildGameHUD(
              label: 'පුහුණු වීම',
              current: _tutorialIndex + 1,
              total: 2,
              color: AppColors.warmAmber,
            ),
            const SizedBox(height: 16),

            // Main content card
            Expanded(
              child: _glassCard(
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Keep the touch cue on the first practice only. The
                    // sequence practice is clearer without a decorative icon.
                    if (isFirst) ...[
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.warmAmber.withValues(alpha: 0.2),
                              AppColors.warmAmber.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.warmAmber.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.touch_app_rounded,
                          color: AppColors.warmAmber,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (isFirst)
                      Text(
                        'නිල් තරුව තෝරමු',
                        textAlign: TextAlign.center,
                        style: AppTypography.sinhala(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Column(
                        children: [
                          Text(
                            'පිළිවෙළට සකසමු',
                            style: AppTypography.sinhala(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.calmBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.calmBlue.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Text(
                              'ගස උසයි',
                              style: AppTypography.sinhala(
                                fontSize: 27,
                                fontWeight: FontWeight.w600,
                                color: AppColors.calmBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),

                    // Tutorial choices
                    if (isFirst)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _tutorialShape(
                            'blue_star',
                            Icons.star_rounded,
                            AppColors.calmBlue,
                          ),
                          const SizedBox(width: 28),
                          _tutorialShape(
                            'yellow_star',
                            Icons.star_rounded,
                            AppColors.warmAmber,
                          ),
                        ],
                      )
                    else ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: _sequenceTray(emphasized: true),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        alignment: WrapAlignment.center,
                        children: [_tutorialWord('උසයි'), _tutorialWord('ගස')],
                      ),
                    ],

                    // Feedback message
                    if (_tutorialMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warmAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.warmAmber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lightbulb_rounded,
                              color: AppColors.warmAmber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _tutorialMessage!,
                                textAlign: TextAlign.center,
                                style: AppTypography.sinhala(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warmAmber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (!isFirst) ...[
                      const SizedBox(height: 24),
                      GradientButton(
                        text: 'ඉදිරියට යමු',
                        icon: Icons.arrow_forward_rounded,
                        fontWeight: FontWeight.w600,
                        gradient: AppColors.greenGradient,
                        onPressed: _finishTutorial,
                      ),
                    ],
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TASK STAGE — Main baseline tasks with game-quality UI
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTask() {
    if (_taskIndex >= starterBaselineTasks.length) return _buildComplete();
    final task = starterBaselineTasks[_taskIndex];
    final presentedChoices = orderedStarterChoices(
      task,
      _status?.sessionId ?? _studentId,
    );
    final ready =
        !_audioPreparing &&
        (task.isSequence
            ? _selectedIds.length == task.correctAnswerIds.length
            : _selectedIds.length == 1);
    final skillCol = _skillColor(task.skillNumber);

    return FadeTransition(
      opacity: _stageTransitionAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          children: [
            // Game HUD header
            _buildGameHUD(
              label: _taskLabel(task.kind),
              current: _taskIndex + 1,
              total: starterBaselineTasks.length,
              color: skillCol,
            ),
            const SizedBox(height: 12),

            // Main content card
            Expanded(
              child: _glassCard(
                child: Column(
                  children: [
                    _baselineQuestionCard(task),

                    // Helper text
                    if (task.helperText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        task.helperText!,
                        textAlign: TextAlign.center,
                        style: AppTypography.sinhala(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Prompt image (if any)
                    if (task.promptImageAsset != null) _promptImage(task),

                    // Sequence tray (if needed)
                    if (task.isSequence) ...[
                      _sequenceTray(),
                      const SizedBox(height: 14),
                    ],

                    // Answer choices
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: task.kind == StarterTaskKind.textChoice
                              ? LayoutBuilder(
                                  builder: (context, constraints) {
                                    final cardSize =
                                        ((constraints.maxWidth - 24) / 3)
                                            .clamp(72.0, 108.0)
                                            .toDouble();
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        presentedChoices.length,
                                        (index) => Padding(
                                          padding: EdgeInsets.only(
                                            right:
                                                index ==
                                                    presentedChoices.length - 1
                                                ? 0
                                                : 12,
                                          ),
                                          child: _choiceCard(
                                            task,
                                            presentedChoices[index],
                                            letterCardSize: cardSize,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  alignment: WrapAlignment.center,
                                  children: presentedChoices
                                      .map(
                                        (choice) => _choiceCard(task, choice),
                                      )
                                      .toList(),
                                ),
                        ),
                      ),
                    ),

                    // Bottom actions
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // A full secondary button is easier for a Grade-1
                        // learner to recognise and tap than a text-only link.
                        Expanded(
                          child: Material(
                            color: AppColors.warmAmber.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(28),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: _submitting
                                  ? null
                                  : () => _submitCurrent(skipped: true),
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: AppColors.warmAmber.withValues(
                                      alpha: 0.55,
                                    ),
                                    width: 1.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.keyboard_double_arrow_right_rounded,
                                      size: 23,
                                      color: AppColors.warmAmber,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'මඟ හරින්න',
                                      style: AppTypography.sinhala(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.warmAmber,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Submit button
                        Expanded(
                          child: AnimatedOpacity(
                            opacity: ready && !_submitting ? 1 : 0.45,
                            duration: const Duration(milliseconds: 200),
                            child: GradientButton(
                              text: _submitting ? 'සුරකිනවා…' : 'ඉදිරියට',
                              icon: _submitting
                                  ? Icons.hourglass_top_rounded
                                  : Icons.arrow_forward_rounded,
                              iconColor: Colors.white,
                              fontWeight: FontWeight.w600,
                              gradient: LinearGradient(
                                colors: [
                                  skillCol.withValues(alpha: 0.9),
                                  skillCol,
                                ],
                              ),
                              onPressed: ready ? _submitCurrent : () {},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // COMPLETE STAGE — Celebration with stars & mascot
  // ═══════════════════════════════════════════════════════════════
  Widget _buildComplete() {
    final insufficient = _status?.status == 'insufficient';
    return AnimatedBuilder(
      animation: _celebrationScale,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_celebrationScale.value * 0.2),
          child: Opacity(
            opacity: _celebrationScale.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
        child: Column(
          children: [
            const Spacer(),

            // Stars row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildGlowingStar(38, delay: true),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildGlowingStar(52),
                ),
                const SizedBox(width: 8),
                _buildGlowingStar(38, delay: true),
              ],
            ),
            const SizedBox(height: 16),

            // Keep the same selected character on the completion screen.
            _buildStudentAvatar(
              size: 170,
              key: const ValueKey('starter-complete-student-avatar'),
            ),
            const SizedBox(height: 22),

            // Celebration card
            _glassCard(
              child: Column(
                children: [
                  // Sparkle icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.warmGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warmAmber.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'හරිම හොඳයි! 🌟',
                    style: AppTypography.sinhala(
                      fontSize: 27,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    insufficient
                        ? 'කරපු දේ සුරැකිලා තියෙනවා. දැන් සතුටින් ඉගෙන ගනිමු!'
                        : 'දැන් අපි ඉගෙනුම් ගමන පටන් ගමු.',
                    textAlign: TextAlign.center,
                    style: AppTypography.sinhala(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GradientButton(
              text: 'මගේ ඉගෙනුම් පිටුවට යමු',
              icon: Icons.rocket_launch_rounded,
              fontWeight: FontWeight.w600,
              gradient: AppColors.greenGradient,
              onPressed: _openDashboard,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SHARED WIDGETS — Reusable components for all stages
  // ═══════════════════════════════════════════════════════════════

  Widget _buildStudentAvatar({required double size, Key? key}) {
    const fallback = 'assets/images/characters/human/human_student_1.png';
    return Container(
      key: key,
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.045),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            AppColors.calmBlue.withValues(alpha: 0.14),
            AppColors.cardSurface,
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.calmBlue.withValues(alpha: 0.28),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.calmBlue.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          _studentAvatarPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Image.asset(fallback, fit: BoxFit.cover),
        ),
      ),
    );
  }

  /// Game-like HUD with the same under-title progress used by skill screens.
  Widget _buildGameHUD({
    required String label,
    required int current,
    required int total,
    required Color color,
  }) {
    return Row(
      children: [
        // Close / exit button
        _hudCircleButton(Icons.close_rounded, _handleExit),
        const SizedBox(width: 14),

        // Title pill
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cardSurface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.sinhala(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(total, (index) {
                    final completed = index < current;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 5,
                        margin: EdgeInsets.only(
                          right: index == total - 1 ? 0 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: completed ? color : AppColors.borderLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Compact count; the visual progress bar stays below the title.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cardSurface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '$current/$total',
            style: AppTypography.body(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// Glass morphism card (consistent throughout all stages)
  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.borderBlue.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.calmBlue.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.7),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Circular HUD button (back, close)
  Widget _hudCircleButton(IconData icon, FutureOr<dynamic> Function() action) {
    return Material(
      color: AppColors.cardSurface.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => action(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.calmBlue, size: 22),
        ),
      ),
    );
  }

  /// Info pill with icon + text
  Widget _infoPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Text(
            label,
            style: AppTypography.sinhala(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Skill-screen style instruction card used by every baseline task.
  Widget _baselineQuestionCard(StarterBaselineTask task) {
    final showsTargetLetter = task.kind == StarterTaskKind.textChoice;
    final usesCompactQuestion = task.itemId == 'BL1S4S02';
    final targetLetter = showsTargetLetter && task.correctAnswerIds.isNotEmpty
        ? task.correctAnswerIds.first
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.warmAmber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.warmAmber, width: 2.5),
      ),
      child: Row(
        children: [
          if (showsTargetLetter) ...[
            Container(
              key: const ValueKey('baseline-target-letter'),
              width: 70,
              height: 70,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: AppColors.warmAmber.withValues(alpha: 0.42),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Transform.translate(
                offset: const Offset(0, -3),
                child: Text(
                  targetLetter,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  style: AppTypography.sinhala(
                    fontSize: 43,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              _audioPreparing
                  ? 'හොඳින් අහමු…'
                  : showsTargetLetter
                  ? 'අකුර තෝරන්න.'
                  : task.prompt,
              textAlign: TextAlign.center,
              style: AppTypography.sinhala(
                fontSize: usesCompactQuestion ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _audioButton(),
        ],
      ),
    );
  }

  /// Audio replay button matching the real skill activity prompt cards.
  Widget _audioButton() {
    return Material(
      color: AppColors.warmAmber,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _replayAudio,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.warmAmber.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            _audioPreparing
                ? Icons.hourglass_top_rounded
                : Icons.volume_up_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
      ),
    );
  }

  /// Tutorial shape button (star / circle)
  Widget _tutorialShape(String id, IconData icon, Color color) {
    final selected = _selectedIds.contains(id);
    return GestureDetector(
      onTap: () => _handleTutorialChoice(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.calmBlue.withValues(alpha: 0.14)
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: selected
                ? AppColors.calmBlue
                : color.withValues(alpha: 0.45),
            width: selected ? 4 : 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.calmBlue.withValues(alpha: 0.25)
                  : color.withValues(alpha: 0.15),
              blurRadius: selected ? 18 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            if (selected)
              const Positioned(
                top: 8,
                right: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.calmBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Tutorial word chip with press feedback
  Widget _tutorialWord(String word) {
    final selected = _selectedIds.contains(word);
    return GestureDetector(
      onTap: () => _handleTutorialChoice(word),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.calmBlue.withValues(alpha: 0.12)
              : AppColors.warmWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.calmBlue : AppColors.borderLight,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.calmBlue.withValues(alpha: 0.2)
                  : AppColors.shadow,
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          word,
          style: AppTypography.sinhala(
            fontSize: 27,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.calmBlue : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  /// Sequence tray for ordered selection
  Widget _sequenceTray({bool emphasized = false}) {
    final task = _stage == _StarterStage.tasks
        ? starterBaselineTasks[_taskIndex]
        : null;
    final slots = task?.correctAnswerIds.length ?? 2;
    final isLetterSequence = task?.kind == StarterTaskKind.audioSequence;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: emphasized ? 104 : 68),
      padding: EdgeInsets.all(emphasized ? 16 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.slateBg.withValues(alpha: 0.8),
            AppColors.slateBg.withValues(alpha: 0.5),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.borderBlue.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(slots, (index) {
          final value = index < _selectedIds.length ? _selectedIds[index] : '';
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            constraints: BoxConstraints(
              minWidth: emphasized ? 104 : 72,
              minHeight: emphasized ? 72 : 50,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: emphasized ? 16 : 10,
              vertical: emphasized ? 13 : 9,
            ),
            decoration: BoxDecoration(
              color: value.isEmpty
                  ? AppColors.cardSurface.withValues(alpha: 0.6)
                  : AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: value.isEmpty
                    ? AppColors.borderLight
                    : AppColors.calmBlue,
                width: value.isEmpty ? 1.5 : 2,
              ),
              boxShadow: value.isNotEmpty
                  ? [
                      BoxShadow(
                        color: AppColors.calmBlue.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                value.isEmpty ? '•' : value,
                style: AppTypography.sinhala(
                  fontSize: emphasized
                      ? 28
                      : isLetterSequence
                      ? 30
                      : 21,
                  fontWeight: FontWeight.w600,
                  color: value.isEmpty
                      ? AppColors.textHint
                      : AppColors.textPrimary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Prompt image with background decoration
  Widget _promptImage(StarterBaselineTask task) {
    final isWordPicture = task.kind == StarterTaskKind.imageWordChoice;
    final isTaskSevenPicture = task.itemId == 'BL1S4S01';
    final isTaskEightPicture = task.itemId == 'BL1S4S02';
    Widget image = Image.asset(task.promptImageAsset!, fit: BoxFit.contain);
    if (task.kind == StarterTaskKind.shadowChoice) {
      image = Opacity(
        opacity: 0.30,
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            AppColors.textPrimary,
            BlendMode.srcIn,
          ),
          child: image,
        ),
      );
    }
    return Container(
      key: ValueKey('baseline-prompt-image-${task.itemId}'),
      width: isTaskSevenPicture
          ? 210
          : isTaskEightPicture
          ? 190
          : isWordPicture
          ? 172
          : 130,
      height: isTaskSevenPicture
          ? 190
          : isTaskEightPicture
          ? 155
          : isWordPicture
          ? 150
          : 115,
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(
        isTaskSevenPicture || isTaskEightPicture || isWordPicture ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: _skillBgColor(starterBaselineTasks[_taskIndex].skillNumber),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _skillColor(
            starterBaselineTasks[_taskIndex].skillNumber,
          ).withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _skillColor(
              starterBaselineTasks[_taskIndex].skillNumber,
            ).withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: image,
    );
  }

  /// Choice card with press animation (matches PressableGameButton style)
  Widget _choiceCard(
    StarterBaselineTask task,
    StarterChoice choice, {
    double? letterCardSize,
  }) {
    final selected = _selectedIds.contains(choice.id);
    final textOnly = choice.imageAsset == null;
    final skillCol = _skillColor(task.skillNumber);

    final usesCenteredGlyph =
        task.kind == StarterTaskKind.textChoice ||
        task.kind == StarterTaskKind.audioChoice ||
        task.kind == StarterTaskKind.audioSequence;
    final (width, height) = choice.imageAsset != null
        ? (135.0, 148.0)
        : switch (task.kind) {
            StarterTaskKind.textChoice => (
              letterCardSize ?? 108.0,
              letterCardSize ?? 108.0,
            ),
            StarterTaskKind.audioChoice => (108.0, 108.0),
            StarterTaskKind.imageWordChoice => (128.0, 96.0),
            StarterTaskKind.audioSequence => (108.0, 108.0),
            StarterTaskKind.sentenceChoice => (280.0, 86.0),
            StarterTaskKind.sentenceSequence => (124.0, 86.0),
            _ => (120.0, 82.0),
          };

    return GestureDetector(
      onTap: () => _selectBaselineChoice(choice.id),
      child: AnimatedContainer(
        key: ValueKey('${task.itemId}:${choice.id}'),
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? skillCol.withValues(alpha: 0.08)
              : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? skillCol : AppColors.borderLight,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? skillCol.withValues(alpha: 0.25)
                  : AppColors.shadow,
              blurRadius: selected ? 14 : 6,
              offset: Offset(0, selected ? 3 : 4),
            ),
          ],
        ),
        child: choice.imageAsset != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Image.asset(choice.imageAsset!, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? skillCol.withValues(alpha: 0.12)
                          : AppColors.slateBg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      choice.label,
                      style: AppTypography.sinhala(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? skillCol : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Transform.translate(
                  offset: Offset(0, usesCenteredGlyph ? -3 : 0),
                  child: Text(
                    choice.label,
                    textAlign: TextAlign.center,
                    textHeightBehavior: usesCenteredGlyph
                        ? const TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          )
                        : null,
                    style: AppTypography.sinhala(
                      fontSize: switch (task.kind) {
                        StarterTaskKind.textChoice => 44,
                        StarterTaskKind.audioChoice =>
                          choice.label.length <= 2 ? 40 : 32,
                        StarterTaskKind.imageWordChoice => 24,
                        StarterTaskKind.audioSequence => 32,
                        StarterTaskKind.sentenceChoice => 18,
                        StarterTaskKind.sentenceSequence => 21,
                        _ => textOnly && choice.label.length <= 3 ? 26 : 17,
                      },
                      height:
                          task.kind == StarterTaskKind.textChoice ||
                              task.kind == StarterTaskKind.audioChoice ||
                              task.kind == StarterTaskKind.audioSequence
                          ? 1
                          : null,
                      fontWeight: FontWeight.w600,
                      color: selected ? skillCol : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Glowing star for celebration (matches SharedCelebrationPopup)
  Widget _buildGlowingStar(double size, {bool delay = false}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: delay
          ? const Interval(0.2, 1.0, curve: Curves.elasticOut)
          : Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Icon(
            Icons.star_rounded,
            size: size,
            color: const Color(0xFFFFD700),
            shadows: [
              Shadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                blurRadius: 15 * value,
              ),
            ],
          ),
        );
      },
    );
  }
}
