import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Schützt die Verdrahtung des Brandings (#437): In-App-Logo, Pubspec,
/// Notification-Icon und R8-keep-Eintrag (Regression wie #335).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('In-App-Logo 256 px ist als Asset gebündelt und ein gültiges PNG',
      () async {
    final data = await rootBundle.load('assets/icon/app_logo_256.png');
    final bytes = data.buffer.asUint8List();
    // PNG-Signatur, Breite/Höhe aus dem IHDR-Chunk.
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final header = ByteData.sublistView(bytes);
    expect(header.getUint32(16), 256);
    expect(header.getUint32(20), 256);
  });

  test('pubspec.yaml verweist nicht mehr auf das alte Logo', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('WorkTimeManagerLogo')));
    expect(pubspec, contains('assets/icon/app_logo_256.png'));
  });

  test('flutter_launcher_icons liegt in dev_dependencies, ohne web-Block', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dev = pubspec.indexOf('dev_dependencies:');
    final dep = pubspec.indexOf('flutter_launcher_icons: ^');
    expect(dev, isNonNegative);
    expect(dep, greaterThan(dev));
    final config = pubspec.substring(
      pubspec.indexOf('\nflutter_launcher_icons:'),
      pubspec.indexOf('\nflutter:'),
    );
    expect(config, isNot(contains('web:')));
    expect(config, contains('adaptive_icon_monochrome'));
  });

  test('Notification-Icon: Dart-Name und keep.xml stimmen überein', () {
    final dart =
        File('lib/core/services/notification_service.dart').readAsStringSync();
    final keep =
        File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
    expect(
      dart,
      contains("AndroidInitializationSettings('@drawable/ic_notification')"),
    );
    expect(keep, contains('@drawable/ic_notification'));
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(
        File('android/app/src/main/res/drawable-$d/ic_notification.png')
            .existsSync(),
        isTrue,
        reason: 'ic_notification fehlt in drawable-$d',
      );
    }
  });

  test('Adaptives Icon enthält Hintergrund, Vordergrund und Monochrom', () {
    final xml =
        File('android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml')
            .readAsStringSync();
    expect(xml, contains('<monochrome'));
    expect(xml, contains('<foreground'));
    expect(xml, contains('<background'));
    // flutter_launcher_icons fügt <inset> wieder ein; das Icon wirkt dann zu klein.
    expect(xml, isNot(contains('<inset')));
  });
}
