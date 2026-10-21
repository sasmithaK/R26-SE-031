import 'dart:math';

/// Reproducible, item-specific layouts that prevent coordinate memorization.
class AdaptiveOptionOrder {
  const AdaptiveOptionOrder._();

  static int stableSeed(String value) {
    var hash = 17;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  static String coreItemId(String itemId) =>
      itemId.replaceFirst(RegExp(r'V\d+$', caseSensitive: false), '');

  static int _phaseOffset(String itemId, int optionCount) {
    final match = RegExp(r'V(\d+)$', caseSensitive: false).firstMatch(itemId);
    if (match == null) return 0;
    final variant = int.tryParse(match.group(1) ?? '') ?? 0;
    if (variant.isOdd) return 1;
    // A two-choice pool cannot expose three unique layouts. Keep both
    // practice phases on the alternate layout so confirmation never restores
    // the target to the coordinate remembered from the original core item.
    return optionCount == 2 ? 1 : 2;
  }

  static List<T> shuffled<T>(
    List<T> source,
    String itemId, {
    String salt = '',
  }) {
    if (source.length < 2) return List<T>.from(source);
    final result = List<T>.from(source)
      ..shuffle(Random(stableSeed('${coreItemId(itemId)}:$salt')));
    final offset = _phaseOffset(itemId, result.length) % result.length;
    if (offset == 0) return result;
    return <T>[...result.skip(offset), ...result.take(offset)];
  }

  /// Places targets at a different first position for core, remediation and
  /// confirmation. With pools of three or more all three locations differ.
  static List<T> withTargets<T>({
    required List<T> source,
    required String itemId,
    required bool Function(T value) isTarget,
  }) {
    if (source.length < 2) return List<T>.from(source);
    final targets = source.where(isTarget).toList()
      ..shuffle(Random(stableSeed('$itemId:targets')));
    final distractors = source.where((value) => !isTarget(value)).toList()
      ..shuffle(Random(stableSeed('$itemId:distractors')));
    if (targets.isEmpty || distractors.isEmpty) {
      return shuffled(source, itemId);
    }

    final length = source.length;
    final basePosition = stableSeed(coreItemId(itemId)) % length;
    final firstTargetPosition =
        (basePosition + _phaseOffset(itemId, length)) % length;
    final result = List<T?>.filled(length, null);
    for (var index = 0; index < targets.length; index++) {
      var position = (firstTargetPosition + index) % length;
      while (result[position] != null) {
        position = (position + 1) % length;
      }
      result[position] = targets[index];
    }
    var distractorIndex = 0;
    for (var index = 0; index < result.length; index++) {
      if (result[index] == null) {
        result[index] = distractors[distractorIndex++];
      }
    }
    return result.cast<T>();
  }
}
