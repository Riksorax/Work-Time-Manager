// App-Bilder für die Kurzvideos aus den echten Seiten der App (#575).
//
// Aufruf (aus `mobile/`, ohne Android-SDK):
//
//   flutter test tool/shorts_frames
//
// Schreibt PNG 1080 × 1920 mit sprechendem Namen nach
// `../marketing/shorts/frames/de/`, nur Deutsch. Liegt außerhalb von `test/`
// und läuft deshalb nicht im normalen `flutter test` mit. Rendern und
// Hilfen: `tool/shared/screen_renderer.dart`, Datensatz:
// `tool/store_screenshots/store_data.dart` (beides gemeinsam mit den
// Store-Screenshots). Details: `mobile/CLAUDE.md`, „App-Bilder für
// Kurzvideos (#575)“.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';
import 'package:flutter_work_time/presentation/screens/dashboard_screen.dart';
import 'package:flutter_work_time/presentation/screens/settings_page.dart';
import 'package:flutter_work_time/presentation/view_models/reports_view_model.dart';
import 'package:flutter_work_time/presentation/widgets/work_profile_switcher.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../shared/screen_renderer.dart';
import '../store_screenshots/store_data.dart';
import 'shorts_data.dart';

const _locale = 'de';
const _out = '../marketing/shorts/frames/$_locale';

/// Ein Bild: Dateiname ohne Endung, Motiv und der Zustand, in dem die App
/// startet. Ohne [now]/[entries] gilt der Zustand der Store-Screenshots
/// (16:40 Uhr, Timer läuft seit 7:52 Uhr, Mittagspause 12:10–12:40 Uhr).
class _Frame {
  const _Frame(
    this.name,
    this.motif, {
    this.now,
    this.entries,
    this.profiles = const [],
  });

  final String name;
  final ScreenMotif motif;
  final DateTime? now;
  final Map<String, WorkEntryEntity> Function()? entries;
  final List<WorkProfileEntity> profiles;
}

typedef _Act = Future<void> Function(WidgetTester t, ProviderContainer c);

Finder _dashboardScrollable() => find
    .descendant(
        of: find.byType(DashboardScreen), matching: find.byType(Scrollable))
    .first;

/// Rollt das Dashboard wieder an den Anfang (Timer und Überstunden).
Future<void> _dashboardTop(WidgetTester t, ProviderContainer c) async {
  t.state<ScrollableState>(_dashboardScrollable()).position.jumpTo(0);
  await settle(t, 4);
}

/// Rollt das Dashboard zur Pausenliste, und zwar so, dass der obere Bildrand
/// keine Zeile anschneidet: [anchor] steht als Erstes unter der Titelleiste
/// ([below]: erst die Zeile darunter). Der Pausen-Button am Ende muss dabei
/// im Bild bleiben, sonst bricht der Lauf ab.
Future<void> _dashboardBreaks(WidgetTester t, Finder anchor,
    {bool below = false}) async {
  final scrollable = _dashboardScrollable();
  final position = t.state<ScrollableState>(scrollable).position;
  final viewport = t.getRect(scrollable);
  final rect = t.getRect(anchor.first);
  final target =
      position.pixels + (below ? rect.bottom : rect.top - 8) - viewport.top;
  expect(target, lessThanOrEqualTo(position.maxScrollExtent),
      reason: 'Anker liegt zu tief, der obere Rand schnitte eine Zeile an');
  position.jumpTo(target);
  await settle(t, 4);
  final l10n = l10nOf(t);
  final button = t.getRect(find.text(l10n.addBreak).evaluate().isNotEmpty
      ? find.text(l10n.addBreak)
      : find.text(l10n.stopBreak));
  expect(button.bottom, lessThanOrEqualTo(viewport.bottom - 8),
      reason: 'Pausen-Button liegt nicht mehr im Bild');
}

/// Tippt auf den Text; liegt er außerhalb des Bildes, wird erst hingerollt
/// (ein Tipp daneben träfe sonst z. B. die untere Leiste).
Future<void> _tapText(WidgetTester t, String text) async {
  final target = find.text(text);
  if (target.hitTestable().evaluate().isEmpty) {
    await t.ensureVisible(target.first);
    await settle(t, 2);
  }
  await t.tap(target.first);
  await settle(t, 6);
}

Future<void> _openProfileSwitcher(WidgetTester t, ProviderContainer c) async {
  await t.tap(find.byType(WorkProfileSwitcher));
  await settle(t, 6);
}

_Act _then(List<_Act> steps) => (t, c) async {
      for (final step in steps) {
        await step(t, c);
      }
    };

