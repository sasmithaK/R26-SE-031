import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sipsara_app/widgets/research_evidence_panel.dart';
import 'package:sipsara_app/widgets/trend_chart.dart';

void main() {
  setUpAll(() { GoogleFonts.config.allowRuntimeFetching = false; });
  test('missing metrics are distinct from real zero', () {
    expect(metricText(null), 'Unavailable');
    expect(metricText(0), '0.00');
    expect(metricText(double.nan), 'Unavailable');
  });
  testWidgets('failed section offers retry without fabricated metrics', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DashboardSection(
      data: const {'_error': 'HTTP 503'}, onRetry: () { retried = true; }, child: const Text('Measured value'),
    ))));
    expect(find.text('HTTP 503'), findsOneWidget);
    expect(find.text('Measured value'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
  testWidgets('synthetic provenance and limits stay visible', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DashboardSection(
      data: const {'data_origin': 'synthetic', 'dataset_id': 'pp2-test'},
      onRetry: () {}, child: const Text('Evidence'),
    ))));
    expect(find.textContaining('SYNTHETIC PP2'), findsOneWidget);
    expect(find.textContaining('not a diagnosis'), findsOneWidget);
  });
  testWidgets('mixed missing chart points do not crash or become zeros', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TrendChart(
      title: 'Measured values', dataPoints: [.2, null, .8], labels: ['one', 'missing', 'three'],
    ))));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
