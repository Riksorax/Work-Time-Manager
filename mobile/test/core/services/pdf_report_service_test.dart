import 'dart:typed_data';

import 'package:flutter/rendering.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:flutter_work_time/core/services/pdf_report_service.dart';
import 'package:flutter_work_time/l10n/app_localizations_de.dart';
import 'package:flutter_work_time/l10n/app_localizations_en.dart';

/// Fängt den plattformspezifischen `sharePdf`-Aufruf ab, damit die Tests
/// ohne echten Share-Dialog laufen (siehe #297: PDF-Export folgt jetzt der
/// App-Sprache statt fest Deutsch zu sein).
class _FakePrintingPlatform extends PrintingPlatform with MockPlatformInterfaceMixin {
  Uint8List? lastBytes;

  @override
  Future<bool> sharePdf(
    Uint8List bytes,
    String filename,
    Rect bounds,
    String? subject,
    String? body,
    List<String>? emails,
  ) async {
    lastBytes = bytes;
    return true;
  }

  @override
  Future<PrintingInfo> info() => throw UnimplementedError();

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<Printer>> listPrinters() => throw UnimplementedError();

  @override
  Future<Printer?> pickPrinter(Rect bounds) => throw UnimplementedError();

  @override
  Future<Uint8List> convertHtml(String html, String? baseUrl, PdfPageFormat format) =>
      throw UnimplementedError();

  @override
  Stream<PdfRaster> raster(Uint8List document, List<int>? pages, double dpi) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('de', null);
    await initializeDateFormatting('en', null);
  });

  late _FakePrintingPlatform fakePlatform;
  late PdfReportService service;

  setUp(() {
    fakePlatform = _FakePrintingPlatform();
    PrintingPlatform.instance = fakePlatform;
    service = PdfReportService();
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
          months: [('Januar', const Duration(hours: 160), const Duration(hours: 4), 20)],
        );

        expect(fakePlatform.lastBytes, isNotNull);
        expect(fakePlatform.lastBytes, isNotEmpty);
      });
    }
  });
}
