import '../../../models/curriculum_models.dart';

/// One exact Skill 2 task selected for rendering and research telemetry.
///
/// Keeping the item ID and render data together prevents the UI from showing
/// a V1/V2 answer pool with the prompt or target from the core task.
class Skill2ResolvedRound {
  final String itemId;
  final String? variantId;
  final Map<String, dynamic> data;

  const Skill2ResolvedRound({
    required this.itemId,
    required this.variantId,
    required this.data,
  });
}

/// Suppresses duplicate lifecycle callbacks for one rendered item without
/// suppressing a new task that happens to use the same spoken instruction.
class Skill2ItemAutoplayGate {
  String? _lastItemId;

  bool shouldPlay(String itemId) {
    if (itemId.isEmpty || itemId == _lastItemId) return false;
    _lastItemId = itemId;
    return true;
  }
}

/// Keeps an audio-only task locked until the stimulus for the currently
/// rendered item has completed successfully. Request tokens prevent a slow
/// response for an old item from unlocking a newer item after navigation.
class Skill2PromptReadiness {
  int _requestToken = 0;
  String _itemId = '';
  bool _isLoading = false;
  bool _isReady = false;
  bool _hasFailed = false;

  bool get isLoading => _isLoading;
  bool get isReady => _isReady;
  bool get hasFailed => _hasFailed;

  void prepare(String itemId) {
    _requestToken++;
    _itemId = itemId;
    _isLoading = false;
    _isReady = false;
    _hasFailed = false;
  }

  int begin(String itemId) {
    _requestToken++;
    _itemId = itemId;
    _isLoading = true;
    _isReady = false;
    _hasFailed = false;
    return _requestToken;
  }

  bool finish({
    required String itemId,
    required int requestToken,
    required bool didPlay,
  }) {
    if (itemId != _itemId || requestToken != _requestToken) return false;
    _isLoading = false;
    _isReady = didPlay;
    _hasFailed = !didPlay;
    return true;
  }
}

class Skill2RoundResolver {
  /// Activities 1 and 2 introduce their instruction automatically only on the
  /// first core task. Later core/equivalent tasks remain available through the
  /// sound button without interrupting the child on every navigation.
  static bool shouldAutoplayActivityIntroduction({
    required int roundIndex,
    String? variantId,
  }) {
    return roundIndex == 0 && _normalizeVariant(variantId) == null;
  }

  static Skill2ResolvedRound resolve({
    required ActivityNode? activity,
    required int roundIndex,
    String? variantId,
  }) {
    final rounds = activity?.rounds ?? const <Map<String, dynamic>>[];
    if (roundIndex < 0 || roundIndex >= rounds.length) {
      return const Skill2ResolvedRound(
        itemId: '',
        variantId: null,
        data: <String, dynamic>{},
      );
    }

    final core = Map<String, dynamic>.from(rounds[roundIndex]);
    final coreContent = core['content'] is Map
        ? Map<String, dynamic>.from(core['content'] as Map)
        : Map<String, dynamic>.from(core);
    final coreId = CanonicalItemResolver.normalizeItemId(
      core['item_id']?.toString() ??
          CanonicalItemResolver.canonicalItemId(
            skillId: activity?.skillId ?? 'skill_2',
            activityId: activity?.id ?? 'act_1',
            roundNumber: roundIndex + 1,
          ),
    );

    final normalizedVariant = _normalizeVariant(variantId);
    if (normalizedVariant == null) {
      return Skill2ResolvedRound(
        itemId: coreId,
        variantId: null,
        data: coreContent,
      );
    }

    final variants = core['adaptive_variants'] is List
        ? core['adaptive_variants'] as List
        : const <dynamic>[];
    Map<String, dynamic>? selected;
    for (final candidate in variants) {
      if (candidate is! Map) continue;
      final mapped = Map<String, dynamic>.from(candidate);
      if (_normalizeVariant(mapped['variant_id']?.toString()) ==
          normalizedVariant) {
        selected = mapped;
        break;
      }
    }

    if (selected == null) {
      // Never fabricate variant content. Falling back to the core identity and
      // content keeps what the child sees aligned with what C4 receives.
      return Skill2ResolvedRound(
        itemId: coreId,
        variantId: null,
        data: coreContent,
      );
    }

    final variantContent = selected['content'] is Map
        ? Map<String, dynamic>.from(selected['content'] as Map)
        : <String, dynamic>{};
    final itemId = CanonicalItemResolver.normalizeItemId(
      selected['item_id']?.toString() ?? '$coreId$normalizedVariant',
    );
    return Skill2ResolvedRound(
      itemId: itemId,
      variantId: normalizedVariant,
      data: CanonicalItemResolver.mergeVariantContent(
        coreContent,
        variantContent,
      ),
    );
  }

  static int? roundIndexFromItemId(String? itemId) {
    final match = RegExp(
      r'^S2A\d+R(\d+)(?:V\d+)?$',
      caseSensitive: false,
    ).firstMatch(CanonicalItemResolver.normalizeItemId(itemId ?? ''));
    final round = int.tryParse(match?.group(1) ?? '');
    return round == null ? null : round - 1;
  }

  static String? variantFromItemId(String? itemId) {
    final match = RegExp(
      r'^S2A\d+R\d+(V\d+)?$',
      caseSensitive: false,
    ).firstMatch(CanonicalItemResolver.normalizeItemId(itemId ?? ''));
    return _normalizeVariant(match?.group(1));
  }

  static String? _normalizeVariant(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final match = RegExp(r'V?(\d+)', caseSensitive: false).firstMatch(value);
    return match == null ? null : 'V${match.group(1)}';
  }
}
