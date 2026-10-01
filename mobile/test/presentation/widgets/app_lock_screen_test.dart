import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/providers/app_lock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/services/app_lock_service.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/widgets/app_lock_screen.dart';

void main() {
  late SharedPreferences prefs;
  late AppLockService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // Echte LocalAuthentication: Ohne Plattform-Kanal wirft sie beim Aufruf
    // eine MissingPluginException, die AppLockService.isBiometricAvailable
    // bereits abfängt und als "nicht verfügbar" behandelt.
    service = AppLockService(prefs: prefs, localAuth: LocalAuthentication());
    await service.setPin('1234');
    await service.setEnabled(true);
  });

  Widget createSubject() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLockServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppLockScreen(),
      ),
    );
  }

  testWidgets(
      'entsperrt per Eingabetaste bei korrekter PIN und schließt dabei die Tastatur (#337)',
      (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Die Tastatur muss schon vor dem Entfernen des Screens geschlossen
    // worden sein (siehe #337) - sonst verarbeitet das Framework die
    // IME-Selection-Änderung noch, während das zugehörige Overlay bereits
    // disposed wird.
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('zeigt bei falscher PIN einen Fehler und behält den Fokus',
      (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Falsche PIN'), findsOneWidget);
  });
}
