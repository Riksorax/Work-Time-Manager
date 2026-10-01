import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/services/version_service.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/widgets/update_required_dialog.dart';
import 'package:mockito/mockito.dart';

class _FakeVersionService extends Mock implements VersionService {}

void main() {
  Widget subject(Locale locale, {required bool forceUpdate}) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: UpdateRequiredDialog(
            updateInfo: UpdateInfo(
              currentVersion: '1.0.0',
              minVersion: '1.5.1',
              forceUpdate: forceUpdate,
            ),
            versionService: _FakeVersionService(),
          ),
        ),
      );

  testWidgets('Standardtext folgt der App-Sprache (Englisch, Pflicht-Update)',
      (tester) async {
    await tester.pumpWidget(subject(const Locale('en'), forceUpdate: true));

    expect(
      find.text(
          'An update is required. Please update the app to version 1.5.1 or higher.'),
      findsOneWidget,
    );
  });

  testWidgets('Standardtext folgt der App-Sprache (Deutsch, optionales Update)',
      (tester) async {
    await tester.pumpWidget(subject(const Locale('de'), forceUpdate: false));

    expect(
      find.text(
          'Eine neue Version (1.5.1) ist verfügbar. Wir empfehlen ein Update.'),
      findsOneWidget,
    );
  });
}
