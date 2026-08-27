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
  @override
  void initState() {
    super.initState();
    _loadSkillAndNavigate();
  }

  bool _isPopping = false;

  Future<void> _loadSkillAndNavigate() async {
    try {
      final skillDetail = await SkillDetail.load(widget.skill.file);
      if (!mounted) return;

      final bool isIntroSeen = ProgressService().isSkillIntroSeen(skillDetail.id);
      
      if (!isIntroSeen) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SkillIntroScreen(skillMap: skillDetail, studentData: widget.studentData)),
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
        MaterialPageRoute(builder: (context) => LevelMapScreen(skillMap: skillDetail, studentData: widget.studentData)),
      );

      if (mounted) {
        setState(() {
          _isPopping = true; // hide UI to prevent flash during pop
        });
        Navigator.pop(context, result);
      }
      
    } catch (e) {
      debugPrint('Error loading skill detail: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPopping) return const SizedBox.shrink(); // Transparent during pop

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: AppLoadingIndicator(),
      ),
    );
  }
}
