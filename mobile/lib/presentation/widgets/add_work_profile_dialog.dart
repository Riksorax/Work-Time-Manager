import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/work_profile_entity.dart';
import '../../l10n/app_localizations.dart';
import '../view_models/work_profile_view_model.dart';
import 'profile_switch_confirm_dialog.dart';

/// Dialog zum Anlegen eines weiteren Arbeitszeit-Profils (siehe #138).
class AddWorkProfileDialog extends ConsumerStatefulWidget {
  const AddWorkProfileDialog({super.key});

  @override
  ConsumerState<AddWorkProfileDialog> createState() =>
      _AddWorkProfileDialogState();
}

class _AddWorkProfileDialogState extends ConsumerState<AddWorkProfileDialog> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Name des aktuell aktiven Profils (Fallback: Standard-Profil).
  String _activeProfileName() {
    final activeId = ref.read(activeWorkProfileIdProvider) ??
        WorkProfileEntity.defaultProfileId;
    final profiles = ref.read(workProfilesProvider).asData?.value ?? const [];
    return profiles
        .firstWhere((p) => p.id == activeId,
            orElse: WorkProfileEntity.defaultProfile)
        .name;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    // Tastatur/Fokus vor dem Schließen des Dialogs beenden (siehe #337):
    // Schließt der Dialog, während das Framework noch eine IME-Selection-
    // Änderung für dieses Textfeld verarbeitet, wird dessen Overlay mitten in
    // der Verarbeitung disposed -> Null-Check-Crash in TextSelectionOverlay.
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);
    final viewModel = ref.read(workProfileViewModelProvider);
    final fromName = _activeProfileName();
    try {
      // Läuft im Dashboard ein Timer, erst bestätigen und speichern, dann
      // anlegen (#388). Bei Abbruch/Fehler bleibt der Dialog offen.
      final guardResult = await viewModel.checkSwitchAllowed(
        confirm: () => mounted
            ? showProfileSwitchConfirmDialog(context,
                fromName: fromName, toName: name)
            : Future.value(false),
      );
      if (guardResult != ProfileSwitchGuardResult.allowed) {
        if (mounted) setState(() => _isSaving = false);
        if (guardResult == ProfileSwitchGuardResult.saveFailed) {
          messenger
              .showSnackBar(SnackBar(content: Text(l10n.dashboardSaveError)));
        }
        return;
      }
      final newProfile = await viewModel.addProfile(name);
      navigator.pop();
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileCreatedMessage(newProfile.name))));
    } catch (e, stackTrace) {
      logger.e('[AddWorkProfileDialog] Fehler beim Anlegen des Profils: $e',
          stackTrace: stackTrace);
      setState(() => _isSaving = false);
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileCreationFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newProfileDialogTitle),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        maxLength: 40,
        decoration: InputDecoration(
          labelText: l10n.profileNameFieldLabel,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.createAction),
        ),
      ],
    );
  }
}
