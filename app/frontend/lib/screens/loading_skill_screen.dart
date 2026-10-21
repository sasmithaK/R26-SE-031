import 'package:flutter/material.dart';
import '../models/dashboard_config.dart';
import '../models/curriculum_models.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_loading_indicator.dart';
import 'level_map_screen.dart';
import 'skill_intro_screen.dart';

class LoadingSkillScreen extends StatefulWidget {
  final SkillSummary skill;
  final Map<String, dynamic>? studentData;
  final VoidCallback onReturn;

  const LoadingSkillScreen({
    super.key,
    required this.skill,
    this.studentData,
    required this.onReturn,
  });

  @override
  State<LoadingSkillScreen> createState() => _LoadingSkillScreenState();
}

class _LoadingSkillScreenState extends State<LoadingSkillScreen> {
  String? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Wait until this route has completed its first frame before pushing the
    // intro/map route. This avoids a nested Navigator push during route setup
    // and makes the transition reliable on slower physical Android devices.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSkillAndNavigate();
    });
  }

  bool _isPopping = false;

  Future<void> _loadSkillAndNavigate() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final skillFile = widget.skill.file.trim().replaceAll('\\', '/');
      if (skillFile.isEmpty) {
        throw StateError(
          'No curriculum file is configured for ${widget.skill.id}',
        );
      }

      // Curriculum files are bundled locally; no backend request is needed to
      // open the activity map. Bound this operation so a missing/corrupt asset
      // cannot leave every student on an endless loading screen.
      final skillDetail = await SkillDetail.load(skillFile)
          .timeout(const Duration(seconds: 15));
      if (skillDetail.activities.isEmpty) {
        throw StateError('The curriculum file contains no activities');
      }
      if (!mounted) return;

      final bool isIntroSeen = ProgressService().isSkillIntroSeen(
        skillDetail.id,
      );

      if (!isIntroSeen) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SkillIntroScreen(
              skillMap: skillDetail,
              studentData: widget.studentData,
            ),
          ),
        );
        if (result != true) {
          // User backed out of intro without clicking start
          if (mounted) Navigator.pop(context);
          return;
        }
      }

      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LevelMapScreen(
            skillMap: skillDetail,
            studentData: widget.studentData,
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _isPopping = true; // hide UI to prevent flash during pop
        });
        Navigator.pop(context, result);
      }
    } catch (e, stackTrace) {
      debugPrint(
        'Error opening ${widget.skill.id} activity map: $e\n$stackTrace',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'We couldn’t open these activities. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPopping) return const SizedBox.shrink(); // Transparent during pop

    if (!_isLoading && _loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book_rounded,
                      size: 52, color: AppColors.calmBlue),
                  const SizedBox(height: 16),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      fontSize: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _loadSkillAndNavigate,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to skills'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: AppLoadingIndicator(),
      ),
    );
  }
}
