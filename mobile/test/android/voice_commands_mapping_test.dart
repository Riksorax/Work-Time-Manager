import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/voice_commands_page.dart';

/// #584: Die Beispiel-Befehle der Hilfeseite „Sprachbefehle“ müssen genau die
/// Aktion auslösen, die die Seite verspricht.
///
/// Wie `assistant_intent_mapping_test.dart` liest der Test die Regeln aus
/// `AssistantTimerIntent.map` (Reihenfolge der `if (has(...))`-Zeilen) und
/// spielt den Abgleich nach, hier zusätzlich mit der Unterscheidung Pause
/// starten/beenden (`return if (has(...)) RESUME else PAUSE`). Die Texte
/// kommen aus den ARB-Dateien (de und en), so wie die Seite sie zeigt. Nur
/// Dateien, ohne Datum und Zeitzone.
void main() {
  const path =
      'android/app/src/main/kotlin/app/work_time_manager/AssistantTimerIntent.kt';

  List<String> words(String args) =>
      RegExp(r'"([^"]*)"').allMatches(args).map((w) => w.group(1)!).toList();

  late String body;
  setUpAll(() {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path nicht gefunden');
    final source = file.readAsStringSync();
    final start = source.indexOf('fun map(');
    expect(start, isNonNegative, reason: 'map() nicht gefunden');
    body = source.substring(start);
  });

  /// Nachbau von `map`: liefert den Namen der Kotlin-Konstante.
  String? map(String feature) {
    final text = feature.toLowerCase().trim();
    if (text.isEmpty) return null;
    final rule = RegExp(
        r'^\s*if \(has\(([^)]*)\)\)\s*\{?\s*(?:return\s+([A-Z_]+))?',
        multiLine: true);
    final sub = RegExp(
        r'return if \(has\(([^)]*)\)\)\s*([A-Z_]+)\s*else\s*([A-Z_]+)',
        multiLine: true);
    for (final m in rule.allMatches(body)) {
      if (!words(m.group(1)!).any(text.contains)) continue;
      if (m.group(2) != null) return m.group(2);
      // Regel mit Unterregel (Pause): die nächste `return if`-Zeile danach.
      final s = sub.firstMatch(body.substring(m.end));
      expect(s, isNotNull, reason: 'Unterregel der Pausen-Regel fehlt');
      return words(s!.group(1)!).any(text.contains) ? s.group(2) : s.group(3);
    }
    return null;
  }

  test('Nachbau unterscheidet Pause starten und beenden', () {
    expect(map('Pause starten'), 'PAUSE');
    expect(map('Pause beenden'), 'RESUME');
    expect(map('Wochen-Trend'), 'QUERY_TREND');
    expect(map('leave work'), isNull);
  });

  for (final locale in ['de', 'en']) {
    final l10n = lookupAppLocalizations(Locale(locale));
    final timer = voiceTimerCommands(l10n).map((c) => c.$2).toList();
    final queries = voiceQueryCommands(l10n).map((c) => c.$2).toList();

    test('$locale: Timer-Befehle der Hilfeseite', () {
      expect(timer, hasLength(4));
      expect(timer.map(map).toList(), ['START', 'PAUSE', 'RESUME', 'STOP'],
          reason: timer.join(' | '));
    });

    test('$locale: Abfrage-Befehle der Hilfeseite', () {
      expect(queries, hasLength(3));
      expect(queries.map(map).toList(),
          ['QUERY_OVERTIME', 'QUERY_LEAVE', 'QUERY_TREND'],
          reason: queries.join(' | '));
    });
  }

  test('Wortlaut wie im Auftrag (#584)', () {
    final de = lookupAppLocalizations(const Locale('de'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
        [...voiceTimerCommands(de), ...voiceQueryCommands(de)].map((c) => c.$2),
        [
          'Arbeitstag starten',
          'Pause starten',
          'Pause beenden',
          'Feierabend',
          'Überstunden',
          'Resturlaub',
          'Wochen-Trend',
        ]);
    expect(
        [...voiceTimerCommands(en), ...voiceQueryCommands(en)].map((c) => c.$2),
        [
          'clock in',
          'start break',
          'end break',
          'clock out',
          'overtime',
          'remaining leave',
          'weekly trend',
        ]);
  });
}
