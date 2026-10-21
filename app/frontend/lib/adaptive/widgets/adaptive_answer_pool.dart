import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../controllers/adaptive_choice_controller.dart';
import '../models/adaptive_scaffold_models.dart';

typedef AdaptiveOptionBuilder<T> =
    Widget Function(
      BuildContext context,
      AdaptiveOption<T> option,
      AdaptiveOptionVisualState state,
      double suggestedExtent,
    );

/// Responsive Grade-1 answer pool. It filters first and lays out second, so a
/// removed answer can never leave an invisible placeholder behind.
class AdaptiveAnswerPool<T> extends StatelessWidget {
  const AdaptiveAnswerPool({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.spacing = 16,
    this.minExtent = 80,
    this.maxExtent = 150,
    this.animationDuration = const Duration(milliseconds: 240),
    this.padding = EdgeInsets.zero,
  });

  final AdaptiveChoiceController<T> controller;
  final AdaptiveOptionBuilder<T> itemBuilder;
  final double spacing;
  final double minExtent;
  final double maxExtent;
  final Duration animationDuration;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final visible = controller.visibleOptions;
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = _columnCount(visible.length, constraints.maxWidth);
            final available = constraints.maxWidth.isFinite
                ? constraints.maxWidth - padding.horizontal
                : maxExtent * columns;
            final extent = ((available - spacing * (columns - 1)) / columns)
                .clamp(minExtent, maxExtent)
                .toDouble();
            final identity = visible.map((option) => option.id).join('|');

            final content = Padding(
              key: ValueKey(identity),
              padding: padding,
              child: Wrap(
                spacing: spacing,
                runSpacing: spacing,
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                children: <Widget>[
                  for (final option in visible)
                    KeyedSubtree(
                      key: ValueKey(option.id),
                      child: itemBuilder(
                        context,
                        option,
                        controller.visualStateFor(option.id),
                        extent,
                      ),
                    ),
                ],
              ),
            );
            if (animationDuration == Duration.zero) return content;
            return AnimatedSize(
              duration: animationDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: animationDuration,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: content,
              ),
            );
          },
        );
      },
    );
  }

  int _columnCount(int count, double width) {
    if (count <= 1) return 1;
    if (count == 2) return 2;
    if (count == 3) return width >= 430 ? 3 : 2;
    if (count == 4) return width >= 620 ? 4 : 2;
    if (count <= 6) return width >= 620 ? 3 : 2;
    return width >= 700 ? 4 : 3;
  }
}

/// Shared semantic appearance. Amber means guidance, green means confirmed
/// success, blue means selected, and coral means an incorrect attempt.
class AdaptiveOptionFrame extends StatelessWidget {
  const AdaptiveOptionFrame({
    super.key,
    required this.state,
    required this.child,
    required this.onTap,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 22,
    this.semanticLabel,
  });

  final AdaptiveOptionVisualState state;
  final Widget child;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final EdgeInsets padding;
  final double borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(state);
    final disabled = state == AdaptiveOptionVisualState.disabled;
    final icon = _iconFor(state);
    return Semantics(
      button: true,
      enabled: !disabled,
      selected: state == AdaptiveOptionVisualState.selected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedOpacity(
          opacity: disabled ? 0.45 : 1,
          duration: const Duration(milliseconds: 180),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: width,
            height: height,
            constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
            padding: padding,
            decoration: BoxDecoration(
              color: colors.$1,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: colors.$2,
                width: state == AdaptiveOptionVisualState.idle ? 2 : 4,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colors.$2.withValues(alpha: 0.22),
                  blurRadius: state == AdaptiveOptionVisualState.idle ? 8 : 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Center(child: child),
                if (icon != null)
                  Positioned(
                    top: -7,
                    right: -7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.$2,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(icon, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color) _colorsFor(AdaptiveOptionVisualState state) {
    switch (state) {
      case AdaptiveOptionVisualState.selected:
        return (AppColors.slateBg, AppColors.calmBlue);
      case AdaptiveOptionVisualState.hint:
        return (
          AppColors.warmAmberLight.withValues(alpha: 0.42),
          AppColors.warmAmber,
        );
      case AdaptiveOptionVisualState.correct:
        return (AppColors.mintBg, AppColors.gentleGreen);
      case AdaptiveOptionVisualState.incorrect:
        return (
          AppColors.softCoral.withValues(alpha: 0.14),
          AppColors.softCoral,
        );
      case AdaptiveOptionVisualState.disabled:
        return (AppColors.creamDark, AppColors.textHint);
      case AdaptiveOptionVisualState.idle:
        return (AppColors.cardSurface, AppColors.borderLight);
    }
  }

  IconData? _iconFor(AdaptiveOptionVisualState state) {
    switch (state) {
      case AdaptiveOptionVisualState.hint:
        return Icons.lightbulb_rounded;
      case AdaptiveOptionVisualState.correct:
        return Icons.check_rounded;
      case AdaptiveOptionVisualState.incorrect:
        return Icons.close_rounded;
      case AdaptiveOptionVisualState.selected:
        return Icons.touch_app_rounded;
      case AdaptiveOptionVisualState.disabled:
        return Icons.lock_outline_rounded;
      case AdaptiveOptionVisualState.idle:
        return null;
    }
  }
}
