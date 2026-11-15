/// Reine Hilfen für die Diagramme der Trend-Ansicht (#531): Skala mit
/// „schönen“ Teilstrichen, Achsenbeschriftung in Stunden und Ausdünnen der
/// Zeitraum-Beschriftungen. Keine Fachlogik: die Werte kommen fertig vom
/// Backend, hier wird nur skaliert und beschriftet. Alle Werte in ms.
library;

import 'dart:math' as math;

const int _minuteMs = 60 * 1000;
const int _hourMs = 60 * _minuteMs;

/// Lineare Skala einer Wertachse. [ticks] enthält immer 0 und liegt mit
/// gleichem Abstand [step] von [min] bis [max] (beide eingeschlossen).
class ChartScale {
  final int min;
  final int max;
  final int step;
  final List<int> ticks;

  const ChartScale({
    required this.min,
    required this.max,
    required this.step,
    required this.ticks,
  });

  @override
  String toString() => 'ChartScale($min..$max, step $step, $ticks)';
}

/// Kleinste mögliche Schrittweite: 15 Minuten.
const int _minStepMs = 15 * _minuteMs;

/// Schrittweiten in ms: 0:15 h, 0:30 h, danach 1, 2, 2,5 und 5 × 10ⁿ Stunden.
Iterable<int> _candidateSteps() sync* {
  yield _minStepMs;
  yield 2 * _minStepMs;
  for (var mag = _hourMs; mag > 0 && mag < (1 << 52); mag *= 10) {
    yield mag;
    yield 2 * mag;
    yield (2.5 * mag).round();
    yield 5 * mag;
  }
}

int _floorTo(int v, int step) => (v / step).floor() * step;
int _ceilTo(int v, int step) => (v / step).ceil() * step;

/// Skala für [valuesMs] mit 4 bis 6 Teilstrichen (3 bis 5 Abschnitte), die 0
/// immer enthält (Balken und Nulllinie) und so nah wie möglich am größten
/// bzw. kleinsten Wert endet.
///
/// Robust für eine leere Liste und nur Nullen (0 bis 0:45 h), nur negative
/// Werte (Skala endet bei 0), sehr große Werte und Ausreißer (die Skala
/// reicht dann bis zum Ausreißer, die übrigen Werte bleiben ablesbar klein).
ChartScale niceHourScale(Iterable<int> valuesMs) {
  var lo = 0;
  var hi = 0;
  for (final v in valuesMs) {
    lo = math.min(lo, v);
    hi = math.max(hi, v);
  }

  var step = _minStepMs;
  var min = 0;
  var max = 0;
  for (final s in _candidateSteps()) {
    step = s;
    min = _floorTo(lo, s);
    max = _ceilTo(hi, s);
    if ((max - min) ~/ s <= 5) break;
  }

  // Mindestens drei Abschnitte (vier Teilstriche): bei sehr kleinen Werten
  // nach oben, bei nur negativen nach unten erweitern.
  while ((max - min) ~/ step < 3) {
    if (max > 0 || min == 0) {
      max += step;
    } else {
      min -= step;
    }
  }

  return ChartScale(
    min: min,
    max: max,
    step: step,
    ticks: [for (var t = min; t <= max; t += step) t],
  );
}

/// Achsenbeschriftung in Stunden: „40 h“, „2:30 h“; mit [signed] „+10 h“ bzw.
/// „-5 h“ (0 ohne Vorzeichen).
String formatAxisHours(int ms, {bool signed = false}) {
  final sign = ms > 0
      ? (signed ? '+' : '')
      : ms < 0
          ? '-'
          : '';
  final abs = ms.abs();
  final h = abs ~/ _hourMs;
  final m = (abs % _hourMs) ~/ _minuteMs;
  if (m == 0) return '$sign$h h';
  return '$sign$h:${m.toString().padLeft(2, '0')} h';
}

/// Jede wievielte Zeitraum-Beschriftung gezeigt wird, damit sich die
/// Beschriftungen nicht überlappen (1 = alle). Gezeigt werden die Indizes, für
/// die [showAxisLabel] `true` liefert, also immer der jüngste Zeitraum.
int axisLabelStep(int count, double plotWidth, double labelWidth) {
  if (count <= 1 || plotWidth <= 0) return 1;
  final slot = plotWidth / count;
  return math.max(1, (labelWidth / slot).ceil());
}

/// Ob die Beschriftung des Zeitraums [index] (0 = ältester) bei Schritt
/// [step] gezeigt wird; der letzte (jüngste) Zeitraum immer.
bool showAxisLabel(int index, int count, int step) =>
    (count - 1 - index) % step == 0;
