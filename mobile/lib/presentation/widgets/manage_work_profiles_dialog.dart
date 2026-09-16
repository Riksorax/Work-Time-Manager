import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/work_profile_entity.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Profil löschen?'),
        content: Text(
          'Profil "${profile.name}" und alle zugehörigen Arbeitseinträge, '
          'Überstunden und Einstellungen werden unwiderruflich gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
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
      messenger.showSnackBar(SnackBar(content: Text('Profil "${profile.name}" gelöscht.')));
    } catch (e, stackTrace) {
      logger.e('[ManageWorkProfilesDialog] Fehler beim Löschen: $e', stackTrace: stackTrace);
      messenger.showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(workProfilesProvider);

    return AlertDialog(
      title: const Text('Profile verwalten'),
      content: SizedBox(
        width: double.maxFinite,
        child: profilesAsync.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('Fehler beim Laden: $error'),
          data: (profiles) {
            final additionalProfiles =
                profiles.where((p) => !p.isDefault).toList();
            if (additionalProfiles.isEmpty) {
              return const Text('Keine zusätzlichen Profile vorhanden.');
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final profile in additionalProfiles)
                  ListTile(
                    title: Text(profile.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Profil löschen',
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
          child: const Text('Fertig'),
        ),
      ],
    );
  }
}
