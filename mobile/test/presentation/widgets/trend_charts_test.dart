import 'package:flutter/material.dart';
import 'dart:ui' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/theme/app_theme.dart';
import 'package:flutter_work_time/presentation/utils/duration_hm.dart';
import 'package:flutter_work_time/presentation/widgets/charts/trend_charts.dart';

const _h = 3600000;

ChartPoint _p(int i, num valueH,
        {num? refH, num? secH, bool hasData = true, bool partial = false}) =>
    ChartPoint(
      key: 'k$i',
      axisLabel: 'KW ${40 + i}',
      label: 'KW ${40 + i} · Woche $i',
      valueMs: (valueH * _h).round(),
      referenceMs: refH == null ? null : (refH * _h).round(),
      secondaryMs: secH == null ? null : (secH * _h).round(),
      hasData: hasData,
      partial: partial,
    );

const _barLabels = ChartLabels(
  title: 'Arbeitszeit je Woche',
  value: 'Ist',
  reference: 'Soll',
  noData: 'keine Einträge',
  partial: 'läuft noch',
);

const _lineLabels = ChartLabels(
  title: 'Überstunden im Zeitraum',
  value: 'Summe',
  secondary: 'Woche',
  noData: 'keine Einträge',
  partial: 'läuft noch',
);

List<ChartPoint> _barPoints() => [
      _p(0, 38.5, refH: 40),
      _p(1, 41, refH: 40),
      _p(2, 0, refH: 0, hasData: false),
      _p(3, 36.5, refH: 40),
      _p(4, 22, refH: 24, partial: true),
    ];

List<ChartPoint> _linePoints() => [
      _p(0, -1.5, secH: -1.5),
      _p(1, -4, secH: -2.5),
      _p(2, -4, secH: 0, hasData: false),
      _p(3, -27, secH: -23),
      _p(4, -29, secH: -2, partial: true),
    ];

Future<void> _pump(WidgetTester tester, Widget chart,
    {double width = 360, bool dark = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(child: chart),
      ),
    ),
  ));
  await tester.pump();
}

String _detail(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('trend-detail'))).data!;