final _frames = <_Frame>[
  // ── Video „feierabend“ ───────────────────────────────────────────────
  // Morgens, heute noch nichts erfasst.
  _Frame('dashboard_vor_start', const ScreenMotif(),
      now: shortsStart, entries: () => shortsEntries(null)),
  // Derselbe Morgen direkt nach dem Tipp auf „Zeiterfassung starten“.
  _Frame(
    'dashboard_gestartet',
    ScreenMotif(
      act: _then([
        (t, c) => _tapText(t, l10nOf(t).startTimeTracking),
        _dashboardTop,
      ]),
    ),
    now: shortsStart,
    entries: () => shortsEntries(null),
  ),
  // Nachmittags: Timer läuft, Feierabendzeit und Überstunden sichtbar.
  const _Frame('dashboard_timer_laeuft', ScreenMotif()),
  const _Frame('dashboard_dunkel', ScreenMotif(dark: true)),

  // ── Video „pausen“ ───────────────────────────────────────────────────
  // Mittags läuft die Pause (Pausenliste am Ende des Dashboards).
  _Frame(
    'dashboard_pause_laeuft',
    ScreenMotif(
      // Ab der Zeile „Voraussichtlicher Feierabend“.
      act: (t, c) => _dashboardBreaks(
          t, find.textContaining(l10nOf(t).expectedEndTime(''))),
    ),
    now: shortsNoon,
    entries: () => shortsEntries(shortsTodayBreakRunning()),
  ),
  // Nachmittags, den ganzen Tag keine Pause eingetragen: vor dem Stoppen …
  _Frame(
    'stop_vorher_ohne_pause',
    ScreenMotif(
      // Ab der Überschrift „Heutige Überstunden“.
      act: (t, c) =>
          _dashboardBreaks(t, find.text(l10nOf(t).overtimeTodayLabel)),
    ),
    entries: () => shortsEntries(shortsTodayWithoutBreak()),
  ),
  // … und danach: die App hat die Pause ergänzt (Kennzeichen „Automatisch“).
  _Frame(
    'stop_pause_ergaenzt',
    ScreenMotif(
      act: _then([
        (t, c) => _tapText(t, l10nOf(t).stopTimeTracking),
        // Ab dem Wert unter „Heutige Überstunden“ (mit der Überschrift
        // passte die Pausenliste nicht mehr ins Bild).
        (t, c) => _dashboardBreaks(t, find.text(l10nOf(t).overtimeTodayLabel),
            below: true),
      ]),
    ),
    entries: () => shortsEntries(shortsTodayWithoutBreak()),
  ),

  // ── Video „ueberstunden“ ─────────────────────────────────────────────
  // Tagesbericht mit Soll, Ist und Saldo des Tages.
  _Frame(
    'tagesbericht',
    ScreenMotif(
      tab: 0,
      act: (t, c) async {
        await selectReportDay(t, c);
        await scrollTo(t, find.textContaining(l10nOf(t).dailyReportTitle('')),
            alignment: 0.5);
      },
    ),
  ),
  // Einstellungen mit dem Gleitzeit-Saldo.
  _Frame(
    'einstellungen_gleitzeit',
    ScreenMotif(
      page: 2,
      act: (t, c) async {
        // Die Liste baut ihre Zeilen erst beim Rollen auf.
        final title = find.text(l10nOf(t).overtimeBalanceTitle);
        await t.scrollUntilVisible(title, 200,
            scrollable: find
                .descendant(
                    of: find.byType(SettingsPage),
                    matching: find.byType(Scrollable))
                .first);
        // Oben beginnt das Bild mit einer ganzen Zeile (Zeitzone).
        await scrollTo(
            t,
            find.ancestor(
                of: find.text(l10nOf(t).timezoneTitle),
                matching: find.byType(ListTile)),
            alignment: 0);
      },
    ),
  ),
  // Trend mit Wochen-Trend und Prognose zum Jahresende (Premium).
  _Frame(
    'trend_prognose',
    ScreenMotif(
      tab: 4,
      act: (t, c) =>
          scrollTo(t, find.text(l10nOf(t).trendWeekTitle), alignment: 0.02),
    ),
  ),

  // ── Video „pdf“ ──────────────────────────────────────────────────────
  const _Frame('wochenbericht', ScreenMotif(tab: 1, act: selectReportDay)),
  // Monatsbericht des letzten vollständigen Monats.
  _Frame(
    'monatsbericht',
    ScreenMotif(
      tab: 2,
      act: (t, c) async {
        c
            .read(reportsViewModelProvider.notifier)
            .onMonthChanged(DateTime(storeToday.year, storeToday.month - 1));
        await settle(t);
      },
    ),
  ),
  const _Frame('jahr_uebersicht', ScreenMotif(tab: 3)),
  _Frame(
    'jahr_pdf_menue',
    ScreenMotif(
      tab: 3,
      act: (t, c) => _tapText(t, l10nOf(t).exportPdfShortButton),
    ),
  ),

  // ── Video „teaser-projekte“ (nur was es heute gibt) ──────────────────
  // Profil-Wechsler über dem Dashboard.
  _Frame(
    'profile_wechsler',
    const ScreenMotif(act: _openProfileSwitcher),
    profiles: shortsProfiles,
  ),
  // Dialog „Neues Profil“ mit eingetipptem Namen, solange es nur das
  // Standard-Profil gibt (Premium erlaubt ein zusätzliches Profil).
  _Frame(
    'profil_neu_dialog',
    ScreenMotif(
      act: _then([
        _openProfileSwitcher,
        (t, c) => _tapText(t, l10nOf(t).newProfileAction),
        (t, c) async {
          await t.enterText(
              find.descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(TextField)),
              shortsNewProfileName);
          await settle(t, 4);
        },
      ]),
    ),
    profiles: [WorkProfileEntity.defaultProfile()],
  ),
];

void main() {
  setUpAll(() async {
    await loadScreenFonts();
    await initializeDateFormatting(_locale, null);
  });

  for (final frame in _frames) {
    testWidgets(frame.name, (t) async {
      final screen = await renderAppScreen(
        t,
        frame.motif,
        _locale,
        now: frame.now,
        entries: frame.entries?.call(),
        profiles: frame.profiles,
      );
      await writePng(t, screen, '$_out/${frame.name}.png');
    });
  }
}
