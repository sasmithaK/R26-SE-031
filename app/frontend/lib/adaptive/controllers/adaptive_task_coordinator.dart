import '../../models/curriculum_models.dart';

/// Single source of truth for the item currently rendered by an activity.
///
/// Core items and their V1/V2 equivalents share a progress position but keep
/// distinct item IDs and content. This prevents remediation from moving the
/// progress indicator backwards or silently reporting a variant as its core.
class AdaptiveTaskCoordinator {
  AdaptiveTaskCoordinator({required this.activity, int initialRoundIndex = 0})
    : _roundIndex = initialRoundIndex.clamp(
        0,
        activity.rounds.isEmpty ? 0 : activity.rounds.length - 1,
      ) {
    _itemId = _coreItemId(_roundIndex);
  }

  final ActivityNode activity;
  int _roundIndex;
  late String _itemId;
  String _phase = 'CORE';

  int get roundIndex => _roundIndex;
  int get progressIndex => _roundIndex;
  String get itemId => _itemId;
  String get phase => _phase;
  bool get isVariant => RegExp(r'V\d+$').hasMatch(_itemId);

  Map<String, dynamic> get roundData => resolveItem(_itemId);

  String _coreItemId(int index) {
    if (activity.rounds.isEmpty) return 'UNKNOWN_ITEM';
    final raw = activity.rounds[index]['item_id']?.toString();
    return CanonicalItemResolver.normalizeItemId(
      raw ??
          CanonicalItemResolver.canonicalItemId(
            skillId: activity.skillId,
            activityId: activity.id,
            roundNumber: index + 1,
          ),
    );
  }

  Map<String, dynamic> resolveItem(String requestedItemId) {
    final normalized = CanonicalItemResolver.normalizeItemId(requestedItemId);
    final match = RegExp(
      r'^S\d+A\d+R(\d+)(V\d+)?$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match == null || activity.rounds.isEmpty) {
      return const <String, dynamic>{};
    }
    final index = (int.tryParse(match.group(1) ?? '') ?? 1) - 1;
    if (index < 0 || index >= activity.rounds.length) {
      return const <String, dynamic>{};
    }
    final core = Map<String, dynamic>.from(activity.rounds[index]);
    final suffix = match.group(2)?.toUpperCase();
    if (suffix == null) return core;
    final variants = core['adaptive_variants'];
    if (variants is! Iterable) return core;
    for (final rawVariant in variants) {
      if (rawVariant is! Map) continue;
      final variant = Map<String, dynamic>.from(rawVariant);
      final variantId = CanonicalItemResolver.normalizeItemId(
        variant['item_id']?.toString() ?? '',
      );
      final variantName = variant['variant_id']?.toString().toUpperCase();
      if (variantId == normalized || variantName == suffix) {
        final content = variant['content'] is Map
            ? Map<String, dynamic>.from(variant['content'] as Map)
            : const <String, dynamic>{};
        return <String, dynamic>{
          ...core,
          ...variant,
          ...content,
          'item_id': normalized,
          'core_item_id': _coreItemId(index),
          'adaptive_phase': variant['item_role']?.toString() ?? suffix,
        };
      }
    }
    return core;
  }

