import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/work_profile_entity.dart';
import '../../l10n/app_localizations.dart';

/// Dialog zum Löschen zusätzlicher Arbeitszeit-Profile (siehe #238). Das
/// Standard-Profil wird hier nicht aufgeführt - es kann nicht gelöscht
/// werden.
class ManageWorkProfilesDialog extends ConsumerWidget {
  const ManageWorkProfilesDialog({super.key});

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    WorkProfileEntity profile,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.deleteProfileTitle),
        content: Text(l10n.deleteProfileConfirm(profile.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final repository = ref.read(workProfileRepositoryProvider);
    if (repository == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await repository.deleteProfile(profile.id);
      ref.invalidate(workProfilesProvider);
      // Falls das gelöschte Profil gerade aktiv war, zurück auf Standard.
      if (ref.read(activeWorkProfileIdProvider) == profile.id) {
        ref.read(activeWorkProfileIdProvider.notifier).setActiveProfile(null);
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileDeletedMessage(profile.name))));
    } catch (e, stackTrace) {
      logger.e('[ManageWorkProfilesDialog] Fehler beim Löschen: $e', stackTrace: stackTrace);
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileDeletionFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(workProfilesProvider);
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.manageProfilesDialogTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: profilesAsync.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(l10n.errorLoadingGeneric('$error')),
          data: (profiles) {
            final additionalProfiles =
                profiles.where((p) => !p.isDefault).toList();
            if (additionalProfiles.isEmpty) {
              return Text(l10n.noAdditionalProfiles);
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final profile in additionalProfiles)
                  ListTile(
                    title: Text(profile.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.deleteProfileTooltip,
                      onPressed: () => _confirmAndDelete(context, ref, profile),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.doneAction),
        ),
      ],
    );
  }
}
