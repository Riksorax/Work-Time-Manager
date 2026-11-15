import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression #287 (Teil B): „Wochen-Trend“ ist jetzt eine aktive Abfrage und
/// darf nie den Timer stoppen. `AssistantTimerIntent.map` prüft mit
/// „enthält“, und das Stop-Wort „end“ steckt in „Tr**end**“.
///
/// Für `mobile/android/app/` gibt es keinen JVM-Testaufbau; der Emulator-Test
/// (`tool/android_e2e/run.sh`) prüft die echte Abbildung. Dieser Test liest
/// die Regeln aus der Kotlin-Datei (Reihenfolge der `if (has(...))`-Zeilen in
/// `map`) und spielt den Abgleich in derselben Reihenfolge nach. Er liest nur
/// Dateien, ohne Datum und Zeitzone.
void main() {
  const path =
      'android/app/src/main/kotlin/app/work_time_manager/AssistantTimerIntent.kt';

  /// Regeln in Prüfreihenfolge: Stichwörter → Ergebnis-Konstante (bei der
  /// Pausen-Regel mit Unterregel `PAUSE_OR_RESUME`).
  List<(List<String>, String)> rules() {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path nicht gefunden');
    final source = file.readAsStringSync();
    final start = source.indexOf('fun map(');
    expect(start, isNonNegative, reason: 'map() nicht gefunden');
    final body = source.substring(start);
    final rule = RegExp(
        // Nur Regeln am Zeilenanfang; die Unterregel der Pausen-Zeile
        // (`return if (has(...)) RESUME`) gehört zur Pausen-Regel.
        r'^\s*if \(has\(([^)]*)\)\)\s*\{?\s*(?:return\s+([A-Z_]+))?',
        multiLine: true);
    final result = <(List<String>, String)>[];
    for (final m in rule.allMatches(body)) {
      final words = RegExp(r'"([^"]*)"')
          .allMatches(m.group(1)!)
          .map((w) => w.group(1)!)
          .toList();
      result.add((words, m.group(2) ?? 'PAUSE_OR_RESUME'));
    }
    return result;
  }

  String? map(String feature) {
    final text = feature.toLowerCase().trim();
    if (text.isEmpty) return null;
    for (final (words, id) in rules()) {
      // Pause/Weiter wird nicht weiter unterschieden (`PAUSE_OR_RESUME`).
      if (words.any(text.contains)) return id;
    }
    return null;
  }

  test('Regeln werden gefunden, Abfragen vor den Timer-Wörtern', () {
    final r = rules();
    final ids = r.map((e) => e.$2).toList();
    expect(ids, contains('QUERY_TREND'));
    expect(ids, contains('STOP'));
    expect(
        ids.indexOf('QUERY_TREND'), lessThan(ids.indexOf('PAUSE_OR_RESUME')));
    expect(ids.indexOf('QUERY_TREND'), lessThan(ids.indexOf('STOP')));
    expect(r.firstWhere((e) => e.$2 == 'STOP').$1, contains('end'),
        reason: 'Voraussetzung des Tests: „end“ ist ein Stop-Wort');
  });

  for (final phrase in [
    'Wochen-Trend',
    'wochen-trend',
    'Wochentrend',
    'Zeig mir meinen Wochen-Trend',
    'weekly trend',
    'Weekly Trend',
    'Trend',
  ]) {
    test('„$phrase“ ist die Trend-Abfrage, nie Stop/Pause', () {
      expect(map(phrase), 'QUERY_TREND');
    });
  }

  for (final (phrase, id) in [
    ('Arbeitstag beenden', 'STOP'),
    ('Feierabend', 'STOP'),
    ('clock out', 'STOP'),
    ('Arbeitstag starten', 'START'),
    ('Überstunden', 'QUERY_OVERTIME'),
    ('Resturlaub', 'QUERY_LEAVE'),
  ]) {
    test('„$phrase“ bleibt $id', () {
      expect(map(phrase), id);
    });
  }
}
