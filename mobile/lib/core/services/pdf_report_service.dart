import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
    final regularData = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/OpenSans-Bold.ttf');
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );
    _theme = theme;
    return theme;
  }

  String _fmtDuration(Duration d) {
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
      data: [for (final row in rows) [row.$1, row.$2]],
    );
  }

  pw.Widget _dailyTable(
    Map<DateTime, Duration> dailyWork, {
    required AppLocalizations l10n,
    required String locale,
  }) {
    final dateFmt = DateFormat('dd.MM.yyyy', locale);
    final sortedEntries = dailyWork.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return pw.TableHelper.fromTextArray(
      headers: [l10n.pdfDateColumn, l10n.pdfWeekdayColumn, l10n.pdfWorkTimeColumn],
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
      },
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      data: [
        for (final entry in sortedEntries)
          [
            dateFmt.format(entry.key),
            DateFormat.EEEE(locale).format(entry.key),
            _fmtDuration(entry.value),
          ],
      ],
    );
  }

  pw.Widget _header(String title, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
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
          pw.Text(l10n.pdfDailyDetailsTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _dailyTable(dailyWork, l10n: l10n, locale: locale),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Wochenbericht_KW${weekNumber}_${startOfWeek.year}.pdf',
    );
  }

  pw.Widget _weeklyTable(
    Map<int, Duration> weeklyWork, {
    required AppLocalizations l10n,
  }) {
    final sortedEntries = weeklyWork.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return pw.TableHelper.fromTextArray(
      headers: [l10n.pdfCalendarWeekColumn, l10n.pdfWorkTimeColumn],
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
  }) async {
    final doc = pw.Document(theme: await _loadTheme());
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          _header(l10n.pdfMonthlyReportTitle, DateFormat.yMMMM(locale).format(month)),
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
          pw.Text(l10n.pdfWeeklyOverviewTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _weeklyTable(weeklyWork, l10n: l10n),
          pw.SizedBox(height: 20),
          pw.Text(l10n.pdfDailyDetailsTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _dailyTable(dailyWork, l10n: l10n, locale: locale),
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
      headers: [l10n.pdfMonthColumn, l10n.pdfWorkDaysLabel, l10n.pdfWorkTimeColumn, l10n.pdfOvertimeLabel],
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
    required List<(String name, Duration net, Duration overtime, int workDays)> months,
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
          pw.Text(l10n.pdfMonthlyOverviewTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
