import 'package:flutter/foundation.dart';

/// Semantic actions understood by Component 4. Activities advertise the
/// subset they support; the backend never controls pixels, colours, or layout.
enum ScaffoldActionType {
  removeOptions,
  highlightOptions,
  disableOptions,
  replayInstruction,
  slowAudio,
  revealFirstToken,
  lockCorrectToken,
  pauseSession,
}

enum AdaptiveOptionRole {
  target,
  visualDistractor,
  phonologicalDistractor,
  semanticDistractor,
  unrelatedDistractor,
  sequenceToken,
  unknown,
}

enum AdaptiveOptionVisualState {
  idle,
  selected,
  hint,
  correct,
  incorrect,
  disabled,
}

@immutable
class AdaptiveOption<T> {
  const AdaptiveOption({
    required this.id,
    required this.value,
    this.role = AdaptiveOptionRole.unknown,
    this.metadata = const <String, dynamic>{},
  });

  /// Stable research identifier. It must not be a shuffled list index or the
  /// visible Sinhala value because both can change or be duplicated.
  final String id;
  final T value;
  final AdaptiveOptionRole role;
  final Map<String, dynamic> metadata;

  bool get isTarget => role == AdaptiveOptionRole.target;
}

@immutable
class ScaffoldCommand {
  const ScaffoldCommand({
    required this.actionId,
    required this.type,
    this.targetOptionIds = const <String>{},
    this.style = 'hint',
    this.reasonCode = 'UNSPECIFIED',
    this.durationMs,
  });

  final String actionId;
  final ScaffoldActionType type;
  final Set<String> targetOptionIds;
  final String style;
  final String reasonCode;
  final int? durationMs;

  factory ScaffoldCommand.fromJson(
    Map<String, dynamic> json, {
    required String fallbackActionId,
  }) {
    final rawType = (json['type'] ?? '').toString().toUpperCase();
    return ScaffoldCommand(
      actionId: (json['action_id'] ?? fallbackActionId).toString(),
      type: _parseType(rawType),
      targetOptionIds: _stringSet(
        json['target_option_ids'] ?? json['option_ids'],
      ),
      style: (json['style'] ?? 'hint').toString(),
      reasonCode: (json['reason_code'] ?? 'UNSPECIFIED').toString(),
      durationMs: (json['duration_ms'] as num?)?.toInt(),
    );
  }

  static ScaffoldActionType _parseType(String value) {
    switch (value) {
      case 'REMOVE_OPTION':
      case 'REMOVE_OPTIONS':
        return ScaffoldActionType.removeOptions;
      case 'HIGHLIGHT_OPTION':
      case 'HIGHLIGHT_OPTIONS':
      case 'HIGHLIGHT_CORRECT':
        return ScaffoldActionType.highlightOptions;
      case 'DISABLE_OPTION':
      case 'DISABLE_OPTIONS':
        return ScaffoldActionType.disableOptions;
      case 'REPLAY_INSTRUCTION':
        return ScaffoldActionType.replayInstruction;
      case 'SLOW_AUDIO':
        return ScaffoldActionType.slowAudio;
      case 'REVEAL_FIRST_TOKEN':
        return ScaffoldActionType.revealFirstToken;
      case 'LOCK_CORRECT_TOKEN':
        return ScaffoldActionType.lockCorrectToken;
      case 'PAUSE_SESSION':
        return ScaffoldActionType.pauseSession;
      default:
        return ScaffoldActionType.highlightOptions;
    }
  }

  static Set<String> _stringSet(dynamic values) {
    if (values is Iterable) {
      return values.map((value) => value.toString()).toSet();
    }
    if (values == null) return <String>{};
    return <String>{values.toString()};
  }
}

@immutable
class ScaffoldPlan {
  const ScaffoldPlan({
    required this.actionId,
    required this.commands,
    this.scaffoldLevel = 0,
    this.policyVersion = 'C4_POLICY_V2',
    this.reasonCodes = const <String>[],
  });

  final String actionId;
  final List<ScaffoldCommand> commands;
  final int scaffoldLevel;
  final String policyVersion;
  final List<String> reasonCodes;

  bool get isEmpty => commands.isEmpty;

  /// Reads the V2 command protocol and remains compatible with the existing
  /// remove_option_ids/highlight_correct backend during migration.
  factory ScaffoldPlan.fromNextAction(
    Map<String, dynamic>? json, {
    Iterable<String> correctOptionIds = const <String>[],
  }) {
    if (json == null) {
      return const ScaffoldPlan(
        actionId: 'none',
        commands: <ScaffoldCommand>[],
      );
    }

    final actionId =
        (json['action_id'] ??
                'legacy-${json['next_item'] ?? 'item'}-${json['scaffold_level'] ?? 0}')
            .toString();
    final commands = <ScaffoldCommand>[];
    final rawCommands = json['commands'];
    if (rawCommands is Iterable) {
      var index = 0;
      for (final raw in rawCommands) {
        if (raw is Map) {
          commands.add(
            ScaffoldCommand.fromJson(
              Map<String, dynamic>.from(raw),
              fallbackActionId: '$actionId-$index',
            ),
          );
          index++;
        }
      }
    }

    final legacyRemove = ScaffoldCommand._stringSet(json['remove_option_ids']);
    if (legacyRemove.isNotEmpty &&
        !commands.any(
          (command) => command.type == ScaffoldActionType.removeOptions,
        )) {
      commands.add(
        ScaffoldCommand(
          actionId: '$actionId-remove',
          type: ScaffoldActionType.removeOptions,
          targetOptionIds: legacyRemove,
          reasonCode: 'LEGACY_REMOVE_OPTION',
        ),
      );
    }
    if (json['highlight_correct'] == true &&
        !commands.any(
          (command) => command.type == ScaffoldActionType.highlightOptions,
        )) {
      commands.add(
        ScaffoldCommand(
          actionId: '$actionId-highlight',
          type: ScaffoldActionType.highlightOptions,
          targetOptionIds: correctOptionIds.toSet(),
          reasonCode: 'LEGACY_HIGHLIGHT_CORRECT',
        ),
      );
    }

    return ScaffoldPlan(
      actionId: actionId,
      commands: commands,
      scaffoldLevel: (json['scaffold_level'] as num?)?.toInt() ?? 0,
      policyVersion: (json['policy_version'] ?? 'C4_POLICY_V2').toString(),
      reasonCodes: ScaffoldCommand._stringSet(
        json['reason_codes'] ?? json['policy_reason'],
      ).toList(),
    );
  }
}

@immutable
class ScaffoldApplicationReport {
  const ScaffoldApplicationReport({
    required this.actionId,
    required this.requestedOptionIds,
    required this.appliedOptionIds,
    required this.visibleBefore,
    required this.visibleAfter,
    required this.rejectedReasons,
  });

  final String actionId;
  final Set<String> requestedOptionIds;
  final Set<String> appliedOptionIds;
  final int visibleBefore;
  final int visibleAfter;
  final List<String> rejectedReasons;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'action_id': actionId,
    'requested_option_ids': requestedOptionIds.toList(),
    'applied_option_ids': appliedOptionIds.toList(),
    'visible_before': visibleBefore,
    'visible_after': visibleAfter,
    'rejected_reasons': rejectedReasons,
  };
}
