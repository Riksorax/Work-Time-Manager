import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> load(String name) =>
      json.decode(File('lib/l10n/$name.arb').readAsStringSync())
          as Map<String, dynamic>;

  test('openEntry*-Keys: de und en haben dieselben Keys, de mit Beschreibung',
      () {
    final de = load('app_de');
    final en = load('app_en');
    final deKeys = de.keys.where((k) => k.startsWith('openEntry')).toSet();
    final enKeys = en.keys.where((k) => k.startsWith('openEntry')).toSet();
    expect(deKeys, isNotEmpty);
    expect(enKeys, deKeys);
    for (final k in deKeys) {
      expect((de['@$k'] as Map<String, dynamic>)['description'], isNotEmpty,
          reason: '@$k braucht eine Beschreibung');
    }
    // Fortsetzen (PR 1b).
    expect(deKeys,
        containsAll(['openEntryContinue', 'openEntryContinueSemantics']));
  });

  test('openEntryContinue*: Texte und Platzhalter date', () {
    final de = load('app_de');
    final en = load('app_en');
    expect(de['openEntryContinue'], 'Fortsetzen');
    expect(en['openEntryContinue'], 'Continue');
    for (final arb in [de, en]) {
      expect(arb['openEntryContinueSemantics'], contains('{date}'));
    }
    final meta = de['@openEntryContinueSemantics'] as Map<String, dynamic>;
    expect((meta['placeholders'] as Map<String, dynamic>).keys, ['date']);
  });
}
