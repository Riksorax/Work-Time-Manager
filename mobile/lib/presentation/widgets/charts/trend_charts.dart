import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../domain/utils/chart_scale.dart';

/// Ein Zeitraum (Spalte) eines Diagramms. Dauern in ms, fertig vom Backend.
class ChartPoint {
  /// Stabiler Schlüssel (z. B. `2026-W45`).
  final String key;

  /// Kurze Achsenbeschriftung („KW 45“, „Nov.“).
  final String axisLabel;

  /// Volle Bezeichnung für Detailzeile und Screenreader
  /// („KW 45 · 2. Nov. – 8. Nov. 2026“, „November 2026“).
  final String label;

  /// Hauptwert (Balken bzw. Linienpunkt).
  final int valueMs;

  /// Vergleichswert; im Balkendiagramm das Soll (als Marke gezeichnet).
  final int? referenceMs;

  /// Zusatzwert nur für Detailzeile und Screenreader (Linie: Überstunden des
  /// einzelnen Zeitraums).
  final int? secondaryMs;

  /// `false`: keine Einträge, wird als Lücke gezeichnet.
  final bool hasData;

  /// Laufender, noch unvollständiger Zeitraum.
  final bool partial;

  const ChartPoint({
    required this.key,
    required this.axisLabel,
    required this.label,
    required this.valueMs,
    this.referenceMs,
    this.secondaryMs,
    required this.hasData,
    required this.partial,
  });
}

/// Übersetzte Beschriftungen eines Diagramms (vom Aufrufer).
class ChartLabels {
  /// Name des Diagramms (Screenreader).
  final String title;
  final String value;
  final String? reference;
  final String? secondary;

  /// Text für Zeiträume ohne Einträge.
  final String noData;

  /// Legende/Zusatz für den laufenden Zeitraum.
  final String partial;

  const ChartLabels({
    required this.title,
    required this.value,
    this.reference,
    this.secondary,
    required this.noData,
    required this.partial,
  });
}

typedef ChartValueFormatter = String Function(Duration value);

const double _plotHeight = 168;
const double _rightPad = 6;
const double _vPad = 8;
const double _axisFontSize = 11;
const int _hourMs = 3600000;

double _hours(int ms) => ms / _hourMs;

/// Balkendiagramm (#531): Arbeitszeit je Zeitraum als Balken, Soll als
/// waagerechte Marke über dem Balken. Lücke (`hasData = false`): gestrichelter
/// Rahmen an der Grundlinie statt eines 0-Balkens; laufender Zeitraum: heller
/// Balken mit gestricheltem Rand. Beides steht in der Legende.
class TrendBarChart extends StatelessWidget {
  final List<ChartPoint> points;
  final ChartLabels labels;
  final ChartValueFormatter formatValue;

