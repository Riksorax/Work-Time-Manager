import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/subscription_provider.dart';
import '../../domain/entities/work_profile_entity.dart';
import 'add_work_profile_dialog.dart';
import 'manage_work_profiles_dialog.dart';

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
    final activeProfileId = ref.watch(activeWorkProfileIdProvider) ?? WorkProfileEntity.defaultProfileId;

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

        return PopupMenuButton<String>(
          tooltip: 'Profil wechseln',
          icon: const Icon(Icons.badge_outlined),
          onSelected: (value) {
            if (value == '__add__') {
              _handleAddProfile(context, ref,
                  isPremium: isPremium, canAdd: canAddProfile, maxProfiles: maxProfiles);
            } else if (value == '__manage__') {
              showDialog(context: context, builder: (_) => const ManageWorkProfilesDialog());
            } else {
              ref.read(activeWorkProfileIdProvider.notifier).setActiveProfile(
                  value == WorkProfileEntity.defaultProfileId ? null : value);
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
                  Icon(canAddProfile ? Icons.add : Icons.lock_outline, size: 20),
                  const SizedBox(width: 8),
                  const Flexible(child: Text('Neues Profil', overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            if (profiles.length > 1)
              const PopupMenuItem<String>(
                value: '__manage__',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: 8),
                    Flexible(child: Text('Profile verwalten', overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  void _handleAddProfile(
    BuildContext context,
    WidgetRef ref, {
    required bool isPremium,
    required bool canAdd,
    required int maxProfiles,
  }) {
    if (!isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zusätzliche Profile sind ein Premium-Feature.')),
      );
      return;
    }
    if (!canAdd) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximal $maxProfiles Profile möglich.')),
      );
      return;
    }
    showDialog(context: context, builder: (_) => const AddWorkProfileDialog());
  }
}
