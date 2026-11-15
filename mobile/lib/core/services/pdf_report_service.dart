import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/yearly_leave_report.dart';
import '../../domain/utils/home_office_stats.dart';
import '../../domain/utils/iso_week.dart';
import '../../l10n/app_localizations.dart';

/// Exportiert Wochen- und Monatsberichte als PDF (siehe #135) und öffnet
/// anschließend den nativen Share-Dialog (bzw. auf Web den Browser-Download).
///
/// Bewusst als eigenständiger Service statt Logik im ViewModel, damit die
/// ViewModels (`ReportsViewModel`) nicht weiter aufgebläht werden.
///
/// Folgt der App-Sprache (siehe #297): Aufrufer übergeben `l10n` und `locale`
/// aus dem umgebenden `BuildContext`, damit Überschriften, Beschriftungen und
/// Datumsformate mit der UI übereinstimmen.
///
/// Bettet Open Sans als TTF-Font ein: die in `pdf` eingebauten Basis-14-Fonts
/// (Helvetica etc.) unterstützen keine deutschen Umlaute/ß zuverlässig
/// (siehe https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management).
class PdfReportService {
  pw.ThemeData? _theme;

  Future<pw.ThemeData> _loadTheme() async {
    final cached = _theme;
    if (cached != null) return cached;
    final regularData =
        await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );
    _theme = theme;
    return theme;
  }

  String _fmtDuration(Duration d) => _fmtDurationStatic(d);

  static String _fmtDurationStatic(Duration d) {
    final abs = d.abs();
    final h = abs.inHours.toString().padLeft(2, '0');
    final m = abs.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sign = d.isNegative ? '-' : '';
    return '$sign$h:$m';
  }

  String _fmtSignedDuration(Duration d) {
    final abs = d.abs();
    final h = abs.inHours.toString().padLeft(2, '0');
    final m = abs.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sign = d.isNegative ? '-' : '+';
    return '$sign$h:$m';
  }

  pw.Widget _summaryTable(List<(String, String)> rows) {
    return pw.TableHelper.fromTextArray(
      headerCount: 0,
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      border: null,
      data: [
        for (final row in rows) [row.$1, row.$2]
      ],
    );
  }

  /// Kopf und Zeilen der Tagestabelle (Woche, Monat) als Text. Hat mindestens
  /// ein Tag Arbeitsorte ([dailyLocations], #526), kommt eine Spalte
  /// „Arbeitsort“ dazu (Orte durch Komma getrennt); sonst bleibt die Tabelle
  /// wie bisher (keine leere Spalte). Tage werden über Jahr/Monat/Tag
  /// zugeordnet.
  @visibleForTesting
  static List<List<String>> dailyTableData(
    Map<DateTime, Duration> dailyWork, {
    required AppLocalizations l10n,
    required String locale,
    Map<DateTime, List<String>> dailyLocations = const {},
  }) {
    DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
    final dateFmt = DateFormat('dd.MM.yyyy', locale);
    final sortedEntries = dailyWork.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final locationsByDay = {
      for (final e in dailyLocations.entries)
        if (e.value.isNotEmpty) dayOf(e.key): e.value.join(', '),
    };
    final withLocations =
        sortedEntries.any((e) => locationsByDay.containsKey(dayOf(e.key)));
    return [
      [
        l10n.pdfDateColumn,
        l10n.pdfWeekdayColumn,
        // Tageswerte sind brutto (#535).
        l10n.pdfAttendanceColumn,
        if (withLocations) l10n.pdfWorkLocationColumn,
      ],
      for (final entry in sortedEntries)
        [
          dateFmt.format(entry.key),
          DateFormat.EEEE(locale).format(entry.key),
          _fmtDurationStatic(entry.value),
          if (withLocations) locationsByDay[dayOf(entry.key)] ?? '',
        ],
    ];
  }

  /// Tagestabelle (Woche, Monat), siehe [dailyTableData]. Lange Orte brechen
  /// in ihrer Zelle um (flexible letzte Spalte).
  pw.Widget _dailyTable(
    Map<DateTime, Duration> dailyWork, {
    required AppLocalizations l10n,
    required String locale,
    Map<DateTime, List<String>> dailyLocations = const {},
  }) {
    final data = dailyTableData(dailyWork,
        l10n: l10n, locale: locale, dailyLocations: dailyLocations);
    final withLocations = data.first.length == 4;
    return pw.TableHelper.fromTextArray(
      headers: data.first,
      columnWidths: withLocations
          ? const {
              0: pw.IntrinsicColumnWidth(),
              1: pw.IntrinsicColumnWidth(),
              2: pw.IntrinsicColumnWidth(),
              3: pw.FlexColumnWidth(),
            }
          : null,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        if (withLocations) 3: pw.Alignment.centerLeft,
      },
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      data: data.skip(1).toList(),
    );
  }

  pw.Widget _header(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(subtitle, style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 16),
      ],
    );
  }

  Future<void> exportWeeklyReport({
    required AppLocalizations l10n,
    required String locale,
    required DateTime startOfWeek,
    required DateTime endOfWeek,
    required int weekNumber,
    required int workDays,
    required Duration totalWorkDuration,
    required Duration totalBreakDuration,
    required Duration averageWorkDuration,
    required Duration overtime,
    required Map<DateTime, Duration> dailyWork,
    Map<DateTime, List<String>> dailyLocations = const {},
  }) async {
    final dateFmt = DateFormat('dd.MM.yyyy', locale);
    final doc = pw.Document(theme: await _loadTheme());
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          _header(
            l10n.pdfWeeklyReportTitle,
            '${l10n.weekNumberLabel(weekNumber)} · ${dateFmt.format(startOfWeek)} – ${dateFmt.format(endOfWeek)}',
          ),
          _summaryTable([
            (l10n.pdfWorkDaysLabel, '$workDays'),
            (l10n.pdfTotalWorkTimeLabel, _fmtDuration(totalWorkDuration)),
            (l10n.pdfTotalBreaksLabel, _fmtDuration(totalBreakDuration)),
            (l10n.pdfAvgWorkPerDayLabel, _fmtDuration(averageWorkDuration)),
            (l10n.pdfOvertimeLabel, _fmtSignedDuration(overtime)),
          ]),
          pw.SizedBox(height: 20),
          pw.Text(l10n.pdfDailyAttendanceTitle,
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _dailyTable(dailyWork,
              l10n: l10n, locale: locale, dailyLocations: dailyLocations),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Wochenbericht_KW${weekNumber}_${isoWeekYear(startOfWeek)}.pdf',
    );
  }

  pw.Widget _weeklyTable(
    Map<int, Duration> weeklyWork, {
    required AppLocalizations l10n,
  }) {
    final sortedEntries = weeklyWork.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return pw.TableHelper.fromTextArray(
      // Wochenwerte sind brutto (#535).
      headers: [l10n.pdfCalendarWeekColumn, l10n.pdfAttendanceColumn],
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      data: [
        for (final entry in sortedEntries)
          [l10n.weekNumberLabel(entry.key), _fmtDuration(entry.value)],
      ],
    );
  }

  Future<void> exportMonthlyReport({
    required AppLocalizations l10n,
    required String locale,
    required DateTime month,
    required int workDays,
    required Duration totalWorkDuration,
    required Duration totalBreakDuration,
    required Duration averageWorkDuration,
    required Duration avgWorkDurationPerWeek,
    required Duration monthlyOvertime,
    required Duration totalOvertime,
    required Map<int, Duration> weeklyWork,
    required Map<DateTime, Duration> dailyWork,
    Map<DateTime, List<String>> dailyLocations = const {},
  }) async {
    final doc = pw.Document(theme: await _loadTheme());
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          _header(l10n.pdfMonthlyReportTitle,
              DateFormat.yMMMM(locale).format(month)),
          _summaryTable([
            (l10n.pdfWorkDaysLabel, '$workDays'),
            (l10n.pdfTotalWorkTimeLabel, _fmtDuration(totalWorkDuration)),
            (l10n.pdfTotalBreaksLabel, _fmtDuration(totalBreakDuration)),
            (l10n.pdfAvgWorkPerDayLabel, _fmtDuration(averageWorkDuration)),
            (l10n.pdfAvgWorkPerWeekLabel, _fmtDuration(avgWorkDurationPerWeek)),
            (l10n.pdfMonthlyOvertimeLabel, _fmtSignedDuration(monthlyOvertime)),
            (l10n.pdfTotalOvertimeLabel, _fmtSignedDuration(totalOvertime)),
          ]),
          pw.SizedBox(height: 20),
          pw.Text(l10n.pdfWeeklyOverviewTitle,
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _weeklyTable(weeklyWork, l10n: l10n),
          pw.SizedBox(height: 20),
          pw.Text(l10n.pdfDayOverviewTitle,
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _dailyTable(dailyWork,
              l10n: l10n, locale: locale, dailyLocations: dailyLocations),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Monatsbericht_${DateFormat('yyyy-MM').format(month)}.pdf',
    );
  }

  pw.Widget _monthlyTable(
    List<(String name, Duration net, Duration overtime, int workDays)> months, {
    required AppLocalizations l10n,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: [
        l10n.pdfMonthColumn,
        l10n.pdfWorkDaysLabel,
        l10n.pdfWorkTimeColumn,
        l10n.pdfOvertimeLabel
      ],
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      data: [
        for (final m in months)
          [m.$1, '${m.$4}', _fmtDuration(m.$2), _fmtSignedDuration(m.$3)],
      ],
    );
  }

  pw.Widget _homeOfficeYearTable(
    List<(String month, int homeOffice, int office, double? ratio)> months, {
    required AppLocalizations l10n,
    required String locale,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: [
        l10n.pdfMonthColumn,
        l10n.pdfHomeOfficeDaysLabel,
        l10n.pdfOfficeDaysLabel,
        l10n.pdfHomeOfficeRatioLabel,
      ],
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      data: [
        for (final m in months)
          [m.$1, '${m.$2}', '${m.$3}', formatHomeOfficeRatio(m.$4, locale)],
      ],
    );
  }

  pw.Widget _homeOfficeDayList(
    List<DateTime> dates, {
    required AppLocalizations l10n,
    required String locale,
  }) {
    if (dates.isEmpty) return pw.Text(l10n.pdfHomeOfficeNoDays);
    final fmt = DateFormat.yMMMEd(locale);
    return pw.TableHelper.fromTextArray(
      headerCount: 0,
      cellAlignments: {0: pw.Alignment.centerLeft},
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      data: [
        for (final d in dates) [fmt.format(d)],
      ],
    );
  }

  /// Exportiert die Home-Office-Auswertung als PDF (siehe #282).
  ///
  /// Genau eines von [homeOfficeDates] (Monatslayout mit Tagesliste) und
  /// [perMonth] (Jahreslayout mit Monatstabelle) ist gesetzt. Die Zählregel
  /// liegt in `calculateHomeOfficeStats`; der Service formatiert nur.
  Future<void> exportHomeOfficeReport({
    required AppLocalizations l10n,
    required String locale,
    required String periodLabel,
    required String fileSuffix,
    required int homeOfficeDays,
    required int officeDays,
    required int totalWorkDays,
    required double? ratio,
    List<DateTime>? homeOfficeDates,
    List<(String month, int homeOffice, int office, double? ratio)>? perMonth,
  }) async {
    assert(
      (homeOfficeDates == null) != (perMonth == null),
      'Genau eines von homeOfficeDates und perMonth muss gesetzt sein.',
    );
    final doc = pw.Document(theme: await _loadTheme());
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          _header(l10n.pdfHomeOfficeReportTitle, periodLabel),
          _summaryTable([
            (l10n.pdfHomeOfficeDaysLabel, '$homeOfficeDays'),
            (l10n.pdfOfficeDaysLabel, '$officeDays'),
            (l10n.pdfHomeOfficeTotalDaysLabel, '$totalWorkDays'),
            (
              l10n.pdfHomeOfficeRatioLabel,
              formatHomeOfficeRatio(ratio, locale)
            ),
          ]),
          pw.SizedBox(height: 20),
          if (homeOfficeDates != null) ...[
            pw.Text(l10n.pdfHomeOfficeDayListTitle,
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _homeOfficeDayList(homeOfficeDates, l10n: l10n, locale: locale),
          ] else ...[
            pw.Text(l10n.pdfMonthlyOverviewTitle,
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _homeOfficeYearTable(perMonth!, l10n: l10n, locale: locale),
          ],
          pw.SizedBox(height: 20),
          pw.Text(l10n.pdfHomeOfficeCountNote,
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Home-Office-Auswertung_$fileSuffix.pdf',
    );
  }

  /// Datumsformat der App-Sprache mit zweistelligem Tag und Monat, abgeleitet
  /// aus dem Muster von [base] (de `d.M.` → `dd.MM.`, en `M/d` → `MM/dd`).
  static DateFormat _twoDigit(DateFormat base, String locale) => DateFormat(
      base.pattern!
          .replaceAll(RegExp('d+'), 'dd')
          .replaceAll(RegExp('M+'), 'MM'),
      locale);

  /// Alle Texte der Urlaubs- und Krankheitsauswertung (#284), getrennt vom
  /// PDF-Aufbau, damit Tests den Inhalt prüfen können. Rechnet nichts nach:
  /// Summen, Monate und Zeiträume stammen aus [report] (Backend).
  @visibleForTesting
  static LeaveReportContent leaveReportContent({
    required AppLocalizations l10n,
    required String locale,
    required YearlyLeaveReport report,
    required bool isCurrentYear,
    required DateTime createdOn,
    String? profileName,
  }) {
    final dayFmt = _twoDigit(DateFormat.Md(locale), locale);
    final createdFmt = _twoDigit(DateFormat.yMd(locale), locale);
    final monthFmt = DateFormat.MMMM(locale);
    final year = '${report.year}';

    List<String> periods(List<LeavePeriod> list) => [
          for (final p in list)
            l10n.pdfLeavePeriodLabel(
              _sameDay(p.start, p.end)
                  ? dayFmt.format(p.start)
                  : '${dayFmt.format(p.start)}–${dayFmt.format(p.end)}',
              p.days,
            ),
        ];

    return LeaveReportContent(
      title: l10n.pdfLeaveReportTitle(year),
      meta: [
        if (profileName != null && profileName.isNotEmpty)
          l10n.pdfLeaveProfileLabel(profileName),
        l10n.pdfLeaveCreatedLabel(createdFmt.format(createdOn)),
      ],
      summary: [
        (l10n.pdfLeaveVacationTakenLabel, '${report.vacationDaysTaken}'),
        (l10n.pdfSickDaysLabel, '${report.sickDays}'),
        if (isCurrentYear) ...[
          (l10n.pdfLeaveEntitlementLabel, '${report.vacationDaysPerYear}'),
          (l10n.pdfLeaveRemainingLabel, '${report.vacationDaysRemaining}'),
        ],
      ],
      pastYearNote: isCurrentYear ? null : l10n.pdfLeavePastYearNote,
      emptyNote: report.isEmpty ? l10n.pdfLeaveEmptyNote(year) : null,
      monthHeader: [
        l10n.pdfMonthColumn,
        l10n.pdfLeaveVacationDaysColumn,
        l10n.pdfLeaveSickDaysColumn,
      ],
      monthRows: [
        for (final m in report.months)
          [
            monthFmt.format(DateTime(2000, m.month)),
            '${m.vacationDays}',
            '${m.sickDays}',
          ],
      ],
      totalRow: [
        l10n.pdfLeaveTotalLabel,
        '${report.vacationDaysTaken}',
        '${report.sickDays}',
      ],
      vacationPeriods: report.isEmpty ? null : periods(report.vacationPeriods),
      sickPeriods: report.isEmpty ? null : periods(report.sickPeriods),
      footnote: l10n.pdfLeaveCountNote,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  pw.Widget _leaveMonthTable(LeaveReportContent c) {
    const padding = pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8);
    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    pw.Widget cell(String text, int col, {pw.TextStyle? style}) => pw.Padding(
          padding: padding,
          child: pw.Align(
            alignment:
                col == 0 ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
            child: pw.Text(text, style: style),
          ),
        );
    pw.TableRow row(List<String> cells, {pw.TextStyle? style}) => pw.TableRow(
          children: [
            for (var i = 0; i < cells.length; i++)
              cell(cells[i], i, style: style),
          ],
        );
    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(width: 0.5),
        top: pw.BorderSide(width: 0.5),
        bottom: pw.BorderSide(width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(),
        2: pw.FlexColumnWidth(),
      },
      children: [
        row(c.monthHeader, style: bold),
        for (final r in c.monthRows) row(r),
        row(c.totalRow, style: bold),
      ],
    );
  }

  /// Überschrift und Zeilen einer Zeitraum-Liste als einzelne Widgets, damit
  /// `MultiPage` eine lange Liste auf mehrere Seiten verteilen kann.
  List<pw.Widget> _leavePeriodSection(String title, List<String> lines,
      {required AppLocalizations l10n}) {
    return [
      pw.Text(title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      if (lines.isEmpty)
        pw.Text(l10n.pdfLeaveNoPeriodsLabel)
      else
        for (final line in lines)
          pw.Bullet(
            text: line,
            margin: const pw.EdgeInsets.symmetric(vertical: 1.5),
            padding: pw.EdgeInsets.zero,
          ),
    ];
  }

  /// Exportiert die Urlaubs- und Krankheitsauswertung eines Jahres als PDF
  /// (#284). Inhalt siehe [leaveReportContent]; der Dateiname ist fest
  /// deutsch (`Urlaub-Krank-Auswertung_{Jahr}.pdf`, wie die übrigen
  /// Berichte). Ein Jahr ohne Urlaub und Krankheit ergibt trotzdem ein PDF
  /// mit Hinweis.
  Future<void> exportLeaveReport({
    required AppLocalizations l10n,
    required String locale,
    required YearlyLeaveReport report,
    required bool isCurrentYear,
    required DateTime createdOn,
    String? profileName,
  }) async {
    final c = leaveReportContent(
      l10n: l10n,
      locale: locale,
      report: report,
      isCurrentYear: isCurrentYear,
      createdOn: createdOn,
      profileName: profileName,
    );
    final doc = pw.Document(theme: await _loadTheme());
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          _header(c.title, c.meta.join(' · ')),
          _summaryTable(c.summary),
          if (c.pastYearNote != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(c.pastYearNote!, style: const pw.TextStyle(fontSize: 10)),
          ],
          if (c.emptyNote != null) ...[
            pw.SizedBox(height: 12),
            pw.Text(c.emptyNote!,
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ],
          if (c.monthRows.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(l10n.pdfLeaveMonthsTitle,
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _leaveMonthTable(c),
          ],
          if (c.vacationPeriods != null) ...[
            pw.SizedBox(height: 16),
            ..._leavePeriodSection(
                l10n.pdfLeaveVacationPeriodsTitle, c.vacationPeriods!,
                l10n: l10n),
          ],
          if (c.sickPeriods != null) ...[
            pw.SizedBox(height: 12),
            ..._leavePeriodSection(
                l10n.pdfLeaveSickPeriodsTitle, c.sickPeriods!,
                l10n: l10n),
          ],
          pw.SizedBox(height: 16),
          pw.Text(c.footnote, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Urlaub-Krank-Auswertung_${report.year}.pdf',
    );
  }

  /// Exportiert den Jahresbericht als PDF (siehe #256).
  Future<void> exportYearlyReport({
    required AppLocalizations l10n,
    required int year,
    required int totalWorkDays,
    required int totalVacationDays,
    required int totalSickDays,
    required int totalHolidayDays,
    required Duration totalNetWorkDuration,
    required Duration totalOvertime,
    required List<(String name, Duration net, Duration overtime, int workDays)>
        months,
  }) async {
    final doc = pw.Document(theme: await _loadTheme());
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          _header(l10n.pdfYearlyReportTitle, '$year'),
          _summaryTable([
            (l10n.pdfWorkDaysLabel, '$totalWorkDays'),
            (l10n.pdfTotalWorkTimeLabel, _fmtDuration(totalNetWorkDuration)),
            (l10n.pdfVacationDaysLabel, '$totalVacationDays'),
            (l10n.pdfSickDaysLabel, '$totalSickDays'),
            (l10n.pdfHolidaysLabel, '$totalHolidayDays'),
            (l10n.pdfTotalOvertimeLabel, _fmtSignedDuration(totalOvertime)),
          ]),
          pw.SizedBox(height: 20),
          pw.Text(l10n.pdfMonthlyOverviewTitle,
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _monthlyTable(months, l10n: l10n),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Jahresbericht_$year.pdf',
    );
  }
}

/// Texte der Urlaubs- und Krankheitsauswertung (#284), siehe
/// [PdfReportService.leaveReportContent].
class LeaveReportContent {
  final String title;

  /// Zeile unter dem Titel: ggf. Profil, dann Erstellungsdatum.
  final List<String> meta;
  final List<(String, String)> summary;

  /// Nur für ein anderes als das laufende Jahr gesetzt.
  final String? pastYearNote;

  /// Nur für ein Jahr ohne Urlaubs- und Krankheitstage gesetzt.
  final String? emptyNote;
  final List<String> monthHeader;

  /// Zwölf Monatszeilen; leer, wenn das Backend keine Monate liefert.
  final List<List<String>> monthRows;
  final List<String> totalRow;

  /// `null` bei einem Jahr ohne Urlaubs- und Krankheitstage (Abschnitt
  /// entfällt); eine leere Liste steht als „Keine“ im PDF.
  final List<String>? vacationPeriods;
  final List<String>? sickPeriods;
  final String footnote;

  const LeaveReportContent({
    required this.title,
    required this.meta,
    required this.summary,
    required this.pastYearNote,
    required this.emptyNote,
    required this.monthHeader,
    required this.monthRows,
    required this.totalRow,
    required this.vacationPeriods,
    required this.sickPeriods,
    required this.footnote,
  });
}
