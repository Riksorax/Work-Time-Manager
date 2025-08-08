import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/break_entity.dart';

/// Das BreakModel ist das DTO für eine einzelne Pause.
///
/// Es erbt von BreakEntity, um die Kompatibilität mit der Domain-Schicht
/// zu gewährleisten, und fügt die Logik für die (De-)Serialisierung
/// für Firestore hinzu.
class BreakModel extends BreakEntity {
  const BreakModel({
    required super.name,
    required super.start,
    super.end,
  });

  /// Erstellt ein BreakModel aus einer reinen BreakEntity.
  /// Dies wird beim Speichern von Daten verwendet.
  factory BreakModel.fromEntity(BreakEntity entity) {
    return BreakModel(
      name: entity.name,
      start: entity.start,
      end: entity.end,
    );
  }

  /// Deserialisierung: Erstellt ein BreakModel aus einer Map.
  ///
  /// Firestore speichert Listen von Objekten als List<dynamic>, wobei jedes
  /// Element eine Map ist. Diese Factory wird von WorkEntryModel.fromFirestore
  /// aufgerufen, um jede Pause in der Liste zu deserialisieren.
  factory BreakModel.fromMap(Map<String, dynamic> map) {
    return BreakModel(
      name: map['name'] as String? ?? 'Pause', // Fallback, falls der Name fehlt
      start: (map['start'] as Timestamp).toDate(),
      end: (map['end'] as Timestamp?)?.toDate(),
    );
  }

  /// Serialisierung: Wandelt das BreakModel in eine Map um.
  ///
  /// Diese Map wird dann als Teil der breaks-Liste im Firestore-Dokument
  /// des WorkEntryModel gespeichert.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      // Wandle Dart DateTime in Firestore Timestamp um.
      'start': Timestamp.fromDate(start),
      // Wandle das optionale DateTime? in ein optionales Timestamp? um.
      'end': end != null ? Timestamp.fromDate(end!) : null,
    };
  }
}