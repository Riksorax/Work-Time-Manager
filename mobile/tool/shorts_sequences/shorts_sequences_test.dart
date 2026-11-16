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
// ein anderes ffmpeg, `--dart-define=SHORTS_SEQUENCE_TRACE=true` gibt je Bild
// die Scroll-Position aus. Getrennt von den Standbildern
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

/// `--dart-define=SHORTS_SEQUENCE_TRACE=true` gibt je Bild die Scroll-Position
/// aus (zum Abstimmen der Wischgesten).
const _trace = bool.fromEnvironment('SHORTS_SEQUENCE_TRACE');

/// Weg des Fingers bei den beiden Wischgesten in logischen Pixeln. So
/// gewählt, dass das Ausschwingen die Seite gerade bis ans Ende bzw. an den
/// Anfang trägt und dort weich ankommt (Seite scrollt vor dem Start 193,6).
const _swipeUpDistance = 158.0;
const _swipeDownDistance = 160.0;

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

  // Morgens: Dashboard steht ruhig, Wisch nach oben bis zum Knopf
  // „Zeiterfassung starten“ (er liegt am Seitenanfang im unteren Bereich,
  // den TikTok/Instagram mit ihren Bedienelementen überdecken), Tipp, Wisch
  // zurück an den Seitenanfang, dort läuft der Timer im Sekundentakt.
  testWidgets('start_morgens', timeout: const Timeout(Duration(minutes: 30)),
      (t) async {
    const idle = 30; // 1,0 s ruhig stehen
    const swipe = 13; // Finger zieht 0,43 s
    const settle = 21; // Ausschwingen und Ruhe bis zum Tipp (0,7 s)
    const rest = 9; // davon mindestens 0,3 s ohne jede Bewegung
    const press = 6; // Finger 0,2 s auf dem Knopf
    const hold = 18; // 0,6 s „Zeiterfassung beenden“ zeigen
    const top = 150; // 5 s am Seitenanfang
    // Bild, mit dem der Finger loslässt. In diesem Augenblick ist es genau
    // 7:52:00 Uhr (die App rundet die Startzeit auf die Minute), die Folge
    // beginnt entsprechend früher.
    const release = idle + 1 + swipe + settle + press - 1;
    // Freie Mitte des Videos: oben verdecken die Plattformen bis y ≈ 0,13,
    // unten ab y ≈ 0,78.
    const freeTop = 0.15;
    const freeBottom = 0.75;

    final rec = _Recorder(t, 'start_morgens',
        startsAt: shortsStart.subtract(_timeOf(release)));
    rec.app = await openAppScreen(t, const ScreenMotif(), _locale,
        clock: rec.clock, entries: shortsEntries(null));
    final l10n = l10nOf(t);
    final regions = <String, Rect>{};
    final marks = <String, int>{};

    final startButton = find.widgetWithText(
        ElevatedButton, l10n.startTimeTracking,
        skipOffstage: true);
    final stopButton = find.widgetWithText(
        ElevatedButton, l10n.stopTimeTracking,
        skipOffstage: true);
    expect(startButton, findsOneWidget);
    final scroll = Scrollable.of(t.element(startButton)).position;

    /// Die Seite steht: kein Scrollen, kein Ausschwingen, keine Animation.
    bool quiet() =>
        !scroll.isScrollingNotifier.value && !t.binding.hasScheduledFrame;

    /// Nimmt ein Bild auf und prüft, was in jedem Bild gelten muss: keine
    /// Fehlermeldung, kein Überlauf, und zu jeder vollen Sekunde nach dem
    /// Loslassen zeigt der Timer genau diese Sekunde.
    Future<void> frame() async {
      await rec.record(1);
      final frame = rec.frames - 1;
      if (_trace) {
        debugPrint('Bild $frame: ${scroll.pixels.toStringAsFixed(1)}'
            '${quiet() ? '' : ' bewegt'}');
      }
      expect(find.byType(SnackBar), findsNothing, reason: 'Bild $frame');
      expect(t.takeException(), isNull, reason: 'Bild $frame');
      final sinceRelease = frame - release;
      if (sinceRelease > 0 && sinceRelease % _fps == 0) {
        expect(find.text(_timer(sinceRelease ~/ _fps)), findsOneWidget,
            reason: 'Bild $frame');
      }
    }

    /// Echte Wischgeste: Finger bei [from] aufsetzen, in [swipe] Bildern um
    /// [dy] ziehen (zum Ende etwas schneller) und in der Bewegung abheben,
    /// sodass die Seite ausschwingt. Die Zeitstempel der Zeigerereignisse
    /// sind die Zeiten der Bilder, daraus bestimmt Flutter die
    /// Geschwindigkeit beim Abheben. Gibt die Nummer des Bildes zurück, mit
    /// dem der Finger aufsetzt.
    Future<int> swipeBy(Offset from, double dy) async {
      const speedup = 0.1;
      final first = rec.frames;
      final finger = await t.createGesture();
      await finger.down(from, timeStamp: _timeOf(first));
      await frame();
      for (var i = 1; i <= swipe; i++) {
        final u = i / swipe;
        final part = (1 - speedup) * u + speedup * u * u;
        await finger.moveTo(from + Offset(0, dy * part),
            timeStamp: _timeOf(first + i));
        // Abheben noch vor dem letzten Bild der Geste: Das Ausschwingen
        // beginnt dann mit diesem Bild und schließt ohne Standbild an.
        if (i == swipe) await finger.up(timeStamp: _timeOf(first + i));
        await frame();
      }
      return first;
    }

    Offset at(double x, double y) =>
        Offset(screenLogicalWidth * x, screenHeight / screenDpr * y);

    // ── vor dem Start, Seitenanfang ────────────────────────────────────
    expect(scroll.pixels, 0);
    regions['timer_vor_start'] = _textRect(t, find.text(_timer(0)));
    for (var i = 0; i < idle; i++) {
      await frame();
    }

    // ── Wisch nach oben bis ans Seitenende: weiter kann die Seite vor dem
    // Start nicht scrollen, der Knopf steht dann in der freien Mitte ──────
    marks['wisch_hoch'] = await swipeBy(at(0.75, 0.68), -_swipeUpDistance);
    var quietFrames = 0;
    for (var i = 0; i < settle; i++) {
      await frame();
      quietFrames = quiet() ? quietFrames + 1 : 0;
    }
    expect(quietFrames, greaterThanOrEqualTo(rest),
        reason: 'Seite steht vor dem Tipp nicht lange genug ruhig');
    expect(scroll.pixels, scroll.maxScrollExtent);

    // ── Tipp auf den Knopf: Finger aufsetzen, halten, loslassen ─────────
    final startRect = t.getRect(startButton);
    regions['start_knopf'] = startRect;
    final startPart = _fraction(startRect);
    expect(startPart['y'], greaterThanOrEqualTo(freeTop));
    expect(startPart['y']! + startPart['hoehe']!, lessThanOrEqualTo(freeBottom),
        reason: 'Start-Knopf liegt beim Tipp nicht in der freien Mitte');
    marks['tipp'] = rec.frames;
    final finger = await t.createGesture();
    await finger.down(startRect.center, timeStamp: _timeOf(rec.frames));
    for (var i = 0; i < press; i++) {
      await frame();
    }
    expect(rec.frames - 1, release);
    expect(rec.clock(), shortsStart);
    await finger.up(timeStamp: _timeOf(release));

    // ── nach dem Start: der Timer der App (`Timer.periodic`, 1 s) tickt,
    // der Knopf heißt jetzt „Zeiterfassung beenden“ ──────────────────────
    while (stopButton.evaluate().isEmpty) {
      expect(rec.frames - release, lessThan(_fps),
          reason: 'Timer wurde nicht gestartet');
      await frame();
    }
    marks['gestartet'] = rec.frames - 1;
    expect(startButton, findsNothing);
    final stopRect = t.getRect(stopButton);
    regions['beenden_knopf'] = stopRect;
    final stopPart = _fraction(stopRect);
    expect(stopPart['y'], greaterThanOrEqualTo(freeTop));
    expect(stopPart['y']! + stopPart['hoehe']!, lessThanOrEqualTo(freeBottom),
        reason: 'Beenden-Knopf liegt nicht in der freien Mitte');
    for (var i = 1; i < hold; i++) {
      await frame();
    }
    expect(t.getRect(stopButton), stopRect);

    // ── Wisch zurück an den Seitenanfang ───────────────────────────────
    marks['wisch_runter'] = await swipeBy(at(0.75, 0.36), _swipeDownDistance);
    while (scroll.pixels != 0 || !quiet()) {
      expect(rec.frames - marks['wisch_runter']!, lessThan(3 * _fps),
          reason: 'Seite kommt nicht am Anfang zur Ruhe');
      await frame();
    }
    // Das zuletzt aufgenommene Bild zeigt die Seite schon ruhig am Anfang.
    marks['oben'] = rec.frames - 1;

    // ── am Seitenanfang: der Timer zählt weiter ────────────────────────
    for (var i = 1; i < top; i++) {
      await frame();
    }
    expect(scroll.pixels, 0);
    final seconds = (rec.frames - 1 - release) ~/ _fps;

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

    await rec.finish(marks: marks, regions: regions);
    await rec.app.close();
  });
}
