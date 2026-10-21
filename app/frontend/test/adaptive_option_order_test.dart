import 'package:flutter_test/flutter_test.dart';
import 'package:sipsara_app/adaptive/utils/adaptive_option_order.dart';

void main() {
  test('core remediation and confirmation use different target positions', () {
    final source = <String>[
      'elephant',
      'cat',
      'dog',
      'bird',
      'cow',
      'fish',
      'van',
    ];

    int targetPosition(String itemId) =>
        AdaptiveOptionOrder.withTargets<String>(
          source: source,
          itemId: itemId,
          isTarget: (value) => value == 'elephant',
        ).indexOf('elephant');

    expect(<int>{
      targetPosition('S1A1R02'),
      targetPosition('S1A1R02V3'),
      targetPosition('S1A1R02V4'),
    }, hasLength(3));
  });

  test('item-specific ordering is reproducible', () {
    final first = AdaptiveOptionOrder.shuffled<String>(<String>[
      'ක',
      'ග',
      'ට',
      'ම',
    ], 'S2A3R04V4');
    final second = AdaptiveOptionOrder.shuffled<String>(<String>[
      'ක',
      'ග',
      'ට',
      'ම',
    ], 'S2A3R04V4');
    expect(second, first);
  });

  test('two-choice confirmation never reuses the core target position', () {
    const source = <String>['target', 'distractor'];

    int targetPosition(String itemId) =>
        AdaptiveOptionOrder.withTargets<String>(
          source: source,
          itemId: itemId,
          isTarget: (value) => value == 'target',
        ).indexOf('target');

    expect(targetPosition('S1A4R01V2'), isNot(targetPosition('S1A4R01')));
  });
}
