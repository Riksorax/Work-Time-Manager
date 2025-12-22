import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

import '../../domain/entities/break_entity.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/work_repository.dart';
import '../models/work_entry_model.dart';

/// Lokales Repository, das Arbeitseinträge in SharedPreferences speichert.
/// Funktioniert komplett offline, ohne Firebase/Internet.
class LocalWorkRepositoryImpl implements WorkRepository {
  static const String _workEntriesPrefix = 'local_work_entries_';
  static const String _monthlyKeysKey = 'local_monthly_keys';

  final SharedPreferences _prefs;

  LocalWorkRepositoryImpl(this._prefs);

  /// Generiert einen Schlüssel für einen bestimmten Monat
  String _getMonthKey(int year, int month) {
    return '$_workEntriesPrefix${year}_${month.toString().padLeft(2, '0')}';
  }

  /// Generiert einen Schlüssel für einen bestimmten Tag
  String _getDayKey(DateTime date) {
    return date.day.toString();
  }

  /// Konvertiert lokale JSON-Daten zu WorkEntryEntity
  WorkEntryEntity _fromLocalJson(Map<String, dynamic> data, DateTime date) {
    return WorkEntryModel(
      id: WorkEntryModel.generateId(date),
      date: date,
      workStart: data['workStart'] != null
          ? DateTime.parse(data['workStart'] as String)
          : null,
      workEnd: data['workEnd'] != null
          ? DateTime.parse(data['workEnd'] as String)
          : null,
      breaks: (data['breaks'] as List<dynamic>?)
              ?.map((breakData) {
                final breakMap = Map<String, dynamic>.from(breakData as Map);
                return _breakFromLocalJson(breakMap);
              })
              .toList() ??
          [],
      manualOvertime: data['manualOvertimeMinutes'] != null
          ? Duration(minutes: data['manualOvertimeMinutes'] as int)
          : null,
      description: data['description'] as String?,
      isManuallyEntered: data['isManuallyEntered'] as bool? ?? false,
    );
  }

  /// Konvertiert WorkEntryEntity zu lokalen JSON-Daten
  Map<String, dynamic> _toLocalJson(WorkEntryEntity entry) {
    return {
      'workStart': entry.workStart?.toIso8601String(),
      'workEnd': entry.workEnd?.toIso8601String(),
      'breaks': entry.breaks.map((b) => _breakToLocalJson(b)).toList(),
      'manualOvertimeMinutes': entry.manualOvertime?.inMinutes,
      'description': entry.description,
      'isManuallyEntered': entry.isManuallyEntered,
    };
  }

  /// Konvertiert lokale JSON-Daten zu BreakEntity
  BreakEntity _breakFromLocalJson(Map<String, dynamic> data) {
    return BreakEntity(
      id: data['id'] as String,
      name: data['name'] as String,
      start: DateTime.parse(data['start'] as String),
      end: data['end'] != null ? DateTime.parse(data['end'] as String) : null,
      isAutomatic: data['isAutomatic'] as bool? ?? false,
    );
  }

  /// Konvertiert BreakEntity zu lokalen JSON-Daten
  Map<String, dynamic> _breakToLocalJson(BreakEntity breakEntity) {
    return {
      'id': breakEntity.id,
      'name': breakEntity.name,
      'start': breakEntity.start.toIso8601String(),
      'end': breakEntity.end?.toIso8601String(),
      'isAutomatic': breakEntity.isAutomatic,
    };
  }

