/// Resolves the unique pool positions that form [target] in reading order.
///
/// Jumbled activities keep pool indices as stable research identifiers, so
/// this returns indices rather than only the visible token strings. A small
/// depth-first search handles tokens with different lengths without assuming
/// that each Sinhala unit occupies one code point.
List<int> resolveSequencePoolOrder({
  required List<String> poolTokens,
  required String target,
}) {
  List<int>? search(String formed, List<int> used) {
    if (formed == target && used.length == poolTokens.length) {
      return List<int>.from(used);
    }
    if (!target.startsWith(formed) || used.length >= poolTokens.length) {
      return null;
    }

    for (var index = 0; index < poolTokens.length; index++) {
      if (used.contains(index)) continue;
      final next = '$formed${poolTokens[index]}';
      if (!target.startsWith(next)) continue;
      final resolved = search(next, <int>[...used, index]);
      if (resolved != null) return resolved;
    }
    return null;
  }

  return search('', const <int>[]) ?? const <int>[];
}

/// Returns the number of consecutive correct tokens at the start of an
/// attempted sequence. Only this prefix is safe to retain and lock: keeping a
/// later token across an earlier mistake would reveal an invalid ordering.
int matchingSequencePrefixLength({
  required List<String?> placedTokens,
  required List<String> correctTokens,
}) {
  final comparableLength = placedTokens.length < correctTokens.length
      ? placedTokens.length
      : correctTokens.length;
  var prefixLength = 0;
  while (prefixLength < comparableLength &&
      placedTokens[prefixLength] == correctTokens[prefixLength]) {
    prefixLength++;
  }
  return prefixLength;
}
