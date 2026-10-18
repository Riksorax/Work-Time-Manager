import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression #467: Eine Consumer-Regel mit `-dontoptimize` (purchases-store-amazon,
/// transitiv über purchases_flutter) schaltet die R8-Optimierung ab. Der Test liest
/// nur Dateien, ohne Datum und Zeitzone.
void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path nicht gefunden');
    return file.readAsStringSync();
  }

  const workflowPath = '../.github/workflows/flutter-production.yml';

  test('build.gradle schließt purchases-store-amazon aus', () {
    final gradle = read('android/app/build.gradle');
    expect(
      gradle,
      matches(
        RegExp(
          r"exclude\s+group:\s*'com\.revenuecat\.purchases',\s*"
          r"module:\s*'purchases-store-amazon'",
        ),
      ),
    );
  });

  test('eigene Regeldateien enthalten kein -dontoptimize', () {
    final files = <String>[
      'android/app/proguard-rules.pro',
      'android/app/src/main/res/raw/keep.xml',
    ];
    for (final path in files) {
      if (!File(path).existsSync()) continue;
      expect(
        RegExp(
          r'^\s*-dontoptimize',
          multiLine: true,
        ).hasMatch(File(path).readAsStringSync()),
        isFalse,
        reason: path,
      );
    }
  });

  test('flutter-production.yml prüft configuration.txt auf -dontoptimize', () {
    final workflow = read(workflowPath);
    expect(workflow, contains('mapping/release/configuration.txt'));
    expect(workflow, contains('-dontoptimize'));
    // Der Guard steht vor dem Play-Upload und bricht mit exit 1 ab.
    final guard = workflow.indexOf('R8 optimization must not be disabled');
    final upload = workflow.indexOf('Upload to Google Play');
    expect(guard, greaterThan(-1));
    expect(upload, greaterThan(guard));
    expect(workflow.substring(guard, upload), contains('exit 1'));
  });

  test('Mapping-Artefakt ist Pflicht, R8-Diagnose wird archiviert', () {
    final workflow = read(workflowPath);
    final start = workflow.indexOf('Upload R8 mapping Artifact');
    expect(start, greaterThan(-1));
    final end = workflow.indexOf('- name:', start + 1);
    expect(
        workflow.substring(start, end), contains('if-no-files-found: error'));
    expect(workflow, contains('mapping/release/seeds.txt'));
    expect(workflow, contains('mapping/release/usage.txt'));
  });
}
