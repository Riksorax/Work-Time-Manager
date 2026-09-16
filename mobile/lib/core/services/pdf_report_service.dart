import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Exportiert Wochen- und Monatsberichte als PDF (siehe #135) und öffnet
/// anschließend den nativen Share-Dialog (bzw. auf Web den Browser-Download).
///
/// Bewusst als eigenständiger Service statt Logik im ViewModel, damit die
/// ViewModels (`ReportsViewModel`) nicht weiter aufgebläht werden.
///
/// Bettet Open Sans als TTF-Font ein: die in `pdf` eingebauten Basis-14-Fonts
/// (Helvetica etc.) unterstützen keine deutschen Umlaute/ß zuverlässig
/// (siehe https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management).
class PdfReportService {
  static final _dateFmt = DateFormat('dd.MM.yyyy', 'de_DE');

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

  pw.Widget _dailyTable(Map<DateTime, Duration> dailyWork) {
    final sortedEntries = dailyWork.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return pw.TableHelper.fromTextArray(
      headers: const ['Datum', 'Wochentag', 'Arbeitszeit'],
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
      },
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      data: [
        for (final entry in sortedEntries)
          [
            _dateFmt.format(entry.key),
            DateFormat.EEEE('de_DE').format(entry.key),
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
    final doc = pw.Document(theme: await _loadTheme());
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          _header(
            'Wochenbericht',
            'KW $weekNumber · ${_dateFmt.format(startOfWeek)} – ${_dateFmt.format(endOfWeek)}',
          ),
          _summaryTable([
            ('Arbeitstage', '$workDays'),
            ('Gesamte Arbeitszeit', _fmtDuration(totalWorkDuration)),
            ('Gesamte Pausen', _fmtDuration(totalBreakDuration)),
            ('Ø Arbeitszeit pro Tag', _fmtDuration(averageWorkDuration)),
            ('Überstunden', _fmtSignedDuration(overtime)),
          ]),
          pw.SizedBox(height: 20),
          pw.Text('Tagesdetails', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _dailyTable(dailyWork),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Wochenbericht_KW${weekNumber}_${startOfWeek.year}.pdf',
    );
  }

  pw.Widget _weeklyTable(Map<int, Duration> weeklyWork) {
    final sortedEntries = weeklyWork.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return pw.TableHelper.fromTextArray(
      headers: const ['Kalenderwoche', 'Arbeitszeit'],
      cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      data: [
        for (final entry in sortedEntries) ['KW ${entry.key}', _fmtDuration(entry.value)],
      ],
    );
  }

  Future<void> exportMonthlyReport({
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
          _header('Monatsbericht', DateFormat.yMMMM('de_DE').format(month)),
          _summaryTable([
            ('Arbeitstage', '$workDays'),
            ('Gesamte Arbeitszeit', _fmtDuration(totalWorkDuration)),
            ('Gesamte Pausen', _fmtDuration(totalBreakDuration)),
            ('Ø Arbeitszeit pro Tag', _fmtDuration(averageWorkDuration)),
            ('Ø Arbeitszeit pro Woche', _fmtDuration(avgWorkDurationPerWeek)),
            ('Überstunden Monat', _fmtSignedDuration(monthlyOvertime)),
            ('Gesamt-Überstunden', _fmtSignedDuration(totalOvertime)),
          ]),
          pw.SizedBox(height: 20),
          pw.Text('Wochenübersicht', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _weeklyTable(weeklyWork),
          pw.SizedBox(height: 20),
          pw.Text('Tagesdetails', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _dailyTable(dailyWork),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Monatsbericht_${DateFormat('yyyy-MM').format(month)}.pdf',
    );
  }
}