  const TrendBarChart({
    super.key,
    required this.points,
    required this.labels,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final scale = niceHourScale([
      for (final p in points) ...[p.valueMs, if (p.hasData) p.referenceMs ?? 0],
    ]);
    final cs = Theme.of(context).colorScheme;
    return _ChartFrame(
      points: points,
      labels: labels,
      scale: scale,
      signedAxis: false,
      valueWithoutData: false,
      formatValue: formatValue,
      formatReference: formatValue,
      formatSecondary: formatValue,
      legend: [
        _LegendItem(_SwatchKind.bar, labels.value),
        if (labels.reference != null &&
            points.any((p) => p.hasData && (p.referenceMs ?? 0) > 0))
          _LegendItem(_SwatchKind.target, labels.reference!),
        if (points.any((p) => p.partial))
          _LegendItem(_SwatchKind.partialBar, labels.partial),
        if (points.any((p) => !p.hasData))
          _LegendItem(_SwatchKind.gap, labels.noData),
      ],
      chartBuilder: (context, plotWidth) {
        final n = points.length;
        final slot = n == 0 ? plotWidth : plotWidth / n;
        final barWidth = math.min(26.0, math.max(6.0, slot * 0.5));
        final span = _hours(scale.max - scale.min);
        // Halbe Markenhöhe bzw. Lückenhöhe in Stunden (≈ 1,5 bzw. 4 px).
        final markHalf = span / _plotHeight * 1.5;
        final gapHeight = span / _plotHeight * 4;
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            minY: _hours(scale.min),
            maxY: _hours(scale.max),
            barTouchData: BarTouchData(enabled: false),
            borderData: FlBorderData(show: false),
            gridData: _grid(scale, cs),
            titlesData: _titles(context, scale, signed: false),
            extraLinesData: _zeroLine(cs),
            barGroups: [
              for (var i = 0; i < n; i++)
                _group(i, points[i], barWidth, markHalf, gapHeight, cs),
            ],
          ),
          duration: Duration.zero,
        );
      },
    );
  }

  BarChartGroupData _group(int i, ChartPoint p, double barWidth,
      double markHalf, double gapHeight, ColorScheme cs) {
    final markWidth = barWidth + 4;
    final BarChartRodData main;
    if (!p.hasData) {
      main = BarChartRodData(
        toY: gapHeight,
        width: barWidth,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(1),
        borderSide: BorderSide(color: cs.onSurfaceVariant, width: 1.2),
        borderDashArray: const [3, 3],
      );
    } else if (p.partial) {
      main = BarChartRodData(
        toY: _hours(p.valueMs),
        width: barWidth,
        color: cs.primary.withValues(alpha: 0.32),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
        borderDashArray: const [4, 3],
      );
    } else {
      main = BarChartRodData(
        toY: _hours(p.valueMs),
        width: barWidth,
        color: cs.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      );
    }
    final ref = p.referenceMs ?? 0;
    final showMark = p.hasData && ref > 0;
    final refH = _hours(ref);
    return BarChartGroupData(
      x: i,
      groupVertically: true,
      barRods: [
        main,
        // Soll-Marke; ohne Soll unsichtbar, damit alle Gruppen gleich breit
        // sind (die Spaltenmitten bleiben dann exakt (i + 0,5) × Breite / n).
        BarChartRodData(
          fromY: showMark ? refH - markHalf : 0,
          toY: showMark ? refH + markHalf : 0,
          width: markWidth,
          color: showMark ? cs.onSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(1),
        ),
      ],
    );
  }
}

/// Liniendiagramm (#531) für vorzeichenbehaftete Werte (aufsummierte
/// Überstunden): Nulllinie hervorgehoben, Achse mit Vorzeichen. Zeitraum ohne
/// Einträge: hohler Punkt; das Stück zum laufenden Zeitraum ist gestrichelt.
class TrendLineChart extends StatelessWidget {
  final List<ChartPoint> points;
  final ChartLabels labels;
  final ChartValueFormatter formatValue;

  const TrendLineChart({
    super.key,
    required this.points,
    required this.labels,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final scale = niceHourScale([for (final p in points) p.valueMs]);
    final cs = Theme.of(context).colorScheme;
    // Füllung des hohlen Punkts = Kartenfarbe (M3: surfaceContainerLow).
    final hollowFill =
        Theme.of(context).cardTheme.color ?? cs.surfaceContainerLow;
    final n = points.length;
    final partialLast = n >= 2 && points.last.partial;
    final solidEnd = partialLast ? n - 1 : n;
    final spots = [
      for (var i = 0; i < n; i++)
        FlSpot(i.toDouble(), _hours(points[i].valueMs))
    ];

    FlDotPainter dot(FlSpot spot, double _, LineChartBarData __, int ___) {
      final p = points[spot.x.round()];
      if (!p.hasData) {
        return FlDotCirclePainter(
            radius: 3.5,
            color: hollowFill,
            strokeWidth: 1.8,
            strokeColor: cs.onSurfaceVariant);
      }
      return FlDotCirclePainter(radius: 3.5, color: cs.primary, strokeWidth: 0);
    }

    LineChartBarData bar(List<FlSpot> s,
            {List<int>? dash, bool Function(FlSpot)? showDot}) =>
        LineChartBarData(
          spots: s,
          color: cs.primary,
          barWidth: 2.5,
          dashArray: dash,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, _) => showDot?.call(spot) ?? true,
            getDotPainter: dot,
          ),
          belowBarData: BarAreaData(
            show: dash == null,
            color: cs.primary.withValues(alpha: 0.10),
            cutOffY: 0,
            applyCutOffY: true,
          ),
          aboveBarData: BarAreaData(
            show: dash == null,
            color: cs.primary.withValues(alpha: 0.10),
            cutOffY: 0,
            applyCutOffY: true,
          ),
        );

