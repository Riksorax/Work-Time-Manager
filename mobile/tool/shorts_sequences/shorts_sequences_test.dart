// Bewegte Bildfolgen für die Kurzvideos aus der echten App (#575).
//
// Aufruf (aus `mobile/`, ohne Android-SDK, braucht `ffmpeg`):
//
//   flutter test tool/shorts_sequences
//
// Schreibt je Folge `<name>.mp4` (H.264, 30 Bilder/s, 1080 × 1920, ohne Ton)
// und `<name>.json` (Marken und Ausschnitte) nach
// `../marketing/shorts/frames/de/`. Die Einzelbilder liegen nur in einem
// temporären Ordner; `--dart-define=SHORTS_SEQUENCE_FRAMES=<ordner>` behält
// sie als `<ordner>/<name>/00000.png …`, `--dart-define=FFMPEG=<pfad>` wählt
// ein anderes ffmpeg. Getrennt von den Standbildern
// (`tool/shorts_frames`), weil der Lauf länger dauert. Details:
// `mobile/CLAUDE.md`, „App-Bilder für Kurzvideos (#575)“.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../shared/screen_renderer.dart';
import '../shorts_frames/shorts_data.dart';

const _locale = 'de';
const _out = '../marketing/shorts/frames/$_locale';
const _fps = 30;
const _keepFrames = String.fromEnvironment('SHORTS_SEQUENCE_FRAMES');
const _ffmpeg = String.fromEnvironment('FFMPEG', defaultValue: 'ffmpeg');

/// Zeit des Bildes [frame] seit Beginn der Folge. Auf Mikrosekunden gerundet;
/// 30 Bilder ergeben trotzdem genau eine Sekunde.
Duration _timeOf(int frame) =>
    Duration(microseconds: (frame * 1000000 / _fps).round());

/// Nimmt eine Folge auf: Die Uhr der App ([clock]) und die Zeit des Tests
/// (Animationen, `Timer`) laufen je Bild gemeinsam um 1/30 s weiter.
class _Recorder {
  _Recorder(this._t, this.name, {required DateTime startsAt})
      : _startsAt = startsAt,
        _dir = _keepFrames.isEmpty
            ? Directory.systemTemp.createTempSync('shorts_sequence_')
            : (Directory('$_keepFrames/$name')..createSync(recursive: true));

  final WidgetTester _t;
  final String name;
  final DateTime _startsAt;
  final Directory _dir;
  late final AppScreen app;

  /// Anzahl der bisher aufgenommenen Bilder = Nummer des nächsten Bildes.
  int frames = 0;

  DateTime clock() => _startsAt.add(_timeOf(frames > 0 ? frames - 1 : 0));

  /// Nimmt [count] Bilder auf. Vor jedem Bild außer dem ersten der Folge
  /// vergeht 1/30 s; die Uhr steht schon während des Schritts auf der Zeit
  /// des neuen Bildes, damit ein darin fälliger `Timer` sie sieht.
  Future<void> record(int count) async {
    for (var i = 0; i < count; i++) {
      if (frames > 0) {
        final step = _timeOf(frames) - _timeOf(frames - 1);
        frames++;
        await _t.pump(step);
      } else {
        frames++;
      }
      final image = await app.capture();
      final file = (frames - 1).toString().padLeft(5, '0');
      await writePng(_t, image, '${_dir.path}/$file.png');
      image.dispose();
    }
  }

  /// Setzt die Einzelbilder zu `<name>.mp4` zusammen und schreibt
  /// `<name>.json`.
  Future<void> finish({
    required Map<String, int> marks,
    required Map<String, Rect> regions,
  }) async {
    final args = [
      '-y', '-loglevel', 'error',
      '-framerate', '$_fps', '-i', '${_dir.path}/%05d.png',
      '-an',
      // Farben ausdrücklich nach BT.709 (ohne Angabe rechnet ffmpeg mit
      // BT.601, Player lesen HD aber als BT.709: Farbstich gegenüber den
      // Standbildern).
      '-vf', 'scale=out_color_matrix=bt709:out_range=tv,format=yuv420p',
      '-colorspace', 'bt709', '-color_primaries', 'bt709',
      '-color_trc', 'bt709', '-color_range', 'tv',
      '-c:v', 'libx264', '-crf', '14', '-preset', 'slow',
      '-r', '$_fps', '-movflags', '+faststart',
      '$_out/$name.mp4',
    ];
    late ProcessResult result;
    await _t.runAsync(() async {
      Directory(_out).createSync(recursive: true);
      result = await Process.run(_ffmpeg, args);
    });
    expect(result.exitCode, 0, reason: 'ffmpeg: ${result.stderr}');

    final json = {
      'fps': _fps,
      'bilder': frames,
      'marken': marks,
      'ausschnitte': {
        for (final e in regions.entries) e.key: _fraction(e.value),
      },
    };
    File('$_out/$name.json')
        .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(json)}'
            '\n');
    if (_keepFrames.isEmpty) _dir.deleteSync(recursive: true);
  }
}

/// [rect] (logische Pixel) als Anteil von Bildbreite und -höhe.
Map<String, double> _fraction(Rect rect) {
  const width = screenLogicalWidth;
  const height = screenHeight / screenDpr;
  double part(double value, double of) =>
      double.parse((value / of).clamp(0.0, 1.0).toStringAsFixed(4));
  final visible = rect.intersect(const Rect.fromLTWH(0, 0, width, height));
  return {
    'x': part(visible.left, width),
    'y': part(visible.top, height),
    'breite': part(visible.width, width),
    'hoehe': part(visible.height, height),
  };
}

