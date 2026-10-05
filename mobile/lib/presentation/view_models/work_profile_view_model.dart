import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../core/utils/logger.dart';
import '../../domain/entities/work_profile_entity.dart';
import 'dashboard_view_model.dart';

final workProfileViewModelProvider =
    Provider<WorkProfileViewModel>((ref) => WorkProfileViewModel(ref));

/// Wird geworfen, wenn kein Nutzer eingeloggt ist - zusätzliche
/// Arbeitszeit-Profile sind ein Premium-Feature, das ein Login voraussetzt
/// (siehe #138).
class WorkProfilesNotAvailableException implements Exception {
  const WorkProfilesNotAvailableException();

  @override
  String toString() =>
      'Arbeitszeit-Profile erfordern einen eingeloggten Nutzer';
}

/// Ergebnis von [WorkProfileViewModel.checkSwitchAllowed] (#388).
enum ProfileSwitchGuardResult {
  /// Wechsel darf erfolgen (nichts lief oder der Timer wurde gespeichert).
  allowed,

  /// Der Nutzer hat im Bestätigungsdialog abgebrochen.
  cancelled,

  /// Der laufende Timer konnte nicht gespeichert werden: nicht wechseln.
  saveFailed,

  /// Es läuft bereits eine Prüfung (Dialog offen): ignorieren.
  busy,
}

/// Kapselt Anlegen und Löschen zusätzlicher Arbeitszeit-Profile (#138) inkl.
/// der Folge-Effekte (Profil-Liste neu laden, aktives Profil ggf.
/// zurücksetzen), damit die Dialoge nicht direkt auf
/// `WorkProfileRepository` zugreifen (siehe #294).
class WorkProfileViewModel {
  WorkProfileViewModel(this._ref);
  final Ref _ref;

  /// Sperre gegen parallele Prüfungen (Dialog offen, Stop läuft).
  bool _switchPending = false;

  /// Prüft vor einem Profilwechsel (Wechsler, "Neues Profil"), ob im Dashboard
  /// ein Timer läuft (#388). Läuft einer, fragt [confirm] den Nutzer; bei
  /// Bestätigung wird der Timer im alten Profil über den normalen Stop-Pfad
  /// gespeichert. Gewechselt wird erst bei [ProfileSwitchGuardResult.allowed],
  /// und zwar vom Aufrufer. Während des Ladens gibt es keinen Dialog.
  /// `deleteProfile`, Logout und App-Neustart nutzen den Guard bewusst nicht.
  Future<ProfileSwitchGuardResult> checkSwitchAllowed({
    required Future<bool> Function() confirm,
  }) async {
    if (_switchPending) return ProfileSwitchGuardResult.busy;
    _switchPending = true;
    try {
      final DashboardViewModel dashboard;
      try {
        dashboard = _ref.read(dashboardViewModelProvider.notifier);
        // `isTimerRunning` ist während des Ladens `false` (kein Dialog).
        if (!dashboard.isTimerRunning) return ProfileSwitchGuardResult.allowed;
      } catch (e, st) {
        // Dashboard nicht baubar (z. B. Repositories nicht verfügbar): dann
        // läuft dort auch kein Timer, der Wechsel darf nicht blockieren.
        logger.e(
            '[WorkProfile] Dashboard-Zustand nicht lesbar '
            '(${e.runtimeType})',
            stackTrace: st);
        return ProfileSwitchGuardResult.allowed;
      }

      final fromProfileId =
          _ref.read(core_providers.activeWorkProfileIdProvider) ??
              WorkProfileEntity.defaultProfileId;
      final bool confirmed;
      try {
        confirmed = await confirm();
      } catch (e, st) {
        logger.e(
            '[WorkProfile] Bestätigungsdialog fehlgeschlagen '
            '(${e.runtimeType})',
            stackTrace: st);
        return ProfileSwitchGuardResult.cancelled;
      }
      if (!confirmed) return ProfileSwitchGuardResult.cancelled;

      final stopped = await dashboard.stopRunningForSwitch(fromProfileId);
      return stopped
          ? ProfileSwitchGuardResult.allowed
          : ProfileSwitchGuardResult.saveFailed;
    } finally {
      _switchPending = false;
    }
  }

  Future<WorkProfileEntity> addProfile(String name) async {
    final repository = _ref.read(core_providers.workProfileRepositoryProvider);
    if (repository == null) throw const WorkProfilesNotAvailableException();

    final profile = await repository.addProfile(name);
    _ref.invalidate(core_providers.workProfilesProvider);
    _ref
        .read(core_providers.activeWorkProfileIdProvider.notifier)
        .setActiveProfile(profile.id);
    return profile;
  }

  Future<void> deleteProfile(String profileId) async {
    final repository = _ref.read(core_providers.workProfileRepositoryProvider);
    if (repository == null) throw const WorkProfilesNotAvailableException();

    // Ist das Profil gerade aktiv, zuerst auf Standard wechseln und erst dann
    // per API löschen (#388): sonst kann ein Autosave des Dashboards in das
    // gerade gelöschte Profil schreiben. Die Prüfung steht vor dem `await`.
    // Der Prefs-Write von `setActiveProfile` wird wie bei den übrigen
    // Aufrufern nicht abgewartet (`state` ist sofort gesetzt).
    final switchNotifier =
        _ref.read(core_providers.activeWorkProfileIdProvider.notifier);
    final wasActive =
        _ref.read(core_providers.activeWorkProfileIdProvider) == profileId;
    if (wasActive) switchNotifier.setActiveProfile(null);

    try {
      await repository.deleteProfile(profileId);
    } catch (_) {
      // Löschen fehlgeschlagen: das Profil existiert weiter, zurückwechseln.
      if (wasActive) switchNotifier.setActiveProfile(profileId);
      rethrow;
    }
    _ref.invalidate(core_providers.workProfilesProvider);
  }
}