  AdaptiveTaskTransition applyResult(Map<String, dynamic>? result) {
    final rawAction = result?['next_action'];
    if (rawAction is! Map) {
      return _sequentialFallback('MISSING_NEXT_ACTION');
    }
    final action = Map<String, dynamic>.from(rawAction);
    final decision = action['decision']?.toString() ?? 'CONTINUE';
    final requested = action['next_item']?.toString() ?? '';
    _phase = action['next_phase']?.toString() ?? 'CORE';

    if (decision == 'TERMINATE') {
      // A safety/fatigue stop is not proof that the child completed the
      // activity. Older backend responses used TERMINATE with an empty item;
      // continue safely instead of showing a false completion celebration.
      return _sequentialFallback('TERMINATE_IS_NOT_ACTIVITY_COMPLETE');
    }

    if (decision == 'ACTIVITY_COMPLETE' ||
        decision == 'CURRICULUM_COMPLETE' ||
        requested == 'COMPLETE') {
      return AdaptiveTaskTransition.complete(decision: decision, phase: _phase);
    }

    if (requested.isEmpty) {
      return _sequentialFallback('EMPTY_NEXT_ITEM');
    }
    final normalized = CanonicalItemResolver.normalizeItemId(requested);
    final match = RegExp(
      r'^S(\d+)A(\d+)R(\d+)(V\d+)?$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match == null) return _sequentialFallback('INVALID_NEXT_ITEM');

    final expectedSkill = RegExp(r'\d+').firstMatch(activity.skillId);
    final expectedActivity = RegExp(r'\d+').firstMatch(activity.id);
    if (match.group(1) != expectedSkill?.group(0) ||
        match.group(2) != expectedActivity?.group(0)) {
      return AdaptiveTaskTransition.external(
        itemId: normalized,
        decision: decision,
        phase: _phase,
      );
    }

    final nextIndex = (int.tryParse(match.group(3) ?? '') ?? 1) - 1;
    if (nextIndex < 0 || nextIndex >= activity.rounds.length) {
      return _sequentialFallback('NEXT_ITEM_OUT_OF_RANGE');
    }
    _roundIndex = nextIndex;
    _itemId = normalized;
    return AdaptiveTaskTransition.item(
      roundIndex: _roundIndex,
      itemId: _itemId,
      phase: _phase,
      decision: decision,
      roundData: roundData,
      reasonCodes: _strings(action['reason_codes']),
    );
  }

  AdaptiveTaskTransition _sequentialFallback(String reason) {
    if (_roundIndex >= activity.rounds.length - 1) {
      return AdaptiveTaskTransition.complete(
        decision: 'ACTIVITY_COMPLETE',
        phase: 'COMPLETE',
        reasonCodes: <String>[reason],
      );
    }
    _roundIndex += 1;
    _itemId = _coreItemId(_roundIndex);
    _phase = 'CORE';
    return AdaptiveTaskTransition.item(
      roundIndex: _roundIndex,
      itemId: _itemId,
      phase: _phase,
      decision: 'SEQUENTIAL_FALLBACK',
      roundData: roundData,
      reasonCodes: <String>[reason],
    );
  }

  static List<String> _strings(dynamic value) => value is Iterable
      ? value.map((item) => item.toString()).toList()
      : const <String>[];
}

class AdaptiveTaskTransition {
  const AdaptiveTaskTransition._({
    required this.roundIndex,
    required this.itemId,
    required this.phase,
    required this.decision,
    required this.roundData,
    required this.isComplete,
    required this.isExternal,
    required this.reasonCodes,
  });

  factory AdaptiveTaskTransition.item({
    required int roundIndex,
    required String itemId,
    required String phase,
    required String decision,
    required Map<String, dynamic> roundData,
    List<String> reasonCodes = const <String>[],
  }) => AdaptiveTaskTransition._(
    roundIndex: roundIndex,
    itemId: itemId,
    phase: phase,
    decision: decision,
    roundData: roundData,
    isComplete: false,
    isExternal: false,
    reasonCodes: reasonCodes,
  );

  factory AdaptiveTaskTransition.complete({
    required String decision,
    required String phase,
    List<String> reasonCodes = const <String>[],
  }) => AdaptiveTaskTransition._(
    roundIndex: -1,
    itemId: 'COMPLETE',
    phase: phase,
    decision: decision,
    roundData: const <String, dynamic>{},
    isComplete: true,
    isExternal: false,
    reasonCodes: reasonCodes,
  );

  factory AdaptiveTaskTransition.external({
    required String itemId,
    required String decision,
    required String phase,
  }) => AdaptiveTaskTransition._(
    roundIndex: -1,
    itemId: itemId,
    phase: phase,
    decision: decision,
    roundData: const <String, dynamic>{},
    isComplete: false,
    isExternal: true,
    reasonCodes: const <String>[],
  );

  final int roundIndex;
  final String itemId;
  final String phase;
  final String decision;
  final Map<String, dynamic> roundData;
  final bool isComplete;
  final bool isExternal;
  final List<String> reasonCodes;
}
