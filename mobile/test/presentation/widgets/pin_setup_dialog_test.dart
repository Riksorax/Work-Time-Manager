import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/providers/app_lock_provider.dart';
import 'package:flutter_work_time/core/providers/providers.dart';
import 'package:flutter_work_time/core/services/app_lock_service.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/widgets/pin_setup_dialog.dart';

void main() {
  late SharedPreferences prefs;
  late AppLockService service;
  bool? result;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = AppLockService(prefs: prefs, localAuth: LocalAuthentication());
    result = null;
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
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await PinSetupDialog.show(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  Future<void> goToCodeStep(WidgetTester tester, String pin) async {
    await tester.pumpWidget(createSubject());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), pin);
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), pin);
    await tester.tap(find.text('Bestätigen'));
    await tester.pumpAndSettle();
  }

  String shownCode(WidgetTester tester) {
    final text = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .single
        .data!;
    expect(RegExp(r'^[A-Z2-9]{4}(-[A-Z2-9]{4}){3}$').hasMatch(text), isTrue);
    return text;
  }

  testWidgets('3 Schritte: Code wird angezeigt, Abschluss erst nach Checkbox',
      (tester) async {
    await goToCodeStep(tester, '1234');
    final code = shownCode(tester);

    // Noch nichts gespeichert, Abschluss deaktiviert.
    expect(service.hasPin, isFalse);
    FilledButton finish() => tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Bestätigen'));
    expect(finish().onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(finish().onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Bestätigen'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(service.verifyPin('1234'), isTrue);
    expect(service.verifyRecoveryCode(code), isTrue);
  });

  testWidgets('Abbruch im Code-Schritt schreibt nichts, alte PIN gilt weiter',
      (tester) async {
    await service.setPinWithRecoveryCode('9999', 'ABCDEFGHJKLMNPQR');
    await goToCodeStep(tester, '1234');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(service.verifyPin('9999'), isTrue);
    expect(service.verifyPin('1234'), isFalse);
    expect(service.verifyRecoveryCode('ABCDEFGHJKLMNPQR'), isTrue);
  });

  testWidgets('Hinweis zum ungültigen Altcode nur bei vorhandenem Code',
      (tester) async {
    await goToCodeStep(tester, '1234');
    expect(find.textContaining('bisherige'), findsNothing);
  });

  testWidgets('Hinweis zum ungültigen Altcode bei vorhandenem Code',
      (tester) async {
    await service.setPinWithRecoveryCode('9999', 'ABCDEFGHJKLMNPQR');
    await goToCodeStep(tester, '1234');
    expect(find.textContaining('bisherige'), findsOneWidget);
  });

  testWidgets('zu kurze PIN zeigt Fehler und bleibt im ersten Schritt',
      (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(
        find.text('Die PIN muss mindestens 4 Ziffern haben'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(service.hasPin, isFalse);
  });

  testWidgets(
      'abweichende Bestätigung zeigt Fehler, kein Code, nichts gespeichert',
      (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4321');
    await tester.tap(find.text('Bestätigen'));
    await tester.pumpAndSettle();
    expect(find.text('Die PINs stimmen nicht überein'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(service.hasPin, isFalse);
    expect(service.hasRecoveryCode, isFalse);
  });

  testWidgets('Abbruch vor dem Code-Schritt schreibt nichts', (tester) async {
    await service.setPinWithRecoveryCode('9999', 'ABCDEFGHJKLMNPQR');
    await tester.pumpWidget(createSubject());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(service.verifyPin('9999'), isTrue);
    expect(service.verifyRecoveryCode('ABCDEFGHJKLMNPQR'), isTrue);
  });
}
