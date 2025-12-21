import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:intl/intl.dart';

import '../../domain/entities/work_entry_entity.dart';
import '../../domain/entities/break_entity.dart';
import 'break_model.dart';

class WorkEntryModel extends WorkEntryEntity {
  const WorkEntryModel({
    required super.id,
    required super.date,
    super.workStart,
    super.workEnd,
    super.breaks = const [],
    super.manualOvertime,
    super.description,
    super.isManuallyEntered,
    super.type,
  });

  static String generateId(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static DateTime parseId(String id) => DateFormat('yyyy-MM-dd').parse(id);

  factory WorkEntryModel.empty(DateTime date) {
    return WorkEntryModel(
      id: generateId(date),
      date: DateUtils.dateOnly(date),
      breaks: const [],
    );
  }

  factory WorkEntryModel.fromEntity(WorkEntryEntity entity) {
    return WorkEntryModel(
      id: entity.id,
      date: entity.date,
      workStart: entity.workStart,
      workEnd: entity.workEnd,
      manualOvertime: entity.manualOvertime,
      breaks: entity.breaks.map((e) => BreakModel.fromEntity(e)).toList(),
      description: entity.description,
      isManuallyEntered: entity.isManuallyEntered,
      type: entity.type,
    );
  }

  factory WorkEntryModel.fromMap(Map<String, dynamic> map) {
    return WorkEntryModel(
      id: '', // Die ID ist nicht Teil der Map, sie wird vom Aufrufer gesetzt.
      date: (map['date'] as Timestamp).toDate(),
      workStart: (map['workStart'] as Timestamp?)?.toDate(),
      workEnd: (map['workEnd'] as Timestamp?)?.toDate(),
      breaks: (map['breaks'] as List<dynamic>?)
              ?.map((breakData) => BreakModel.fromMap(breakData as Map<String, dynamic>))
              .toList() ??
          [],
      manualOvertime: map['manualOvertimeMinutes'] != null
          ? Duration(minutes: map['manualOvertimeMinutes'] as int)
          : null,
      description: map['description'] as String?,
      isManuallyEntered: map['isManuallyEntered'] as bool? ?? false,
      type: map['type'] != null
          ? WorkEntryType.values.firstWhere(
              (e) => e.name == map['type'],
              orElse: () => WorkEntryType.work,
            )
          : WorkEntryType.work,
    );
  }

  factory WorkEntryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError("Konnte kein WorkEntryModel aus einem leeren Snapshot erstellen!");
    }
    return WorkEntryModel.fromMap(data).copyWith(id: snapshot.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(DateTime.utc(date.year, date.month, date.day)),
      'workStart': workStart != null ? Timestamp.fromDate(workStart!) : null,
      'workEnd': workEnd != null ? Timestamp.fromDate(workEnd!) : null,
      'breaks': (breaks as List<BreakModel>).map((b) => b.toMap()).toList(),
      'manualOvertimeMinutes': manualOvertime?.inMinutes,
      'description': description,
      'isManuallyEntered': isManuallyEntered,
      'type': type.name,
    };
  }

  Map<String, dynamic> toFirestore() {
    return toMap();
  }

  @override
  WorkEntryModel copyWith({
    String? id,
    DateTime? date,
    DateTime? workStart,
    DateTime? workEnd,
    List<BreakEntity>? breaks,
    Duration? manualOvertime,
    String? description,
    bool? isManuallyEntered,
    WorkEntryType? type,
  }) {
    return WorkEntryModel(
      id: id ?? this.id,
      date: date ?? this.date,
      workStart: workStart ?? this.workStart,
      workEnd: workEnd ?? this.workEnd,
      breaks: breaks ?? this.breaks,
      manualOvertime: manualOvertime ?? this.manualOvertime,
      description: description ?? this.description,
      isManuallyEntered: isManuallyEntered ?? this.isManuallyEntered,
      type: type ?? this.type,
    );
  }
}
