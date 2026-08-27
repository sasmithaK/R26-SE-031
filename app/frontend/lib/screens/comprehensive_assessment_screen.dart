import 'package:flutter/material.dart';
import '../widgets/app_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

import '../theme/app_theme.dart';
import '../models/comprehensive_assessment_questions.dart';
import '../widgets/gradient_button.dart';
import '../services/student_service.dart';
import '../services/localization_service.dart';
class ComprehensiveAssessmentScreen extends StatefulWidget {
  final String studentId;
  final String category;

  const ComprehensiveAssessmentScreen({
    super.key,
    required this.studentId,
    required this.category,
  });

  @override
  State<ComprehensiveAssessmentScreen> createState() => _ComprehensiveAssessmentScreenState();
}

class _ComprehensiveAssessmentScreenState extends State<ComprehensiveAssessmentScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isLoading = false;

  late List<bool?> _answers;
  late List<ComprehensiveQuestion> _questions;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _questions = ComprehensiveAssessmentData.getQuestionsByCategory(widget.category);
    _answers = List.generate(_questions.length, (_) => null);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onOptionSelected(int index, bool isYes) {
    HapticFeedback.lightImpact();
    setState(() {
      _answers[index] = isYes;
    });
    
    if (index < _questions.length - 1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _pageController.hasClients) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 800),
            curve: Curves.fastLinearToSlowEaseIn,
          );
        }
      });
    }
  }

  Future<void> _submitAssessment() async {
    if (_answers.contains(null)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please answer all questions (${_questions.length})', style: const TextStyle(fontWeight: FontWeight.bold)), 
          backgroundColor: AppColors.warmAmber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      final firstUnanswered = _answers.indexOf(null);
      if (firstUnanswered != -1 && _pageController.hasClients) {
        _pageController.animateToPage(
          firstUnanswered, 
          duration: const Duration(milliseconds: 800), 
          curve: Curves.fastLinearToSlowEaseIn,
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final error = await StudentService().submitComprehensiveAssessment(
      widget.studentId,
      widget.category,
      _answers.cast<bool>(),
    );
    
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error), 
          backgroundColor: AppColors.softCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evaluation successfully completed!', style: TextStyle(fontWeight: FontWeight.bold)), 
          backgroundColor: AppColors.gentleGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        if (_questions.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Questions not found for this category.')),
          );
        }

        final progress = (_currentIndex + 1) / _questions.length;

        return Scaffold(
          body: Stack(
        children: [
          // Map Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/backgrounds/map_bg.png'),
                fit: BoxFit.cover,
                opacity: 0.9,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: AppColors.cream.withValues(alpha: 0.7),
              ),
            ),
          ),
          
          SafeArea(
            child: _isLoading 
                ? const Center(child: AppLoadingIndicator())
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Row(
                          children: [
                            _buildPremiumBackButton(context),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        LocalizationService.instance.t('question_prefix'),
                                        style: AppTypography.caption(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '${_currentIndex + 1}',
                                        style: AppTypography.heading(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.calmBlue,
                                        ),
                                      ),
                                      Text(
                                        ' / ${_questions.length}',
                                        style: AppTypography.caption(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Stack(
                                    children: [
                                      Container(
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.03),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 600),
                                        curve: Curves.fastOutSlowIn,
                                        height: 10,
                                        width: (MediaQuery.of(context).size.width - 92) * progress,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.blueButtonGradient,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.calmBlue.withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 10),

                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (index) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          itemCount: _questions.length,
                          itemBuilder: (context, index) {
                            return _buildPremiumQuestionCard(_questions[index], index);
                          },
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          transform: Matrix4.translationValues(
                            0, 
                            _answers[_currentIndex] == null ? 20 : 0, 
                            0
                          ),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _answers[_currentIndex] == null ? 0.0 : 1.0,
                            child: GradientButton(
                              text: _currentIndex == _questions.length - 1 
                                  ? LocalizationService.instance.t('btn_finish_evaluation') 
                                  : LocalizationService.instance.t('btn_next_question'),
                              icon: _currentIndex == _questions.length - 1 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                              onPressed: _answers[_currentIndex] == null 
                                  ? () {}
                                  : () {
                                      HapticFeedback.lightImpact();
                                      if (_currentIndex < _questions.length - 1) {
                                        _pageController.nextPage(
                                          duration: const Duration(milliseconds: 800),
                                          curve: Curves.fastLinearToSlowEaseIn,
                                        );
                                      } else {
                                        _submitAssessment();
                                      }
                                    },
                            ),
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

  Widget _buildPremiumQuestionCard(ComprehensiveQuestion question, int index) {
    final isActive = index == _currentIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.fastOutSlowIn,
      margin: EdgeInsets.only(
        right: 16,
        left: 8,
        top: isActive ? 20 : 40,
        bottom: isActive ? 30 : 50,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.calmBlueDark.withValues(alpha: isActive ? 0.12 : 0.05),
            blurRadius: isActive ? 32 : 16,
            offset: Offset(0, isActive ? 16 : 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.calmBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${LocalizationService.instance.t("question_prefix")}${index + 1}',
                    style: AppTypography.caption(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.calmBlue,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        question.text,
                        textAlign: TextAlign.center,
                        style: AppTypography.heading(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildInteractiveBlock(
                        text: LocalizationService.instance.t('btn_yes'),
                        subtext: '',
                        icon: Icons.check_rounded,
                        isSelected: _answers[index] == true,
                        activeGradient: AppColors.greenGradient,
                        activeShadow: AppColors.gentleGreen,
                        onTap: () => _onOptionSelected(index, true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInteractiveBlock(
                        text: LocalizationService.instance.t('btn_no'),
                        subtext: '',
                        icon: Icons.close_rounded,
                        isSelected: _answers[index] == false,

                        activeGradient: AppColors.greenGradient,
                        activeShadow: AppColors.gentleGreen,
                        onTap: () => _onOptionSelected(index, false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveBlock({
    required String text,
    required String subtext,
    required IconData icon,
    required bool isSelected,
    required LinearGradient activeGradient,
    required Color activeShadow,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          gradient: isSelected ? activeGradient : null,
          color: isSelected ? null : AppColors.cream,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.borderLight,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeShadow.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: isSelected ? [] : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: AppTypography.heading(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (subtext.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtext,
                style: AppTypography.caption(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white.withValues(alpha: 0.8) : AppColors.textHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (_currentIndex > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 800),
            curve: Curves.fastLinearToSlowEaseIn,
          );
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.textPrimary,
          size: 20,
        ),
      ),
    );
  }
}
