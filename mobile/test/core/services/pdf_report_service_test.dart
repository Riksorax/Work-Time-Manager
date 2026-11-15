import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:printing/src/interface.dart' show PrintingPlatform;
import 'package:flutter_work_time/core/services/pdf_report_service.dart';
import 'package:flutter_work_time/data/models/yearly_leave_report_model.dart';
import 'package:flutter_work_time/domain/entities/yearly_leave_report.dart';
import 'package:flutter_work_time/l10n/app_localizations_de.dart';
import 'package:flutter_work_time/l10n/app_localizations_en.dart';

import '../../support/fake_printing_platform.dart';
import '../../support/yearly_leave_report_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  late FakePrintingPlatform fakePlatform;
  late PdfReportService service;

  setUp(() {
    fakePlatform = FakePrintingPlatform();
    PrintingPlatform.instance = fakePlatform;
    service = PdfReportService();
  });

  group('Wochenbericht-Dateiname nutzt das ISO-Wochenjahr (#354)', () {
    for (final (monday, week, expected) in [
      (DateTime(2025, 12, 29), 1, 'Wochenbericht_KW1_2026.pdf'),
      (DateTime(2024, 12, 30), 1, 'Wochenbericht_KW1_2025.pdf'),
      (DateTime(2026, 1, 5), 2, 'Wochenbericht_KW2_2026.pdf'),
    ]) {
      test('Montag $monday -> $expected', () async {
        await service.exportWeeklyReport(
          l10n: AppLocalizationsDe(),
          locale: 'de',
          startOfWeek: monday,
          endOfWeek: DateTime(monday.year, monday.month, monday.day + 6),
          weekNumber: week,
          workDays: 5,
          totalWorkDuration: const Duration(hours: 40),
          totalBreakDuration: const Duration(hours: 2),
          averageWorkDuration: const Duration(hours: 8),
          overtime: Duration.zero,
          dailyWork: {monday: const Duration(hours: 8)},
        );

        expect(fakePlatform.lastFilename, expected);
      });
    }
  });

  group('Home-Office-Auswertung (#282)', () {
    List<(String, int, int, double?)> twelveMonths() => [
          for (var m = 1; m <= 12; m++)
            ('Monat $m', m % 3, 20 - (m % 3), m % 3 / 20),
        ];

    test('Monatslayout: Dateiname und PDF-Bytes', () async {
      await service.exportHomeOfficeReport(
        l10n: AppLocalizationsDe(),
        locale: 'de',
        periodLabel: 'Juni 2026',
        fileSuffix: '2026-06',
        homeOfficeDays: 2,
        officeDays: 6,
        totalWorkDays: 8,
        ratio: 0.25,
        homeOfficeDates: [DateTime(2026, 6, 3), DateTime(2026, 6, 9)],
      );

      expect(fakePlatform.lastFilename, 'Home-Office-Auswertung_2026-06.pdf');
      expect(fakePlatform.lastBytes, isNotEmpty);
      expect(String.fromCharCodes(fakePlatform.lastBytes!.take(4)), '%PDF');
    });

    test('Monatslayout mit leerer Tagesliste und ratio null', () async {
      await service.exportHomeOfficeReport(
        l10n: AppLocalizationsDe(),
        locale: 'de',
        periodLabel: 'Juni 2026',
        fileSuffix: '2026-06',
        homeOfficeDays: 0,
        officeDays: 0,
        totalWorkDays: 0,
        ratio: null,
        homeOfficeDates: const [],
      );

      expect(String.fromCharCodes(fakePlatform.lastBytes!.take(4)), '%PDF');
    });

    for (final locale in ['de', 'en']) {
      test('Jahreslayout: Dateiname und PDF-Bytes (locale=$locale)', () async {
        await service.exportHomeOfficeReport(
          l10n: locale == 'de' ? AppLocalizationsDe() : AppLocalizationsEn(),
          locale: locale,
          periodLabel: '2026',
          fileSuffix: '2026',
          homeOfficeDays: 12,
          officeDays: 228,
          totalWorkDays: 240,
          ratio: 0.05,
          perMonth: twelveMonths(),
        );

        expect(fakePlatform.lastFilename, 'Home-Office-Auswertung_2026.pdf');
        expect(String.fromCharCodes(fakePlatform.lastBytes!.take(4)), '%PDF');
      });
    }

    test('genau eines von homeOfficeDates/perMonth ist Pflicht', () async {
      Future<void> call(
              {List<DateTime>? dates,
              List<(String, int, int, double?)>? months}) =>
          service.exportHomeOfficeReport(
            l10n: AppLocalizationsDe(),
            locale: 'de',
            periodLabel: 'x',
            fileSuffix: 'x',
            homeOfficeDays: 0,
            officeDays: 0,
            totalWorkDays: 0,
            ratio: null,
            homeOfficeDates: dates,
            perMonth: months,
          );

      await expectLater(call(), throwsA(isA<AssertionError>()));
      await expectLater(call(dates: const [], months: twelveMonths()),
          throwsA(isA<AssertionError>()));
    });
  });

  group('PdfReportService folgt der App-Sprache (#297)', () {
    for (final locale in ['de', 'en']) {
      final l10n = locale == 'de' ? AppLocalizationsDe() : AppLocalizationsEn();

      test('exportWeeklyReport erzeugt ein PDF für locale=$locale', () async {
        await service.exportWeeklyReport(
          l10n: l10n,
          locale: locale,
          startOfWeek: DateTime(2026, 1, 5),
          endOfWeek: DateTime(2026, 1, 11),
          weekNumber: 2,
          workDays: 5,
          totalWorkDuration: const Duration(hours: 40),
          totalBreakDuration: const Duration(hours: 2, minutes: 30),
          averageWorkDuration: const Duration(hours: 8),
          overtime: const Duration(minutes: 30),
          dailyWork: {DateTime(2026, 1, 5): const Duration(hours: 8)},
        );

        expect(fakePlatform.lastBytes, isNotNull);
        expect(fakePlatform.lastBytes, isNotEmpty);
      });

      test('exportMonthlyReport erzeugt ein PDF für locale=$locale', () async {
        await service.exportMonthlyReport(
          l10n: l10n,
          locale: locale,
          month: DateTime(2026, 1, 1),
          workDays: 22,
          totalWorkDuration: const Duration(hours: 176),
          totalBreakDuration: const Duration(hours: 11),
          averageWorkDuration: const Duration(hours: 8),
          avgWorkDurationPerWeek: const Duration(hours: 40),
          monthlyOvertime: const Duration(hours: 2),
          totalOvertime: const Duration(hours: 10),
          weeklyWork: {2: const Duration(hours: 40)},
          dailyWork: {DateTime(2026, 1, 5): const Duration(hours: 8)},
        );

        expect(fakePlatform.lastBytes, isNotNull);
        expect(fakePlatform.lastBytes, isNotEmpty);
      });

      test('exportYearlyReport erzeugt ein PDF für locale=$locale', () async {
        await service.exportYearlyReport(
          l10n: l10n,
          year: 2026,
          totalWorkDays: 220,
          totalVacationDays: 25,
          totalSickDays: 3,
          totalHolidayDays: 10,
          totalNetWorkDuration: const Duration(hours: 1760),
          totalOvertime: const Duration(hours: 12),
          months: [
            ('Januar', const Duration(hours: 160), const Duration(hours: 4), 20)
          ],
        );

        expect(fakePlatform.lastBytes, isNotNull);
        expect(fakePlatform.lastBytes, isNotEmpty);
      });
    }
  });

  group('Arbeitsorte in der Tagestabelle (#526)', () {
    final mo = DateTime(2026, 10, 5);
    final di = DateTime(2026, 10, 6);
    final work = {
      mo: const Duration(hours: 8),
      di: const Duration(hours: 9),
    };

    for (final (locale, column, weekday) in [
      ('de', 'Arbeitsort', 'Montag'),
      ('en', 'Work location', 'Monday'),
    ]) {
      final l10n = locale == 'de' ? AppLocalizationsDe() : AppLocalizationsEn();

      test('Spalte mit Orten, durch Komma getrennt ($locale)', () {
        final data = PdfReportService.dailyTableData(work,
            l10n: l10n,
            locale: locale,
            // Zeitanteil im Schlüssel stört die Zuordnung nicht.
            dailyLocations: {
              DateTime(2026, 10, 5, 0, 0): const ['Büro', 'Kunde A'],
            });
        expect(data.first.last, column);
        expect(data[1], ['05.10.2026', weekday, '08:00', 'Büro, Kunde A']);
        expect(data[2].last, '', reason: 'Tag ohne Orte: leere Zelle');
      });

      test('ohne Orte keine leere Spalte ($locale)', () {
        final data =
            PdfReportService.dailyTableData(work, l10n: l10n, locale: locale);
        expect(data.first, hasLength(3));
        expect(data.first, isNot(contains(column)));
      });

      test('Wochen- und Monatsbericht mit Orten erzeugen ein PDF ($locale)',
          () async {
        final locs = {
          mo: const ['Zentrale Düsseldorf, Königsallee 1', 'Kunde A'],
        };
        await service.exportWeeklyReport(
          l10n: l10n,
          locale: locale,
          startOfWeek: mo,
          endOfWeek: DateTime(2026, 10, 11),
          weekNumber: 41,
          workDays: 2,
          totalWorkDuration: const Duration(hours: 17),
          totalBreakDuration: const Duration(hours: 1),
          averageWorkDuration: const Duration(hours: 8, minutes: 30),
          overtime: const Duration(hours: 1),
          dailyWork: work,
          dailyLocations: locs,
        );
        expect(String.fromCharCodes(fakePlatform.lastBytes!.take(4)), '%PDF');

        await service.exportMonthlyReport(
          l10n: l10n,
          locale: locale,
          month: DateTime(2026, 10),
          workDays: 2,
          totalWorkDuration: const Duration(hours: 17),
          totalBreakDuration: const Duration(hours: 1),
          averageWorkDuration: const Duration(hours: 8, minutes: 30),
          avgWorkDurationPerWeek: const Duration(hours: 17),
          monthlyOvertime: const Duration(hours: 1),
          totalOvertime: const Duration(hours: 3),
          weeklyWork: {41: const Duration(hours: 17)},
          dailyWork: work,
          dailyLocations: locs,
        );
        expect(String.fromCharCodes(fakePlatform.lastBytes!.take(4)), '%PDF');
      });
    }
  });

  group('Urlaubs- und Krankheitsauswertung (#284)', () {
    final report = yearlyLeaveReportFromJson(yearlyLeaveReportJson(2026),
        requestedYear: 2026);
    final empty = yearlyLeaveReportFromJson(
        yearlyLeaveReportJson(2024, empty: true),
        requestedYear: 2024);
    final created = DateTime(2026, 11, 5);

    LeaveReportContent content(
      YearlyLeaveReport r, {
      String locale = 'de',
      bool current = true,
      String? profileName,
    }) =>
        PdfReportService.leaveReportContent(
          l10n: locale == 'de' ? AppLocalizationsDe() : AppLocalizationsEn(),
          locale: locale,
          report: r,
          isCurrentYear: current,
          createdOn: created,
          profileName: profileName,
        );

    test('laufendes Jahr: Titel, Summen mit Anspruch und Resturlaub', () {
      final c = content(report);
      expect(c.title, 'Urlaubs- und Krankheitsauswertung 2026');
      expect(c.meta, ['Erstellt am 05.11.2026']);
      expect(c.summary, [
        ('Urlaubstage genommen', '14'),
        ('Krankheitstage', '4'),
        ('Urlaubsanspruch', '30'),
        ('Resturlaub', '16'),
      ]);
      expect(c.pastYearNote, isNull);
      expect(c.emptyNote, isNull);
      expect(c.footnote, startsWith('Zählregel: Jeder Urlaubs-'));
    });

    test('Monatstabelle: zwölf Monate in der App-Sprache und Summenzeile', () {
      final c = content(report);
      expect(c.monthHeader, ['Monat', 'Urlaubstage', 'Krankheitstage']);
      expect(c.monthRows, hasLength(12));
      expect(c.monthRows.first, ['Januar', '0', '0']);
      expect(c.monthRows[1], ['Februar', '0', '3']);
      expect(c.monthRows[2].first, 'März');
      expect(c.monthRows[7], ['August', '12', '0']);
      expect(c.totalRow, ['Summe', '14', '4']);
    });

    test('Zeiträume: Bereich mit Tagen, einzelner Tag im Singular', () {
      final c = content(report);
      expect(c.vacationPeriods,
          ['03.08.–14.08. (12 Tage)', '23.12.–24.12. (2 Tage)']);
      expect(c.sickPeriods, ['10.02.–12.02. (3 Tage)', '03.11. (1 Tag)']);
    });

    test('vergangenes Jahr: ohne Anspruch/Resturlaub, mit Hinweis', () {
      final c = content(report, current: false);
      expect(c.summary.map((r) => r.$1),
          ['Urlaubstage genommen', 'Krankheitstage']);
      expect(c.pastYearNote,
          'Anspruch und Resturlaub werden nur für das laufende Jahr ausgewiesen.');
    });

    test('leeres Jahr: Hinweis, Nullen, keine Zeitraum-Abschnitte', () {
      final c = content(empty, current: false);
      expect(c.title, 'Urlaubs- und Krankheitsauswertung 2024');
      expect(c.emptyNote,
          'In 2024 wurden keine Urlaubs- oder Krankheitstage erfasst.');
      expect(c.monthRows, hasLength(12));
      expect(c.totalRow, ['Summe', '0', '0']);
      expect(c.vacationPeriods, isNull);
      expect(c.sickPeriods, isNull);
    });

    test('nur Krankheit: Urlaubsliste „Keine“ (leere Liste)', () {
      final onlySick = yearlyLeaveReportFromJson({
        ...yearlyLeaveReportJson(2026),
        'vacationDaysTaken': 0,
        'vacationPeriods': <Map<String, dynamic>>[],
      }, requestedYear: 2026);
      final c = content(onlySick);
      expect(c.emptyNote, isNull);
      expect(c.vacationPeriods, isEmpty);
      expect(c.sickPeriods, hasLength(2));
    });

    test('Zusatzprofil: Profilname vor dem Erstellungsdatum', () {
      final c = content(report, profileName: 'Nebenjob');
      expect(c.meta, ['Profil: Nebenjob', 'Erstellt am 05.11.2026']);
    });

    test('ohne Monate (älteres Backend): keine Tabellenzeilen', () {
      final old = yearlyLeaveReportFromJson({
        'year': 2026,
        'vacationDaysTaken': 3,
        'sickDays': 1,
      }, requestedYear: 2026);
      final c = content(old);
      expect(c.monthRows, isEmpty);
      expect(c.vacationPeriods, isEmpty);
      expect(c.sickPeriods, isEmpty);
    });

    test('Englisch: Texte, Monatsnamen und Datumsformat', () {
      final c = content(report, locale: 'en', profileName: 'Side job');
      expect(c.title, 'Vacation and sick-day report 2026');
      expect(c.meta, ['Profile: Side job', 'Created on 11/05/2026']);
      expect(c.summary, [
        ('Vacation days taken', '14'),
        ('Sick days', '4'),
        ('Vacation entitlement', '30'),
        ('Remaining vacation', '16'),
      ]);
      expect(c.monthHeader, ['Month', 'Vacation days', 'Sick days']);
      expect(c.monthRows.first.first, 'January');
      expect(c.totalRow.first, 'Total');
      expect(
          c.vacationPeriods, ['08/03–08/14 (12 days)', '12/23–12/24 (2 days)']);
      expect(c.sickPeriods!.last, '11/03 (1 day)');
      expect(content(empty, locale: 'en', current: false).emptyNote,
          'No vacation or sick days were recorded in 2024.');
    });

    for (final (name, r, current, locale, profile) in [
      ('laufendes Jahr', report, true, 'de', null),
      ('vergangenes Jahr', report, false, 'de', null),
      ('leeres Jahr', empty, false, 'de', null),
      ('Englisch', report, true, 'en', null),
      ('Zusatzprofil', report, true, 'de', 'Nebenjob'),
    ]) {
      test('Export $name: Dateiname und PDF-Bytes', () async {
        await service.exportLeaveReport(
          l10n: locale == 'de' ? AppLocalizationsDe() : AppLocalizationsEn(),
          locale: locale,
          report: r,
          isCurrentYear: current,
          createdOn: created,
          profileName: profile,
        );
        // Dateiname fest deutsch, auch bei englischer App-Sprache.
        expect(
            fakePlatform.lastFilename, 'Urlaub-Krank-Auswertung_${r.year}.pdf');
        expect(String.fromCharCodes(fakePlatform.lastBytes!.take(4)), '%PDF');
      });
    }

    test('viele Zeiträume verteilen sich auf mehrere Seiten', () async {
      // 120 einzelne Krankheitstage: die Liste ist länger als eine Seite.
      final days = [
        for (var i = 0; i < 120; i++)
          DateTime(2026, 1, 1).add(Duration(days: i * 3)),
      ];
      String key(DateTime d) => '${d.year}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      final many = yearlyLeaveReportFromJson({
        ...yearlyLeaveReportJson(2026),
        'sickDays': days.length,
        'sickPeriods': [
          for (final d in days) {'start': key(d), 'end': key(d), 'days': 1},
        ],
      }, requestedYear: 2026);
      await service.exportLeaveReport(
        l10n: AppLocalizationsDe(),
        locale: 'de',
        report: many,
        isCurrentYear: true,
        createdOn: created,
      );
      final pdf = String.fromCharCodes(fakePlatform.lastBytes!);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length,
          greaterThanOrEqualTo(3));
    });
  });
}