    return _ChartFrame(
      points: points,
      labels: labels,
      scale: scale,
      signedAxis: true,
      valueWithoutData: true,
      formatValue: formatValue,
      formatReference: formatValue,
      formatSecondary: formatValue,
      legend: [
        _LegendItem(_SwatchKind.line, labels.value),
        if (partialLast) _LegendItem(_SwatchKind.partialLine, labels.partial),
        if (points.any((p) => !p.hasData))
          _LegendItem(_SwatchKind.hollowDot, labels.noData),
      ],
      chartBuilder: (context, plotWidth) => LineChart(
        LineChartData(
          minX: -0.5,
          maxX: n - 0.5,
          minY: _hours(scale.min),
          maxY: _hours(scale.max),
          lineTouchData: const LineTouchData(enabled: false),
          borderData: FlBorderData(show: false),
          gridData: _grid(scale, cs),
          titlesData: _titles(context, scale, signed: true),
          extraLinesData: _zeroLine(cs),
          lineBarsData: [
            if (solidEnd > 0) bar(spots.sublist(0, solidEnd)),
            if (partialLast)
              bar(spots.sublist(n - 2),
                  dash: const [5, 4],
                  // Der erste Punkt gehört zur durchgezogenen Linie.
                  showDot: (s) => s.x.round() == n - 1),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

FlGridData _grid(ChartScale scale, ColorScheme cs) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: _hours(scale.step),
      getDrawingHorizontalLine: (_) =>
          FlLine(color: cs.outlineVariant, strokeWidth: 1),
    );

ExtraLinesData _zeroLine(ColorScheme cs) => ExtraLinesData(
      horizontalLines: [
        HorizontalLine(y: 0, color: cs.onSurfaceVariant, strokeWidth: 1.4),
      ],
    );

TextStyle _axisStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelSmall!.copyWith(
          fontSize: _axisFontSize,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w400,
        );

double _textWidth(BuildContext context, String text, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return tp.width;
}

double _textHeight(BuildContext context, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: 'KW 0', style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return tp.height.ceilToDouble();
}

double _leftReserved(BuildContext context, ChartScale scale, bool signed) {
  final style = _axisStyle(context);
  var w = 16.0;
  for (final t in scale.ticks) {
    w = math.max(
        w, _textWidth(context, formatAxisHours(t, signed: signed), style));
  }
  return w.ceilToDouble() + 8;
}

FlTitlesData _titles(BuildContext context, ChartScale scale,
    {required bool signed}) {
  final style = _axisStyle(context);
  const off = AxisTitles(sideTitles: SideTitles(showTitles: false));
  final pad = AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: _vPad,
      getTitlesWidget: (_, __) => const SizedBox.shrink(),
    ),
  );
  return FlTitlesData(
    // Leerer Rand oben/unten, damit die äußeren Achsenbeschriftungen mittig
    // auf ihrer Linie stehen können.
    topTitles: pad,
    rightTitles: off,
    bottomTitles: pad,
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: _leftReserved(context, scale, signed),
        interval: _hours(scale.step),
        getTitlesWidget: (value, meta) {
          final ms = (value * _hourMs).round();
          final tick = scale.ticks.where((t) => (t - ms).abs() < 1000);
          if (tick.isEmpty) return const SizedBox.shrink();
          return SideTitleWidget(
            meta: meta,
            space: 6,
            child:
                Text(formatAxisHours(tick.first, signed: signed), style: style),
          );
        },
      ),
    ),
  );
}

