import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../domain/entities/work_profile_entity.dart';

final workProfileViewModelProvider =
    Provider<WorkProfileViewModel>((ref) => WorkProfileViewModel(ref));

/// Wird geworfen, wenn kein Nutzer eingeloggt ist - zusätzliche
/// Arbeitszeit-Profile sind ein Premium-Feature, das ein Login voraussetzt
/// (siehe #138).
class WorkProfilesNotAvailableException implements Exception {
  const WorkProfilesNotAvailableException();

  @override
  String toString() => 'Arbeitszeit-Profile erfordern einen eingeloggten Nutzer';
}

/// Kapselt Anlegen und Löschen zusätzlicher Arbeitszeit-Profile (#138) inkl.
/// der Folge-Effekte (Profil-Liste neu laden, aktives Profil ggf.
/// zurücksetzen), damit die Dialoge nicht direkt auf
/// `WorkProfileRepository` zugreifen (siehe #294).
class WorkProfileViewModel {
  WorkProfileViewModel(this._ref);
  final Ref _ref;

  Future<WorkProfileEntity> addProfile(String name) async {
    final repository = _ref.read(core_providers.workProfileRepositoryProvider);
    if (repository == null) throw const WorkProfilesNotAvailableException();

    final profile = await repository.addProfile(name);
    _ref.invalidate(core_providers.workProfilesProvider);
    _ref.read(core_providers.activeWorkProfileIdProvider.notifier).setActiveProfile(profile.id);
    return profile;
  }

  Future<void> deleteProfile(String profileId) async {
    final repository = _ref.read(core_providers.workProfileRepositoryProvider);
    if (repository == null) throw const WorkProfilesNotAvailableException();

    await repository.deleteProfile(profileId);
    _ref.invalidate(core_providers.workProfilesProvider);
    // Falls das gelöschte Profil gerade aktiv war, zurück auf Standard.
    if (_ref.read(core_providers.activeWorkProfileIdProvider) == profileId) {
      _ref.read(core_providers.activeWorkProfileIdProvider.notifier).setActiveProfile(null);
    }
  }
}
