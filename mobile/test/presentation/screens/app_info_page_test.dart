import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/screens/app_info_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Absicherung des Updates auf package_info_plus 10 (#375): die Info-Seite
/// liest Version und Build weiter über `PackageInfo.fromPlatform()`.
void main() {
  testWidgets('zeigt Version und Build aus PackageInfo', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Work Time Manager',
      packageName: 'de.example.test',
      version: '9.8.7',
      buildNumber: '654',
      buildSignature: '',
    );

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        locale: Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppInfoPage(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Version 9.8.7 (654)'), findsOneWidget);
  });

  test('PackageInfo.fromPlatform liefert die gesetzten Felder', () async {
    PackageInfo.setMockInitialValues(
      appName: 'A',
      packageName: 'p.q',
      version: '1.2.3',
      buildNumber: '4',
      buildSignature: '',
    );
    final info = await PackageInfo.fromPlatform();
    expect(info.version, '1.2.3');
    expect(info.buildNumber, '4');
    expect(info.packageName, 'p.q');
  });
}
