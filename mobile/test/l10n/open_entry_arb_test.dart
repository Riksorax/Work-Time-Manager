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
    // Fortsetzen kommt erst mit PR 1b.
    expect(deKeys, isNot(contains('openEntryContinue')));
  });
}