void main() {
  group('TrendBarChart (#531)', () {
    testWidgets('Detailzeile zeigt zuerst den laufenden Zeitraum', (t) async {
      await _pump(
          t,
          TrendBarChart(
              points: _barPoints(),
              labels: _barLabels,
              formatValue: formatDurationHm));
      expect(
          _detail(t), 'KW 44 · Woche 4 (läuft noch): Ist 22:00 · Soll 24:00');
      expect(t.takeException(), isNull);
    });

    testWidgets('Antippen eines Balkens füllt die Detailzeile', (t) async {
      await _pump(
          t,
          TrendBarChart(
              points: _barPoints(),
              labels: _barLabels,
              formatValue: formatDurationHm));
      await t.tap(find.byKey(const ValueKey('trend-slot-k1')));
      await t.pump();
      expect(_detail(t), 'KW 41 · Woche 1: Ist 41:00 · Soll 40:00');
    });

    testWidgets('Lücke: kein 0-Balken mit Soll, sondern „keine Einträge“',
        (t) async {
      await _pump(
          t,
          TrendBarChart(
              points: _barPoints(),
              labels: _barLabels,
              formatValue: formatDurationHm));
      await t.tap(find.byKey(const ValueKey('trend-slot-k2')));
      await t.pump();
      expect(_detail(t), 'KW 42 · Woche 2: keine Einträge');
      // Legende erklärt Lücke und laufenden Zeitraum (nicht nur über Farbe).
      expect(find.text('keine Einträge'), findsOneWidget);
      expect(find.text('läuft noch'), findsOneWidget);
      expect(find.text('Soll'), findsOneWidget);
    });

    testWidgets('Semantik: jeder Zeitraum ist ein eigenes Element', (t) async {
      final handle = t.ensureSemantics();
      await _pump(
          t,
          TrendBarChart(
              points: _barPoints(),
              labels: _barLabels,
              formatValue: formatDurationHm));
      expect(find.bySemanticsLabel('Arbeitszeit je Woche'), findsOneWidget);
      expect(find.bySemanticsLabel('KW 40 · Woche 0: Ist 38:30 · Soll 40:00'),
          findsOneWidget);
      expect(find.bySemanticsLabel('KW 42 · Woche 2: keine Einträge'),
          findsOneWidget);
      expect(
          find.bySemanticsLabel(
              'KW 44 · Woche 4 (läuft noch): Ist 22:00 · Soll 24:00'),
          findsOneWidget);
      final node = t.getSemantics(find.byKey(const ValueKey('trend-slot-k1')));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('Achse: Stunden mit „schönen“ Schritten', (t) async {
      await _pump(
          t,
          TrendBarChart(
              points: _barPoints(),
              labels: _barLabels,
              formatValue: formatDurationHm));
      for (final l in ['0 h', '10 h', '20 h', '30 h', '40 h', '50 h']) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
    });

    testWidgets('12 Zeiträume auf 320 px: ausgedünnt, jüngster beschriftet',
        (t) async {
      final points = [
        for (var i = 0; i < 12; i++) _p(i, 40, refH: 40, partial: i == 11),
      ];
      await _pump(
          t,
          TrendBarChart(
              points: points,
              labels: _barLabels,
              formatValue: formatDurationHm),
          width: 320);
      expect(t.takeException(), isNull);
      expect(find.text('KW 51'), findsOneWidget);
      expect(find.text('KW 50'), findsNothing);
      expect(
          find.text('KW 40').evaluate().length +
              find.text('KW 41').evaluate().length,
          lessThan(2));
    });

    testWidgets('Dunkelmodus rendert ohne Fehler', (t) async {
      await _pump(
          t,
          TrendBarChart(
              points: _barPoints(),
              labels: _barLabels,
              formatValue: formatDurationHm),
          dark: true);
      expect(t.takeException(), isNull);
    });
  });

  group('TrendLineChart (#531)', () {
    testWidgets('negative Werte: Achse mit Vorzeichen, Nulllinie oben',
        (t) async {
      await _pump(
          t,
          TrendLineChart(
              points: _linePoints(),
              labels: _lineLabels,
              formatValue: formatSignedDurationHm));
      expect(t.takeException(), isNull);
      for (final l in ['0 h', '-10 h', '-20 h', '-30 h']) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      expect(find.text('+10 h'), findsNothing);
      expect(_detail(t),
          'KW 44 · Woche 4 (läuft noch): Summe -29:00 · Woche -02:00');
    });

    testWidgets('Lücke: Summe bleibt ablesbar, dazu „keine Einträge“',
        (t) async {
      await _pump(
          t,
          TrendLineChart(
              points: _linePoints(),
              labels: _lineLabels,
              formatValue: formatSignedDurationHm));
      await t.tap(find.byKey(const ValueKey('trend-slot-k2')));
      await t.pump();
      expect(_detail(t), 'KW 42 · Woche 2: Summe -04:00 · keine Einträge');
      expect(find.text('keine Einträge'), findsOneWidget);
      expect(find.text('läuft noch'), findsOneWidget);
    });

    testWidgets('Semantik je Zeitraum', (t) async {
      final handle = t.ensureSemantics();
      await _pump(
          t,
          TrendLineChart(
              points: _linePoints(),
              labels: _lineLabels,
              formatValue: formatSignedDurationHm));
      expect(find.bySemanticsLabel('Überstunden im Zeitraum'), findsOneWidget);
      expect(
          find.bySemanticsLabel('KW 41 · Woche 1: Summe -04:00 · Woche -02:30'),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('Dunkelmodus rendert ohne Fehler', (t) async {
      await _pump(
          t,
          TrendLineChart(
              points: _linePoints(),
              labels: _lineLabels,
              formatValue: formatSignedDurationHm),
          dark: true);
      expect(t.takeException(), isNull);
    });
  });
}
