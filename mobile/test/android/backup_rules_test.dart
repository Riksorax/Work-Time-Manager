import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regressionsschutz für #375: Die Dateien von `flutter_secure_storage` dürfen
/// nicht ins Android-Backup (der Keystore-Schlüssel wird nie gesichert, ein
/// zurückgespielter Datensatz wäre unlesbar und würde Sperr-Werte auf fremde
/// Geräte tragen), die übrigen Einstellungen (`FlutterSharedPreferences.xml`)
/// müssen dagegen im Backup bleiben.
///
/// Prüft nur die Liste, nicht die reale Datei des Plugins: bei einem
/// Plugin-Update die Namen im Gerätetest gegenprüfen
/// (`adb shell run-as <pkg> ls shared_prefs`, siehe `mobile/CLAUDE.md`).
void main() {
  const secureFiles = [
    'FlutterSecureStorage.xml',
    'FlutterSecureKeyStorage.xml',
    'FlutterSecureStorageConfiguration.xml',
    'FlutterSecureStorageConfiguration:FlutterSecureStorage.xml',
  ];
  const res = 'android/app/src/main/res/xml';

  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path fehlt');
    return file.readAsStringSync();
  }

  /// Pfade der `<exclude domain="sharedpref" .../>`-Einträge innerhalb von
  /// `<section>…</section>`.
  Set<String> sharedPrefExcludes(String xml, String section) {
    final block =
        RegExp('<$section>(.*?)</$section>', dotAll: true).firstMatch(xml);
    expect(block, isNotNull, reason: '<$section> fehlt');
    final result = <String>{};
    for (final m in RegExp(r'<exclude\s+([^>]*?)/>', dotAll: true)
        .allMatches(block!.group(1)!)) {
      final attrs = m.group(1)!;
      final domain = RegExp(r'domain="([^"]*)"').firstMatch(attrs)?.group(1);
      final path = RegExp(r'path="([^"]*)"').firstMatch(attrs)?.group(1);
      if (domain == 'sharedpref' && path != null) result.add(path);
    }
    return result;
  }

  void expectExcluded(Set<String> excludes) {
    for (final name in secureFiles) {
      expect(excludes, contains(name));
    }
    expect(excludes, isNot(contains('FlutterSharedPreferences.xml')),
        reason: 'Einstellungen und lokale Einträge müssen im Backup bleiben');
    expect(excludes.length, secureFiles.length,
        reason: 'unerwartete weitere Ausschlüsse');
  }

  test('data_extraction_rules.xml (API 31+): Cloud-Backup und Gerätetransfer',
      () {
    final xml = read('$res/data_extraction_rules.xml');
    expect(xml, contains('<data-extraction-rules>'));
    expectExcluded(sharedPrefExcludes(xml, 'cloud-backup'));
    expectExcluded(sharedPrefExcludes(xml, 'device-transfer'));
  });

  test('backup_rules.xml (API <= 30): Full-Backup', () {
    final xml = read('$res/backup_rules.xml');
    expectExcluded(sharedPrefExcludes(xml, 'full-backup-content'));
  });

  test('Manifest verweist auf beide Regeln und lässt Backup grundsätzlich an',
      () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final application =
        RegExp(r'<application\b([^>]*)>', dotAll: true).firstMatch(manifest);
    expect(application, isNotNull);
    final attrs = application!.group(1)!;
    expect(attrs,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
    expect(attrs, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(attrs, isNot(contains('android:allowBackup="false"')),
        reason: 'sonst gingen auch die Einstellungen im Backup verloren');
  });
}
