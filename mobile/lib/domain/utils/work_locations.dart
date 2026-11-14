import '../entities/work_entry_entity.dart';
import 'entry_day.dart';

/// Höchstzahl Arbeitsorte je Tag (#526, wie Backend
/// `FirestoreMappings.IsValidWorkLocations` und Web `work-locations.util.ts`).
const int maxWorkLocations = 5;

/// Höchstlänge eines Arbeitsorts in Zeichen (nach Trimmen).
const int maxWorkLocationLength = 60;

/// Höchstzahl Vorschläge in der Orte-Eingabe.
const int maxWorkLocationSuggestions = 10;

String _key(String s) => s.trim().toLowerCase();

/// Bereinigt eine Orte-Liste wie das Backend (`NormalizeWorkLocations`):
/// trimmen, leere Einträge verwerfen, Duplikate ohne Beachtung der
/// Groß-/Kleinschreibung verwerfen (der erste bleibt). Zusätzlich als Schutz
/// vor einem 400: Orte auf 60 Zeichen kürzen und auf 5 Einträge begrenzen.
///
/// `null` bleibt `null` („nicht geändert“, siehe
/// [WorkEntryEntity.workLocations]); sonst immer eine neue Liste.
List<String>? normalizeWorkLocationsOrNull(Iterable<Object?>? raw) =>
    raw == null ? null : normalizeWorkLocations(raw);

/// Wie [normalizeWorkLocationsOrNull], aber `null` ergibt `[]`.
List<String> normalizeWorkLocations(Iterable<Object?>? raw) {
  if (raw == null) return [];
  final seen = <String>{};
  final result = <String>[];
  for (final item in raw) {
    if (item is! String) continue;
    var trimmed = item.trim();
    if (trimmed.length > maxWorkLocationLength) {
      trimmed = trimmed.substring(0, maxWorkLocationLength).trim();
    }
    if (trimmed.isEmpty) continue;
    if (!seen.add(_key(trimmed))) continue;
    result.add(trimmed);
    if (result.length >= maxWorkLocations) break;
  }
  return result;
}

/// Liest ein gespeichertes Feld (Firestore/API/lokal): fehlend oder keine
/// Liste ergibt `[]`, Nicht-Texte werden verworfen.
List<String> readWorkLocations(Object? raw) =>
    raw is List ? raw.whereType<String>().toList() : <String>[];

/// Fehlerart beim Hinzufügen eines Orts.
enum AddWorkLocationError { empty, duplicate, tooLong, max }

/// Ergebnis von [addWorkLocation]: neue Liste (bei Fehler die unveränderte)
/// und ggf. die Fehlerart.
class AddWorkLocationResult {
  final List<String> locations;
  final AddWorkLocationError? error;

  const AddWorkLocationResult(this.locations, [this.error]);
}

/// Fügt einen Ort hinzu, sofern gültig (nicht leer, höchstens 60 Zeichen,
/// kein Duplikat, höchstens 5 Orte). Reihenfolge der Prüfungen wie im Web.
AddWorkLocationResult addWorkLocation(List<String> current, String input) {
  final value = input.trim();
  final copy = List<String>.of(current);
  if (value.isEmpty) {
    return AddWorkLocationResult(copy, AddWorkLocationError.empty);
  }
  if (value.length > maxWorkLocationLength) {
    return AddWorkLocationResult(copy, AddWorkLocationError.tooLong);
  }
  if (current.any((c) => _key(c) == _key(value))) {
    return AddWorkLocationResult(copy, AddWorkLocationError.duplicate);
  }
  if (current.length >= maxWorkLocations) {
    return AddWorkLocationResult(copy, AddWorkLocationError.max);
  }
  return AddWorkLocationResult([...copy, value]);
}

/// Ein Tag mit Orten als Quelle für Vorschläge.
class WorkLocationDay {
  /// Kalendertag (nur für die Reihenfolge, jüngster zuerst).
  final DateTime day;
  final List<String> locations;

  const WorkLocationDay(this.day, this.locations);
}

/// Vorschläge aus bereits bekannten Tagen (kein zusätzlicher Lesezugriff):
/// zuletzt verwendete zuerst (jüngster Tag zuerst, innerhalb eines Tages in
/// gespeicherter Reihenfolge), ohne Duplikate (Groß-/Kleinschreibung egal) und
/// ohne die schon gewählten, höchstens [limit]. Mit [filter] nur Orte, die den
/// Text enthalten. Wie Web `suggestWorkLocations`.
List<String> suggestWorkLocations(
  Iterable<WorkLocationDay> days, {
  List<String> selected = const [],
  int limit = maxWorkLocationSuggestions,
  String filter = '',
}) {
  final taken = selected.map(_key).toSet();
  final needle = _key(filter);
  final sorted = days.toList()..sort((a, b) => b.day.compareTo(a.day));
  final out = <String>[];
  for (final d in sorted) {
    for (final loc in d.locations) {
      final k = _key(loc);
      if (k.isEmpty || taken.contains(k)) continue;
      if (needle.isNotEmpty && !k.contains(needle)) continue;
      taken.add(k);
      out.add(loc.trim());
      if (out.length >= limit) return out;
    }
  }
  return out;
}

/// Arbeitsorte je Kalendertag (lokale Mitternacht, Tag über [entryDay]) aus
/// bereits geladenen Einträgen, nur Typ „Arbeit“ (#526, PDF-Tagesliste).
/// Mehrere Einträge eines Tages werden in ihrer Reihenfolge zusammengeführt
/// (ohne Duplikate, Groß-/Kleinschreibung egal); Tage ohne Orte fehlen.
Map<DateTime, List<String>> workLocationsByDay(
    Iterable<WorkEntryEntity> entries) {
  final result = <DateTime, List<String>>{};
  for (final e in entries) {
    if (e.type != WorkEntryType.work) continue;
    final locs = normalizeWorkLocations(e.locations);
    if (locs.isEmpty) continue;
    final list = result.putIfAbsent(entryDay(e), () => <String>[]);
    for (final loc in locs) {
      if (!list.any((l) => _key(l) == _key(loc))) list.add(loc);
    }
  }
  return result;
}
