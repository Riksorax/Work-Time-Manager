import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/data/repositories/local_work_repository_impl.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:flutter_work_time/presentation/widgets/quick_entry_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Schnelleintrag (#526): erzeugt einen frischen Eintrag ohne Orte (`null`),
// der gespeicherte Orte nicht überschreibt.
void main() {
  testWidgets(
      'Schnelleintrag liefert workLocations null; Speichern behält Orte',
      (tester) async {
    final day = DateTime(2026, 10, 5);
    WorkEntryEntity? result;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showDialog<WorkEntryEntity>(
                  context: context,
                  builder: (_) => QuickEntryDialog(date: day));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.workLocations, isNull);

    // Gegen ein gespeichertes Arbeits-Eintrag mit Orten: bleiben erhalten.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalWorkRepositoryImpl(prefs);
    await tester.runAsync(() async {
      await repo.saveWorkEntry(WorkEntryEntity(
          id: '2026-10-05',
          date: day,
          workStart: DateTime(2026, 10, 5, 8),
          workLocations: const ['Büro']));
      await repo.saveWorkEntry(result!);
      expect((await repo.getWorkEntry(day)).workLocations, ['Büro']);
    });
  });
}
