import 'package:flutter/foundation.dart';

import '../models/adaptive_scaffold_models.dart';

/// The single state reducer used by choice, matching, memory, and sequence
/// adapters. Filtering happens here so layouts never receive placeholder gaps.
class AdaptiveChoiceController<T> extends ChangeNotifier {
  AdaptiveChoiceController({
    List<AdaptiveOption<T>>? options,
    this.minimumVisibleOptions = 2,
  }) : _allOptions = List<AdaptiveOption<T>>.from(
         options ?? <AdaptiveOption<T>>[],
       ) {
    _validateUniqueIds(_allOptions);
  }

  List<AdaptiveOption<T>> _allOptions;
  final int minimumVisibleOptions;
  final Set<String> _removedIds = <String>{};
  final Set<String> _highlightedIds = <String>{};
  final Set<String> _disabledIds = <String>{};
  final Set<String> _selectedIds = <String>{};
  final Set<String> _correctIds = <String>{};
  final Set<String> _incorrectIds = <String>{};
  final Set<String> _appliedActionIds = <String>{};

  List<AdaptiveOption<T>> get allOptions => List.unmodifiable(_allOptions);
  List<AdaptiveOption<T>> get visibleOptions => List.unmodifiable(
    _allOptions.where((option) => !_removedIds.contains(option.id)),
  );
  Set<String> get removedIds => Set.unmodifiable(_removedIds);
  Set<String> get highlightedIds => Set.unmodifiable(_highlightedIds);
  Set<String> get disabledIds => Set.unmodifiable(_disabledIds);

  void configure(List<AdaptiveOption<T>> options) {
    _validateUniqueIds(options);
    _allOptions = List<AdaptiveOption<T>>.from(options);
    reset(notify: false);
    notifyListeners();
  }

  void reset({bool notify = true}) {
    _removedIds.clear();
    _highlightedIds.clear();
    _disabledIds.clear();
    _selectedIds.clear();
    _correctIds.clear();
    _incorrectIds.clear();
    _appliedActionIds.clear();
    if (notify) notifyListeners();
  }

  void setSelected(String id, {bool selected = true}) {
    selected ? _selectedIds.add(id) : _selectedIds.remove(id);
    _highlightedIds.remove(id);
    notifyListeners();
  }

  void markCorrect(String id) {
    _correctIds.add(id);
    _incorrectIds.remove(id);
    notifyListeners();
  }

  void markIncorrect(String id) {
    _incorrectIds.add(id);
    notifyListeners();
  }

  void clearTransientFeedback() {
    _incorrectIds.clear();
    notifyListeners();
  }

  AdaptiveOptionVisualState visualStateFor(String id) {
    if (_correctIds.contains(id)) return AdaptiveOptionVisualState.correct;
    if (_incorrectIds.contains(id)) return AdaptiveOptionVisualState.incorrect;
    if (_disabledIds.contains(id)) return AdaptiveOptionVisualState.disabled;
    if (_selectedIds.contains(id)) return AdaptiveOptionVisualState.selected;
    if (_highlightedIds.contains(id)) return AdaptiveOptionVisualState.hint;
    return AdaptiveOptionVisualState.idle;
  }

  ScaffoldApplicationReport applyPlan(ScaffoldPlan plan) {
    final visibleBefore = visibleOptions.length;
    final requested = <String>{};
    final applied = <String>{};
    final rejected = <String>[];

    for (final command in plan.commands) {
      requested.addAll(command.targetOptionIds);
      if (_appliedActionIds.contains(command.actionId)) {
        rejected.add('DUPLICATE_ACTION:${command.actionId}');
        continue;
      }
      final knownIds = _allOptions.map((option) => option.id).toSet();
      final validIds = command.targetOptionIds.intersection(knownIds);
      if (validIds.length != command.targetOptionIds.length) {
        rejected.add('UNKNOWN_OPTION_ID');
      }

      switch (command.type) {
        case ScaffoldActionType.removeOptions:
          for (final id in validIds) {
            final option = _allOptions.firstWhere((item) => item.id == id);
            if (option.isTarget) {
              rejected.add('TARGET_REMOVAL_BLOCKED:$id');
              continue;
            }
            if (visibleOptions.length <= minimumVisibleOptions) {
              rejected.add('MINIMUM_VISIBLE_OPTIONS_REACHED');
              break;
            }
            _removedIds.add(id);
            _highlightedIds.remove(id);
            _disabledIds.remove(id);
            applied.add(id);
          }
          break;
        case ScaffoldActionType.highlightOptions:
        case ScaffoldActionType.revealFirstToken:
          _highlightedIds
            ..clear()
            ..addAll(validIds.where((id) => !_removedIds.contains(id)));
          applied.addAll(_highlightedIds);
          break;
        case ScaffoldActionType.disableOptions:
          _disabledIds.addAll(
            validIds.where((id) => !_removedIds.contains(id)),
          );
          applied.addAll(validIds);
          break;
        case ScaffoldActionType.replayInstruction:
        case ScaffoldActionType.slowAudio:
        case ScaffoldActionType.lockCorrectToken:
        case ScaffoldActionType.showWorkedExample:
        case ScaffoldActionType.pauseSession:
          // These are consumed by task-family adapters rather than choice state.
          break;
      }
      _appliedActionIds.add(command.actionId);
    }

    notifyListeners();
    return ScaffoldApplicationReport(
      actionId: plan.actionId,
      requestedOptionIds: requested,
      appliedOptionIds: applied,
      visibleBefore: visibleBefore,
      visibleAfter: visibleOptions.length,
      rejectedReasons: rejected,
    );
  }

  void _validateUniqueIds(List<AdaptiveOption<T>> options) {
    final ids = options.map((option) => option.id).toSet();
    if (ids.length != options.length) {
      throw ArgumentError('Adaptive option IDs must be unique within an item.');
    }
  }
}
