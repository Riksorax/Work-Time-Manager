import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart' show workProfilesProvider;
import '../../core/utils/network_error.dart';
import '../../domain/entities/work_profile_entity.dart';
import '../../l10n/app_localizations.dart';
import '../utils/user_error_message.dart';
import '../view_models/work_profile_view_model.dart';
import 'common/load_failure_notice.dart';

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

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(workProfileViewModelProvider).deleteProfile(profile.id);
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileDeletedMessage(profile.name))));
    } catch (e, stackTrace) {
      // Ohne Ausnahmetext ins Log und in die Meldung (#582).
      logUserFacingError(
          '[ManageWorkProfilesDialog] Profil nicht gelöscht', e, stackTrace);
      messenger.showSnackBar(SnackBar(
          content: Text(
              userErrorMessage(l10n, e, general: l10n.profileDeletionFailed))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(workProfilesProvider);
    final l10n = AppLocalizations.of(context);
    // Ladefehler der Profil-Liste ins Log, ohne Ausnahmetext (#582).
    ref.listen(workProfilesProvider, (previous, next) {
      if (next is AsyncError && previous is! AsyncError) {
        logUserFacingError('[ManageWorkProfilesDialog] Profile nicht geladen',
            next.error!, next.stackTrace);
      }
    });

    return AlertDialog(
      title: Text(l10n.manageProfilesDialogTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: profilesAsync.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          // Verständlicher Hinweis mit „Erneut versuchen“ statt des
          // Ausnahmetexts (#582); geloggt wird beim Laden der Profile.
          error: (error, _) => LoadFailureNotice(
            message: l10n.profilesLoadFailed,
            offline: isTransientNetworkError(error),
            onRetry: () => ref.invalidate(workProfilesProvider),
          ),
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
