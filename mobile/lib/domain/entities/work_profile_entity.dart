import 'package:equatable/equatable.dart';

/// Ein Arbeitszeit-Profil für einen Arbeitgeber/ein Projekt (siehe #138).
///
/// Jeder Nutzer hat immer mindestens das [defaultProfile] - es bildet
/// bestehende Bestandsdaten unverändert an ihrem ursprünglichen Firestore-
/// Pfad (`users/{uid}/work_entries/...` usw.) ab, es findet also **keine**
/// Datenmigration statt. Zusätzliche Profile leben in einer eigenen
/// Subcollection (`users/{uid}/profiles/{id}/...`).
class WorkProfileEntity extends Equatable {
  static const String defaultProfileId = 'default';

  final String id;
  final String name;
  final bool isDefault;

  const WorkProfileEntity({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  factory WorkProfileEntity.defaultProfile() => const WorkProfileEntity(
        id: defaultProfileId,
        name: 'Standard',
        isDefault: true,
      );

  @override
  List<Object?> get props => [id, name, isDefault];
}