/// Fläche der gezeichneten Zeilen aller Texte unter [finder] (ein `Text`
/// selbst ist im Dashboard so breit wie die Spalte).
Rect _textRect(WidgetTester t, Finder finder) {
  final paragraphs = find.descendant(
      of: finder, matching: find.byType(RichText), matchRoot: true);
  expect(paragraphs, findsWidgets);
  Rect? all;
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final boxes = paragraph.getBoxesForSelection(TextSelection(
        baseOffset: 0, extentOffset: paragraph.text.toPlainText().length));
    for (final box in boxes) {
      final rect = MatrixUtils.transformRect(
          paragraph.getTransformTo(null), box.toRect());
      all = all?.expandToInclude(rect) ?? rect;
    }
  }
  return all!;
}

/// Überschrift und Wert eines Überstunden-Blocks.
Rect _overtimeRect(WidgetTester t, String label) => _textRect(t,
    find.ancestor(of: find.text(label), matching: find.byType(Column)).first);

String _timer(int seconds) => '00:00:${seconds.toString().padLeft(2, '0')}';

void main() {
  setUpAll(() async {
    await loadScreenFonts();
    await initializeDateFormatting(_locale, null);
  });

  // Morgens: Dashboard steht ruhig, Tipp auf „Zeiterfassung starten“, danach
  // läuft der Timer im Sekundentakt.
  testWidgets('start_morgens', timeout: const Timeout(Duration(minutes: 30)),
      (t) async {
    const idle = 45; // 1,5 s ruhig stehen
    const press = 6; // Finger 0,2 s auf dem Knopf
    const seconds = 5; // so viele Sekunden zählt der Timer hoch …
    const tail = 15; // … und die letzte bleibt noch 0,5 s stehen
    // Bild, mit dem der Finger loslässt. In diesem Augenblick ist es genau
    // 7:52:00 Uhr, die Folge beginnt entsprechend früher.
    const release = idle + press - 1;

    final rec = _Recorder(t, 'start_morgens',
        startsAt: shortsStart.subtract(_timeOf(release)));
    rec.app = await openAppScreen(t, const ScreenMotif(), _locale,
        clock: rec.clock, entries: shortsEntries(null));
    final l10n = l10nOf(t);
    final regions = <String, Rect>{};

    // ── vor dem Start ──────────────────────────────────────────────────
    final startButton = find.widgetWithText(
        ElevatedButton, l10n.startTimeTracking,
        skipOffstage: true);
    expect(startButton, findsOneWidget);
    regions['start_knopf'] = t.getRect(startButton);
    regions['timer_vor_start'] = _textRect(t, find.text(_timer(0)));
    regions['ueberstunden_gesamt_vor_start'] =
        _overtimeRect(t, l10n.overtimeTotalLabel);
    regions['heutige_ueberstunden_vor_start'] =
        _overtimeRect(t, l10n.overtimeTodayLabel);
    await rec.record(idle);

    // ── Tipp: Finger auf den Text des Knopfs (die untere Leiste verdeckt
    // dessen unteren Rand), halten, loslassen ─────────────────────────────
    final tapFrame = rec.frames;
    final finger =
        await t.startGesture(t.getCenter(find.text(l10n.startTimeTracking)));
    await rec.record(press);
    expect(rec.frames - 1, release);
    expect(rec.clock(), shortsStart);
    await finger.up();

    // ── nach dem Start: der Timer der App (`Timer.periodic`, 1 s) tickt ──
    int? startedFrame;
    for (var i = 0; i < seconds * _fps + tail; i++) {
      await rec.record(1);
      final frame = rec.frames - 1;
      if (startedFrame == null &&
          find.text(l10n.stopTimeTracking).evaluate().isNotEmpty) {
        startedFrame = frame;
      }
      expect(find.byType(SnackBar), findsNothing);
      final sinceRelease = frame - release;
      if (sinceRelease % _fps == 0) {
        expect(find.text(_timer(sinceRelease ~/ _fps)), findsOneWidget,
            reason: 'Bild $frame');
      }
    }
    expect(startedFrame, isNotNull, reason: 'Timer wurde nicht gestartet');
    expect(t.takeException(), isNull);

    regions['timer'] = _textRect(t, find.text(_timer(seconds)));
    regions['brutto_zeile'] =
        _textRect(t, find.text(l10n.grossAttendance(_timer(seconds))));
    regions['ueberstunden_gesamt'] = _overtimeRect(t, l10n.overtimeTotalLabel);
    regions['heutige_ueberstunden'] = _overtimeRect(t, l10n.overtimeTodayLabel);
    regions['feierabend_zeile'] =
        _textRect(t, find.textContaining(l10n.expectedEndTime('')));
    regions['gleitzeit_null_zeile'] =
        _textRect(t, find.textContaining(l10n.expectedEndTimeWithBalance('')));
    regions['startzeit_feld'] = t.getRect(find
        .ancestor(
            of: find.text(l10n.startTimeLabel),
            matching: find.byType(InputDecorator))
        .first);

    await finger.removePointer();
    await rec.finish(
      marks: {'tipp': tapFrame, 'gestartet': startedFrame!},
      regions: regions,
    );
    await rec.app.close();
  });
}