/// Gemeinsamer Rahmen beider Diagramme: Plotfläche mit Spalten zum Antippen
/// (je Zeitraum ein Screenreader-Element mit den Werten), ausgedünnte
/// Zeitraum-Beschriftung (der jüngste bleibt), Detailzeile und Legende.
class _ChartFrame extends StatefulWidget {
  final List<ChartPoint> points;
  final ChartLabels labels;
  final ChartScale scale;
  final bool signedAxis;

  /// Wert auch ohne Einträge zeigen (laufende Summe bleibt gültig).
  final bool valueWithoutData;
  final ChartValueFormatter formatValue;
  final ChartValueFormatter formatReference;
  final ChartValueFormatter formatSecondary;
  final List<_LegendItem> legend;
  final Widget Function(BuildContext context, double plotWidth) chartBuilder;

  const _ChartFrame({
    required this.points,
    required this.labels,
    required this.scale,
    required this.signedAxis,
    required this.valueWithoutData,
    required this.formatValue,
    required this.formatReference,
    required this.formatSecondary,
    required this.legend,
    required this.chartBuilder,
  });

  @override
  State<_ChartFrame> createState() => _ChartFrameState();
}

class _ChartFrameState extends State<_ChartFrame> {
  int? _selected;

  @override
  void didUpdateWidget(covariant _ChartFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sel = _selected;
    if (sel != null &&
        (sel >= widget.points.length ||
            oldWidget.points.length != widget.points.length ||
            oldWidget.points[sel].key != widget.points[sel].key)) {
      _selected = null;
    }
  }

  Duration _d(int ms) => Duration(milliseconds: ms);