  @override
  Future<WorkEntryEntity> getWorkEntry(DateTime date) async {
    final monthKey = _getMonthKey(date.year, date.month);
    final dayKey = _getDayKey(date);

    logger.i('[LocalWorkRepository] Lade Eintrag für $date (monthKey: $monthKey, dayKey: $dayKey)');

    // Lade Monatsdaten
    final monthDataJson = _prefs.getString(monthKey);
    if (monthDataJson == null) {
      logger.i('[LocalWorkRepository] Kein Eintrag für Monat $monthKey gefunden');
      return WorkEntryModel.empty(date);
    }

    try {
      final decoded = json.decode(monthDataJson);
      final monthData = Map<String, dynamic>.from(decoded as Map);
      final daysMapRaw = monthData['days'];

      if (daysMapRaw == null) {
        logger.i('[LocalWorkRepository] Keine Tage in $monthKey gefunden');
        return WorkEntryModel.empty(date);
      }

      final daysMap = Map<String, dynamic>.from(daysMapRaw as Map);

      if (!daysMap.containsKey(dayKey)) {
        logger.i('[LocalWorkRepository] Kein Eintrag für Tag $dayKey gefunden');
        return WorkEntryModel.empty(date);
      }

      final dayDataRaw = daysMap[dayKey];
      final dayData = Map<String, dynamic>.from(dayDataRaw as Map);
      logger.i('[LocalWorkRepository] Eintrag gefunden: $dayData');
      return _fromLocalJson(dayData, date);
    } catch (e, stackTrace) {
      logger.e('[LocalWorkRepository] Fehler beim Laden: $e', stackTrace: stackTrace);
      return WorkEntryModel.empty(date);
    }
  }

  @override
  Future<List<WorkEntryEntity>> getWorkEntriesForMonth(int year, int month) async {
    final monthKey = _getMonthKey(year, month);
    final monthDataJson = _prefs.getString(monthKey);

    if (monthDataJson == null) {
      return [];
    }

    try {
      final decoded = json.decode(monthDataJson);
      final monthData = Map<String, dynamic>.from(decoded as Map);
      final daysMapRaw = monthData['days'];

      if (daysMapRaw == null) {
        return [];
      }

      final daysMap = Map<String, dynamic>.from(daysMapRaw as Map);
      final entries = <WorkEntryEntity>[];

      for (final entry in daysMap.entries) {
        final dayData = Map<String, dynamic>.from(entry.value as Map);
        final day = int.parse(entry.key);
        final entryDate = DateTime(year, month, day);

        entries.add(_fromLocalJson(dayData, entryDate));
      }

      // Sortiere nach Datum
      entries.sort((a, b) => a.date.compareTo(b.date));
      return entries;
    } catch (e, stackTrace) {
      logger.e('[LocalWorkRepository] Fehler beim Laden der Monatseinträge: $e', stackTrace: stackTrace);
      return [];
    }
  }

