import 'package:flutter_test/flutter_test.dart';
import 'package:sipsara_app/adaptive/sequence_progression.dart';

void main() {
  test('resolves jumbled Sinhala units into stable pool order', () {
    expect(
      resolveSequencePoolOrder(
        poolTokens: const <String>['ය', 'ස', 'බ'],
        target: 'බසය',
      ),
      const <int>[2, 1, 0],
    );
    expect(
      resolveSequencePoolOrder(
        poolTokens: const <String>['ටු', 'පු', 'ව'],
        target: 'පුටුව',
      ),
      const <int>[1, 0, 2],
    );
  });

  test('locks only the consecutive correct prefix after a wrong attempt', () {
    const correct = <String>['බ', 'ස', 'ය'];

    expect(
      matchingSequencePrefixLength(
        placedTokens: const <String?>['බ', 'ය', 'ස'],
        correctTokens: correct,
      ),
      1,
    );
    expect(
      matchingSequencePrefixLength(
        placedTokens: const <String?>['බ', 'ස', 'ය'],
        correctTokens: correct,
      ),
      3,
    );
    expect(
      matchingSequencePrefixLength(
        placedTokens: const <String?>['ස', 'බ', 'ය'],
        correctTokens: correct,
      ),
      0,
    );
  });
}
