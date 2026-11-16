// Zustände des heutigen Tages für die App-Bilder der Kurzvideos (#575).
//
// Alles baut auf dem Datensatz der Store-Screenshots auf
// (`../store_screenshots/store_data.dart`): gleiche Person, gleiche
// Vergangenheit, gleicher Kalendertag (Mi 11.11.2026). Hier ändert sich nur
// der heutige Eintrag und die Uhrzeit. Keine echten Nutzerdaten.

import 'package:flutter_work_time/domain/entities/break_entity.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/domain/entities/work_profile_entity.dart';

import '../store_screenshots/store_data.dart';

DateTime _today(int hour, int minute) =>
    DateTime(storeToday.year, storeToday.month, storeToday.day, hour, minute);

/// Arbeitsbeginn des heutigen Tages (wie `storeTodayEntry`).
final shortsStart = _today(7, 52);

/// Mittags, 15 Minuten nach Beginn der laufenden Pause.
final shortsNoon = _today(12, 25);

/// Früher Nachmittag, 35 Minuten nach dem Ende der Mittagspause (Beginn der
/// Bildfolge `feierabend_mittags`).
final shortsAfterLunch = _today(13, 30);

/// Langer Tag: Beginn der Bildfolge `pausen_ergaenzt_lang`, seit 7:52 Uhr
/// ohne Pause, also über 9 Stunden.
final shortsLongDayEnd = _today(17, 30);

/// Arbeitsbeginn und Mittagspause des Tages in `feierabend_mittags`.
final shortsLateStart = _today(8, 7);
final shortsLunchStart = _today(12, 10);
final shortsLunchEnd = _today(12, 55);

/// Der Datensatz mit [today] als heutigem Eintrag; `null` = heute noch
/// nichts erfasst.
Map<String, WorkEntryEntity> shortsEntries(WorkEntryEntity? today) {
  final entries = buildStoreEntries(storeTextsDe)
    ..remove(storeDayKey(storeToday));
  if (today != null) entries[today.id] = today;
  return entries;
}

/// Heute läuft der Timer seit 7:52 Uhr, ohne eine einzige Pause.
WorkEntryEntity shortsTodayWithoutBreak() =>
    storeTodayEntry(storeTextsDe).copyWith(breaks: const []);

/// Heute läuft der Timer seit 7:52 Uhr, die Mittagspause läuft seit 12:10 Uhr.
WorkEntryEntity shortsTodayBreakRunning() =>
    storeTodayEntry(storeTextsDe).copyWith(breaks: [
      BreakEntity(
        id: 'l-today',
        name: storeTextsDe.lunch,
        start: _today(12, 10),
      ),
    ]);

/// Heute läuft der Timer seit 8:07 Uhr, die Mittagspause von 45 Minuten
/// (12:10 bis 12:55 Uhr) ist abgeschlossen.
WorkEntryEntity shortsTodayAfterLunch() =>
    storeTodayEntry(storeTextsDe).copyWith(
      workStart: shortsLateStart,
      breaks: [
        BreakEntity(
          id: 'l-today',
          name: storeTextsDe.lunch,
          start: shortsLunchStart,
          end: shortsLunchEnd,
        ),
      ],
    );

/// Arbeitszeit-Profile, wie es sie heute gibt: das Standard-Profil (heißt in
/// der App fest „Standard“) und ein selbst angelegtes. Mehr als ein
/// zusätzliches Profil lässt die App derzeit nicht zu.
final shortsProfiles = [
  WorkProfileEntity.defaultProfile(),
  const WorkProfileEntity(id: 'nebenjob', name: shortsNewProfileName),
];

/// Name, der im Dialog „Neues Profil“ eingetippt wird.
const shortsNewProfileName = 'Nebenjob';