  @override
  Future<void> saveWorkEntry(WorkEntryEntity entry) async {
    final monthKey = _getMonthKey(entry.date.year, entry.date.month);
    final dayKey = _getDayKey(entry.date);

    logger.i('[LocalWorkRepository] Speichere Eintrag für ${entry.date} (monthKey: $monthKey, dayKey: $dayKey)');

    // Lade existierende Monatsdaten oder erstelle neue
    Map<String, dynamic> monthData;
    final existingDataJson = _prefs.getString(monthKey);

    if (existingDataJson != null) {
      try {
        final decoded = json.decode(existingDataJson);
        monthData = Map<String, dynamic>.from(decoded as Map);
        // Stelle sicher, dass 'days' auch eine Map<String, dynamic> ist
        if (monthData['days'] != null) {
          monthData['days'] = Map<String, dynamic>.from(monthData['days'] as Map);
        } else {
          monthData['days'] = <String, dynamic>{};
        }
      } catch (e) {
        logger.w('[LocalWorkRepository] Fehler beim Parsen, erstelle neue Daten: $e');
        monthData = {'days': <String, dynamic>{}};
      }
    } else {
      monthData = {'days': <String, dynamic>{}};
    }

    // Füge/Update den Tag
    final daysMap = monthData['days'] as Map<String, dynamic>;
    daysMap[dayKey] = _toLocalJson(entry);

    // Speichere zurück
    try {
      await _prefs.setString(monthKey, json.encode(monthData));

      // Merke den Monatsschlüssel für spätere Sync
      await _addMonthKeyToIndex(monthKey);

      logger.i('[LocalWorkRepository] Erfolgreich gespeichert: ${entry.date}');
      logger.i('[LocalWorkRepository] Gespeicherte Daten: ${_toLocalJson(entry)}');
    } catch (e) {
      logger.e('[LocalWorkRepository] Fehler beim Speichern: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteWorkEntry(String entryId) async {
    final date = WorkEntryModel.parseId(entryId);
    final monthKey = _getMonthKey(date.year, date.month);
    final dayKey = _getDayKey(date);

    final monthDataJson = _prefs.getString(monthKey);
    if (monthDataJson == null) {
      return; // Nichts zu löschen
    }

    try {
      final decoded = json.decode(monthDataJson);
      final monthData = Map<String, dynamic>.from(decoded as Map);
      final daysMapRaw = monthData['days'];

      if (daysMapRaw != null) {
        final daysMap = Map<String, dynamic>.from(daysMapRaw as Map);

        if (daysMap.containsKey(dayKey)) {
          daysMap.remove(dayKey);

          // Wenn keine Tage mehr übrig, lösche den ganzen Monat
          if (daysMap.isEmpty) {
            await _prefs.remove(monthKey);
            await _removeMonthKeyFromIndex(monthKey);
          } else {
            monthData['days'] = daysMap;
            await _prefs.setString(monthKey, json.encode(monthData));
          }

          logger.i('[LocalWorkRepository] Gelöscht: $entryId');
        }
      }
    } catch (e, stackTrace) {
      logger.e('[LocalWorkRepository] Fehler beim Löschen: $e', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Merkt sich alle Monatsschlüssel für spätere Sync-Operationen
  Future<void> _addMonthKeyToIndex(String monthKey) async {
    final existingKeys = _prefs.getStringList(_monthlyKeysKey) ?? [];
    if (!existingKeys.contains(monthKey)) {
      existingKeys.add(monthKey);
      await _prefs.setStringList(_monthlyKeysKey, existingKeys);
    }
  }

  /// Entfernt einen Monatsschlüssel aus dem Index
  Future<void> _removeMonthKeyFromIndex(String monthKey) async {
    final existingKeys = _prefs.getStringList(_monthlyKeysKey) ?? [];
    existingKeys.remove(monthKey);
    await _prefs.setStringList(_monthlyKeysKey, existingKeys);
  }

  /// Gibt alle lokal gespeicherten Arbeitseinträge zurück (für Sync)
  Future<List<WorkEntryEntity>> getAllLocalEntries() async {
    final monthKeys = _prefs.getStringList(_monthlyKeysKey) ?? [];
    final allEntries = <WorkEntryEntity>[];

    for (final monthKey in monthKeys) {
      final monthDataJson = _prefs.getString(monthKey);
      if (monthDataJson == null) continue;

      try {
        final decoded = json.decode(monthDataJson);
        final monthData = Map<String, dynamic>.from(decoded as Map);
        final daysMapRaw = monthData['days'];

        if (daysMapRaw == null) continue;

        final daysMap = Map<String, dynamic>.from(daysMapRaw as Map);

        // Parse Monat/Jahr aus dem Key (Format: local_work_entries_2025_10)
        final parts = monthKey.split('_');
        final year = int.parse(parts[3]);
        final month = int.parse(parts[4]);

        for (final entry in daysMap.entries) {
          final dayData = Map<String, dynamic>.from(entry.value as Map);
          final day = int.parse(entry.key);
          final entryDate = DateTime(year, month, day);

          allEntries.add(_fromLocalJson(dayData, entryDate));
        }
      } catch (e, stackTrace) {
        logger.e('[LocalWorkRepository] Fehler beim Laden von $monthKey: $e', stackTrace: stackTrace);
      }
    }

    return allEntries;
  }

  /// Löscht alle lokalen Arbeitseinträge (nach erfolgreicher Sync)
  Future<void> clearAllLocalEntries() async {
    final monthKeys = _prefs.getStringList(_monthlyKeysKey) ?? [];

    for (final monthKey in monthKeys) {
      await _prefs.remove(monthKey);
    }

    await _prefs.remove(_monthlyKeysKey);
    logger.i('[LocalWorkRepository] Alle lokalen Einträge gelöscht');
  }
}
