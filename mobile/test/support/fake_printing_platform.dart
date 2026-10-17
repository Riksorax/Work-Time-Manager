import 'dart:typed_data';

import 'package:flutter/rendering.dart' show Rect;
import 'package:pdf/pdf.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';

/// Fängt den plattformspezifischen `sharePdf`-Aufruf ab, damit die Tests
/// ohne echten Share-Dialog laufen (siehe #297: PDF-Export folgt jetzt der
/// App-Sprache statt fest Deutsch zu sein).
class FakePrintingPlatform extends PrintingPlatform
    with MockPlatformInterfaceMixin {
  Uint8List? lastBytes;
  String? lastFilename;

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
    lastFilename = filename;
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
  Future<Uint8List> convertHtml(
          String html, String? baseUrl, PdfPageFormat format) =>
      throw UnimplementedError();

  @override
  Stream<PdfRaster> raster(Uint8List document, List<int>? pages, double dpi) =>
      throw UnimplementedError();
}
