import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:intl/intl.dart';

import '../../domain/entities/work_entry_entity.dart';
import '../../domain/entities/break_entity.dart';
import 'break_model.dart';

/// Das WorkEntryModel ist das Daten-Transfer-Objekt (DTO), das direkt
/// mit Firestore kommuniziert.
///
/// Es erbt von WorkEntryEntity, um mit der Domain-Schicht kompatibel zu sein,
/// fügt aber die spezifische Logik für die Serialisierung (Umwandlung in eine Map)
/// und Deserialisierung (Erstellung aus einer Map) hinzu.
class WorkEntryModel extends WorkEntryEntity {
  const WorkEntryModel({
    required super.id,
    required super.date,
    super.workStart,
    super.workEnd,
    super.breaks = const [],
    super.manualOvertime,
  });

  /// Eine statische Helfermethode, um konsistent die Dokumenten-ID
  /// für einen bestimmten Tag zu generieren (z.B. "2024-05-21").
  /// Dies verhindert Duplikate und macht das Abrufen von Einträgen einfach.
  static String generateId(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// Eine Factory, um ein leeres, initiales Model für einen Tag zu erstellen,
  /// falls noch kein Eintrag in Firestore existiert. Dies vereinfacht die Logik
  /// im Repository und ViewModel, da sie immer ein gültiges Objekt erhalten.
  factory WorkEntryModel.empty(DateTime date) {
    return WorkEntryModel(
      id: generateId(date),
      date: DateUtils.dateOnly(date), // Stelle sicher, dass keine Zeitkomponente enthalten ist
      breaks: const [],
    );
  }

  /// Eine Factory, um eine reine Domain-Entity in ein speicherbares Model umzuwandeln.
  /// Wird vom WorkRepositoryImpl aufgerufen, bevor Daten an die FirestoreDataSource
  /// gesendet werden.
  factory WorkEntryModel.fromEntity(WorkEntryEntity entity) {
    return WorkEntryModel(
      id: entity.id,
      date: entity.date,
      workStart: entity.workStart,
      workEnd: entity.workEnd,
      manualOvertime: entity.manualOvertime,
      // Konvertiere auch die untergeordneten Break-Entities in speicherbare Break-Models.
      breaks: entity.breaks.map((e) => BreakModel.fromEntity(e)).toList(),
    );
  }

  /// Deserialisierung: Erstellt ein WorkEntryModel aus einem Firestore DocumentSnapshot.
  /// Dies ist der "Eingang" von der Datenbank in die App.
  factory WorkEntryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      // Dieser Fall sollte selten auftreten, ist aber ein wichtiges Sicherheitsnetz.
      throw StateError("Konnte kein WorkEntryModel aus einem leeren Snapshot erstellen!");
    }
    return WorkEntryModel(
      id: snapshot.id,
      // Konvertiere Firestore `Timestamp` zurück in Dart `DateTime`.
      date: (data['date'] as Timestamp).toDate(),
      workStart: (data['workStart'] as Timestamp?)?.toDate(),
      workEnd: (data['workEnd'] as Timestamp?)?.toDate(),
      // Deserialisiere die Liste der Pausen. `data['breaks']` ist eine `List<dynamic>`,
      // wobei jedes Element eine `Map<String, dynamic>` ist.
      breaks: (data['breaks'] as List<dynamic>?)
          ?.map((breakData) => BreakModel.fromMap(breakData as Map<String, dynamic>))
          .toList() ??
          [],
      // Konvertiere die gespeicherten Minuten zurück in eine `Duration`.
      manualOvertime: data['manualOvertimeMinutes'] != null
          ? Duration(minutes: data['manualOvertimeMinutes'] as int)
          : null,
    );
  }

  /// Serialisierung: Wandelt das WorkEntryModel in eine Map<String, dynamic> um,
  /// die Firestore versteht und speichern kann. Dies ist der "Ausgang" aus der App
  /// in die Datenbank.
  Map<String, dynamic> toFirestore() {
    return {
      // Wir speichern das Datum ohne Zeitkomponente als Timestamp.
      'date': Timestamp.fromDate(DateUtils.dateOnly(date)),
      // Konvertiere DateTime? in Firestore Timestamp?.
      'workStart': workStart != null ? Timestamp.fromDate(workStart!) : null,
      'workEnd': workEnd != null ? Timestamp.fromDate(workEnd!) : null,
      // Rufe die toMap-Methode für jedes BreakModel in der Liste auf.
      'breaks': (breaks as List<BreakModel>).map((b) => b.toMap()).toList(),
      // Speichere Duration als einfache Minutenanzahl (Integer), da Firestore
      // keinen eigenen Duration-Typ hat.
      'manualOvertimeMinutes': manualOvertime?.inMinutes,
    };
  }
}