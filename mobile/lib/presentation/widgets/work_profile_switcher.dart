import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/subscription_provider.dart';
import '../../domain/entities/work_profile_entity.dart';
import '../../l10n/app_localizations.dart';
import 'add_work_profile_dialog.dart';
import '../view_models/work_profile_view_model.dart';
import 'common/paywall_launcher.dart';
import 'manage_work_profiles_dialog.dart';
import 'profile_switch_confirm_dialog.dart';

/// Profil-Wechsler im Header (siehe #138): zeigt alle Arbeitszeit-Profile
/// des Nutzers und erlaubt das Anlegen eines weiteren Profils, begrenzt auf
/// [maxWorkProfileCountProvider] (siehe #240). Für ausgeloggte Nutzer
/// unsichtbar, da Profile ein Login voraussetzen.
class WorkProfileSwitcher extends ConsumerWidget {
  const WorkProfileSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;
    if (user == null) return const SizedBox.shrink();

    final profilesAsync = ref.watch(workProfilesProvider);
    final activeProfileId = ref.watch(activeWorkProfileIdProvider) ??
        WorkProfileEntity.defaultProfileId;

    return profilesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (profiles) {
        final activeProfile = profiles.firstWhere(
          (p) => p.id == activeProfileId,
          orElse: WorkProfileEntity.defaultProfile,
        );
        final isPremium = ref.watch(isPremiumProvider);
        final maxProfiles = ref.watch(maxWorkProfileCountProvider);
        final canAddProfile = profiles.length < maxProfiles;
        final l10n = AppLocalizations.of(context);

        return PopupMenuButton<String>(
          tooltip: l10n.switchProfileTooltip,
          icon: const Icon(Icons.badge_outlined),
          onSelected: (value) {
            if (value == '__add__') {
              _handleAddProfile(context, ref,
                  isPremium: isPremium,
                  canAdd: canAddProfile,
                  maxProfiles: maxProfiles);
            } else if (value == '__manage__') {
              showDialog(
                  context: context,
                  builder: (_) => const ManageWorkProfilesDialog());
            } else {
              _handleSelectProfile(context, ref, value, profiles,
                  activeProfileId: activeProfile.id);
            }
          },
          itemBuilder: (context) => [
            for (final profile in profiles)
              CheckedPopupMenuItem<String>(
                value: profile.id,
                checked: profile.id == activeProfile.id,
                child: Text(profile.name),
              ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: '__add__',
              child: Row(
                children: [
                  Icon(canAddProfile ? Icons.add : Icons.lock_outline,
                      size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                      child: Text(l10n.newProfileAction,
                          overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            if (profiles.length > 1)
              PopupMenuItem<String>(
                value: '__manage__',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(l10n.manageProfilesAction,
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// Wechselt das Profil. Läuft im Dashboard ein Timer, fragt der Guard vor
  /// dem Wechsel (#388). Alles Nötige wird vor dem ersten `await` gelesen.
  Future<void> _handleSelectProfile(
    BuildContext context,
    WidgetRef ref,
    String profileId,
    List<WorkProfileEntity> profiles, {
    required String activeProfileId,
  }) async {
    if (profileId == activeProfileId) return;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final switchNotifier = ref.read(activeWorkProfileIdProvider.notifier);
    final guard = ref.read(workProfileViewModelProvider);
    String nameOf(String id) => profiles
        .firstWhere((p) => p.id == id,
            orElse: () => id == WorkProfileEntity.defaultProfileId
                ? WorkProfileEntity.defaultProfile()
                : WorkProfileEntity(id: id, name: id))
        .name;
    final fromName = nameOf(activeProfileId);
    final toName = nameOf(profileId);

    final result = await guard.checkSwitchAllowed(
      confirm: () => context.mounted
          ? showProfileSwitchConfirmDialog(context,
              fromName: fromName, toName: toName)
          : Future.value(false),
    );
    switch (result) {
      case ProfileSwitchGuardResult.allowed:
        switchNotifier.setActiveProfile(
            profileId == WorkProfileEntity.defaultProfileId ? null : profileId);
      case ProfileSwitchGuardResult.saveFailed:
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.dashboardSaveError)));
      case ProfileSwitchGuardResult.cancelled:
      case ProfileSwitchGuardResult.busy:
        break;
    }
  }

  void _handleAddProfile(
    BuildContext context,
    WidgetRef ref, {
    required bool isPremium,
    required bool canAdd,
    required int maxProfiles,
  }) {
    final l10n = AppLocalizations.of(context);
    if (!isPremium) {
      showPaywall(context);
      return;
    }
    if (!canAdd) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.maxProfilesReached(maxProfiles))),
      );
      return;
    }
    showDialog(context: context, builder: (_) => const AddWorkProfileDialog());
  }
}
