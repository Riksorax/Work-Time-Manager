import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/utils/chart_scale.dart';

const _h = 3600000;
const _m = 60000;

List<int> hours(List<num> v) => [for (final x in v) (x * _h).round()];

/// Schöne Schrittweiten (Stunden): 0:15, 0:30, dann 1, 2, 2,5, 5 × 10ⁿ.
bool isNiceStep(int stepMs) {
  if (stepMs == 15 * _m || stepMs == 30 * _m) return true;
  var mag = _h;
  while (mag <= stepMs) {
    for (final f in [1.0, 2.0, 2.5, 5.0]) {
      if ((f * mag).round() == stepMs) return true;
    }
    mag *= 10;
  }
  return false;
}

void expectValid(ChartScale s, List<int> values) {
  expect(s.ticks.length, inInclusiveRange(4, 6), reason: '$s');
  expect(s.ticks, contains(0), reason: '$s');
  expect(isNiceStep(s.step), isTrue, reason: '$s');
  expect(s.ticks.first, s.min);
  expect(s.ticks.last, s.max);
  for (var i = 1; i < s.ticks.length; i++) {
    expect(s.ticks[i] - s.ticks[i - 1], s.step);
  }
  for (final v in values) {
    expect(v, inInclusiveRange(s.min, s.max), reason: '$v in $s');
  }
}

void main() {
  group('niceHourScale (#531)', () {
    test('Wochen-Arbeitszeit inkl. Soll: 0 bis 50 h in 10-h-Schritten', () {
      final v = hours([38.5, 41, 40, 44, 22, 24]);
      final s = niceHourScale(v);
      expectValid(s, v);
      expect(s.ticks, hours([0, 10, 20, 30, 40, 50]));
    });

    test('Monats-Arbeitszeit: 0 bis 200 h in 50-h-Schritten', () {
      final v = hours([168, 175, 86, 120]);
      final s = niceHourScale(v);
      expectValid(s, v);
      expect(s.ticks, hours([0, 50, 100, 150, 200]));
    });

    test('nah am größten Wert: die Skala endet höchstens einen Schritt darüber',
        () {
      for (final max in [1, 3, 7, 9.5, 13, 27, 44, 61, 99, 168, 333, 999]) {
        final v = hours([max]);
        final s = niceHourScale(v);
        expectValid(s, v);
        expect(s.max - v.first, lessThan(s.step), reason: '$max h: $s');
      }
    });

    test('2,5er-Schritt wird genutzt', () {
      final v = hours([12]);
      final s = niceHourScale(v);
      expectValid(s, v);
      expect(s.step, (2.5 * _h).round());
      expect(s.ticks, hours([0, 2.5, 5, 7.5, 10, 12.5]));
    });

    test('alle Werte 0 und leere Liste: gültige Skala ab 0', () {
      for (final v in [
        <int>[],
        hours([0, 0, 0])
      ]) {
        final s = niceHourScale(v);
        expectValid(s, v);
        expect(s.min, 0);
        expect(s.max, greaterThan(0));
      }
    });

    test('nur negative Werte: Skala endet bei 0, Teilstriche negativ', () {
      final v = hours([-1.5, -4, -0.5, -27]);
      final s = niceHourScale(v);
      expectValid(s, v);
      expect(s.max, 0);
      expect(s.min, lessThan(0));
      expect(s.ticks, hours([-30, -20, -10, 0]));
    });

    test('kleine negative Werte: mindestens vier Teilstriche nach unten', () {
      final v = hours([-0.1]);
      final s = niceHourScale(v);
      expectValid(s, v);
      expect(s.max, 0);
    });

    test('gemischte Vorzeichen: 0 liegt auf einem Teilstrich', () {
      final v = hours([-4, -0.5, 1.5, 2]);
      final s = niceHourScale(v);
      expectValid(s, v);
      expect(s.ticks, hours([-4, -2, 0, 2]));
    });

    test('sehr große Werte bleiben ganzzahlig und schön', () {
      final v = hours([123456789]);
      final s = niceHourScale(v);
      expectValid(s, v);
    });

    test('Ausreißer: Skala reicht bis zum Ausreißer, weiterhin 4–6 Striche',
        () {
      final v = hours([40, 38, 41, 950]);
      final s = niceHourScale(v);
      expectValid(s, v);
      expect(s.max, 1000 * _h);
    });

    test('sehr kleine Werte: Schritt 15 Minuten', () {
      final v = [10 * _m];
      final s = niceHourScale(v);
      expectValid(s, v);
      expect(s.step, 15 * _m);
    });
  });

  group('formatAxisHours', () {
    test('ganze und halbe Stunden', () {
      expect(formatAxisHours(40 * _h), '40 h');
      expect(formatAxisHours(0), '0 h');
      expect(formatAxisHours((2.5 * _h).round()), '2:30 h');
      expect(formatAxisHours(15 * _m), '0:15 h');
    });

    test('mit Vorzeichen; 0 ohne', () {
      expect(formatAxisHours(10 * _h, signed: true), '+10 h');
      expect(formatAxisHours(-5 * _h, signed: true), '-5 h');
      expect(formatAxisHours(-5 * _h), '-5 h');
      expect(formatAxisHours(0, signed: true), '0 h');
    });
  });

  group('Achsenbeschriftung ausdünnen', () {
    test('genug Platz: alle', () {
      expect(axisLabelStep(12, 600, 40), 1);
    });

    test('schmale Breite: jede zweite bzw. dritte, der jüngste bleibt', () {
      final step = axisLabelStep(12, 250, 40);
      expect(step, 2);
      expect(showAxisLabel(11, 12, step), isTrue);
      expect(showAxisLabel(10, 12, step), isFalse);
      expect(showAxisLabel(9, 12, step), isTrue);
      expect(axisLabelStep(12, 150, 40), 4);
    });

    test('Randfälle', () {
      expect(axisLabelStep(1, 10, 100), 1);
      expect(axisLabelStep(12, 0, 40), 1);
    });
  });
}