  String _describe(ChartPoint p) {
    final l = widget.labels;
    final parts = <String>[];
    if (!p.hasData) {
      if (widget.valueWithoutData) {
        parts.add('${l.value} ${widget.formatValue(_d(p.valueMs))}');
      }
      parts.add(l.noData);
    } else {
      parts.add('${l.value} ${widget.formatValue(_d(p.valueMs))}');
      if (l.reference != null && p.referenceMs != null) {
        parts.add(
            '${l.reference} ${widget.formatReference(_d(p.referenceMs!))}');
      }
      if (l.secondary != null && p.secondaryMs != null) {
        parts.add(
            '${l.secondary} ${widget.formatSecondary(_d(p.secondaryMs!))}');
      }
    }
    final suffix = p.partial ? ' (${l.partial})' : '';
    return '${p.label}$suffix: ${parts.join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final n = points.length;
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final left = _leftReserved(context, widget.scale, widget.signedAxis);
    final axisStyle = _axisStyle(context);
    final active = _selected ?? (n - 1);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.labels.title,
      child: LayoutBuilder(builder: (context, constraints) {
        final plotWidth =
            math.max(constraints.maxWidth - left - _rightPad, 40.0);
        var longest = 0.0;
        for (final p in points) {
          longest =
              math.max(longest, _textWidth(context, p.axisLabel, axisStyle));
        }
        final every = axisLabelStep(n, plotWidth, longest + 6);

        Widget columns(Widget Function(int i) cell) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (var i = 0; i < n; i++) Expanded(child: cell(i))],
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _plotHeight + 2 * _vPad,
              child: Stack(
                children: [
                  // Hervorhebung der gewählten Spalte (hinter dem Diagramm).
                  Positioned(
                    left: left,
                    right: _rightPad,
                    top: _vPad,
                    bottom: _vPad,
                    child: columns((i) => i == _selected
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        : const SizedBox.shrink()),
                  ),
                  Positioned(
                    left: 0,
                    right: _rightPad,
                    top: 0,
                    bottom: 0,
                    child: ExcludeSemantics(
                        child: widget.chartBuilder(context, plotWidth)),
                  ),
                  // Tippflächen und Screenreader-Elemente je Zeitraum.
                  Positioned(
                    left: left,
                    right: _rightPad,
                    top: _vPad,
                    bottom: _vPad,
                    child: columns((i) => Semantics(
                          key: ValueKey('trend-slot-${points[i].key}'),
                          container: true,
                          button: true,
                          selected: i == _selected,
                          label: _describe(points[i]),
                          onTap: () => setState(() => _selected = i),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            excludeFromSemantics: true,
                            onTap: () => setState(() => _selected = i),
                          ),
                        )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.only(left: left, right: _rightPad),
                child: SizedBox(
                  height: _textHeight(context, axisStyle),
                  child: Row(
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: showAxisLabel(i, n, every)
                              ? OverflowBox(
                                  minWidth: 0,
                                  maxWidth: longest + 8,
                                  child: Text(
                                    points[i].axisLabel,
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                    style: axisStyle.copyWith(
                                      fontWeight: i == _selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (n > 0)
              ExcludeSemantics(
                child: Text(
                  _describe(points[active]),
                  key: const ValueKey('trend-detail'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  for (final item in widget.legend)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: const Size(18, 12),
                          painter: _SwatchPainter(item.kind, cs),
                        ),
                        const SizedBox(width: 5),
                        Text(item.text,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

enum _SwatchKind { bar, target, partialBar, gap, line, partialLine, hollowDot }

class _LegendItem {
  final _SwatchKind kind;
  final String text;
  const _LegendItem(this.kind, this.text);
}

class _SwatchPainter extends CustomPainter {
  final _SwatchKind kind;
  final ColorScheme cs;

  _SwatchPainter(this.kind, this.cs);

  void _dashedLine(Canvas c, Offset a, Offset b, Paint p,
      {double dash = 3, double gap = 2.5}) {
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var t = 0.0;
    while (t < total) {
      final e = math.min(t + dash, total);
      c.drawLine(a + dir * t, a + dir * e, p);
      t = e + gap;
    }
  }

  void _dashedRect(Canvas c, Rect r, Paint p) {
    _dashedLine(c, r.topLeft, r.topRight, p);
    _dashedLine(c, r.topRight, r.bottomRight, p);
    _dashedLine(c, r.bottomRight, r.bottomLeft, p);
    _dashedLine(c, r.bottomLeft, r.topLeft, p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint()..style = PaintingStyle.fill;
    final midY = size.height / 2;
    final bar = Rect.fromLTWH(4, 1, size.width - 8, size.height - 2);
    switch (kind) {
      case _SwatchKind.bar:
        canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(2)),
            fill..color = cs.primary);
      case _SwatchKind.target:
        canvas.drawRect(Rect.fromLTWH(1, midY - 1.5, size.width - 2, 3),
            fill..color = cs.onSurface);
      case _SwatchKind.partialBar:
        canvas.drawRect(bar, fill..color = cs.primary.withValues(alpha: 0.32));
        _dashedRect(canvas, bar, stroke..color = cs.primary);
      case _SwatchKind.gap:
        _dashedRect(
            canvas,
            Rect.fromLTWH(4, size.height - 5, size.width - 8, 4),
            stroke
              ..color = cs.onSurfaceVariant
              ..strokeWidth = 1.2);
      case _SwatchKind.line:
        canvas.drawLine(
            Offset(1, midY),
            Offset(size.width - 1, midY),
            stroke
              ..color = cs.primary
              ..strokeWidth = 2.5);
        canvas.drawCircle(
            Offset(size.width / 2, midY), 3.5, fill..color = cs.primary);
      case _SwatchKind.partialLine:
        _dashedLine(
            canvas,
            Offset(1, midY),
            Offset(size.width - 1, midY),
            stroke
              ..color = cs.primary
              ..strokeWidth = 2.5,
            dash: 4,
            gap: 3);
      case _SwatchKind.hollowDot:
        canvas.drawCircle(Offset(size.width / 2, midY), 3.5,
            fill..color = cs.surfaceContainerLow);
        canvas.drawCircle(
            Offset(size.width / 2, midY),
            3.5,
            stroke
              ..color = cs.onSurfaceVariant
              ..strokeWidth = 1.8);
    }
  }

  @override
  bool shouldRepaint(covariant _SwatchPainter old) =>
      old.kind != kind || old.cs != cs;
}
