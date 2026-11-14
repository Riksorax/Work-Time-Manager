import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/work_entry_entity.dart';
import '../../domain/utils/entry_day.dart';
import '../../domain/utils/work_locations.dart';

/// Merkt sich die Arbeitsorte der Einträge, die die App ohnehin lädt oder
/// speichert (#526), damit die Vorschläge auch nach einem Neustart da sind,
/// ohne zusätzlichen API-/Firestore-Lesezugriff. Pendant zum Web
/// `WorkLocationHistoryService`.
///
/// Je Nutzer und Profil (eigener SharedPreferences-Schlüssel, Muster der
/// profilbezogenen Einstellungen) höchstens die letzten [maxDays] Tage mit
/// Orten. Reine Datenhaltung, keine Netzzugriffe; Fehler beim Lesen oder
/// Schreiben werden geschluckt (Vorschläge sind nur Komfort).
class WorkLocationHistory {
  /// Höchstzahl gemerkter Tage je Nutzer und Profil (wie Web).
  static const int maxDays = 40;

  final SharedPreferences _prefs;

  /// SharedPreferences-Schlüssel dieses Nutzers/Profils.
  final String storageKey;

  List<_StoredDay>? _cache;

  WorkLocationHistory(this._prefs, {required String userId, String? profileId})
      : storageKey = keyFor(userId: userId, profileId: profileId);

  /// Schlüssel je Nutzer (`local` im Gast-Modus) und Profil; das
  /// Standard-Profil hat kein Suffix (wie `SettingsRepositoryImpl`).
  static String keyFor({required String userId, String? profileId}) {
    final suffix =
        (profileId == null || profileId == 'default') ? '' : '_$profileId';
    return 'work_location_history_$userId$suffix';
  }

  /// Übernimmt die Orte der übergebenen Einträge. Einträge mit
  /// `workLocations == null` (Orte unbekannt, z. B. frischer Schnelleintrag)
  /// ändern nichts; ein Tag ohne Orte oder mit anderem Typ als „Arbeit“
  /// entfernt einen früher gemerkten Tag.
  void record(Iterable<WorkEntryEntity> entries) {
    final byDay = {for (final s in _load()) s.day: s};
    var changed = false;
    for (final e in entries) {
      final raw = e.workLocations;
      if (raw == null) continue;
      final day = localDateFromEntryId(e.id) != null ? e.id : null;
      if (day == null) continue;
      final locs = e.type == WorkEntryType.work
          ? normalizeWorkLocations(raw)
          : const <String>[];
      final prev = byDay[day];
      if (locs.isEmpty) {
        if (prev != null) {
          byDay.remove(day);
          changed = true;
        }
        continue;
      }
      if (prev == null || prev.locations.join('\n') != locs.join('\n')) {
        byDay[day] = _StoredDay(day, locs);
        changed = true;
      }
    }
    if (!changed) return;
    final sorted = byDay.values.toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    _cache = sorted.take(maxDays).toList();
    try {
      _prefs
          .setString(
              storageKey,
              jsonEncode([
                for (final s in _cache!) {'d': s.day, 'l': s.locations}
              ]))
          .catchError((_) => false);
    } catch (_) {
      // Speichern ist nur Komfort.
    }
  }

  /// Vorschläge (zuletzt verwendete zuerst, höchstens 10, ohne [selected]),
  /// optional gefiltert auf Orte, die [filter] enthalten.
  List<String> suggestions(List<String> selected, {String filter = ''}) {
    return suggestWorkLocations(
      [
        for (final s in _load())
          WorkLocationDay(
              localDateFromEntryId(s.day) ?? DateTime(0), s.locations),
      ],
      selected: selected,
      filter: filter,
    );
  }

  List<_StoredDay> _load() {
    final cached = _cache;
    if (cached != null) return cached;
    var result = <_StoredDay>[];
    try {
      final raw = _prefs.getString(storageKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          result = [
            for (final item in decoded)
              if (item is Map &&
                  item['d'] is String &&
                  localDateFromEntryId(item['d'] as String) != null)
                _StoredDay(item['d'] as String, readWorkLocations(item['l'])),
          ];
        }
      }
    } catch (_) {
      result = [];
    }
    _cache = result;
    return result;
  }
}

class _StoredDay {
  /// Tag als `yyyy-MM-dd` (Eintrags-Id).
  final String day;
  final List<String> locations;

  const _StoredDay(this.day, this.locations);
}
