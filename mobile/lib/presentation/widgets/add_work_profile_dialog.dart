import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/utils/logger.dart';

/// Dialog zum Anlegen eines weiteren Arbeitszeit-Profils (siehe #138).
class AddWorkProfileDialog extends ConsumerStatefulWidget {
  const AddWorkProfileDialog({super.key});

  @override
  ConsumerState<AddWorkProfileDialog> createState() => _AddWorkProfileDialogState();
}

class _AddWorkProfileDialogState extends ConsumerState<AddWorkProfileDialog> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final repository = ref.read(workProfileRepositoryProvider);
    if (repository == null) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final newProfile = await repository.addProfile(name);
      ref.invalidate(workProfilesProvider);
      ref.read(activeWorkProfileIdProvider.notifier).setActiveProfile(newProfile.id);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Profil "${newProfile.name}" angelegt.')));
    } catch (e, stackTrace) {
      logger.e('[AddWorkProfileDialog] Fehler beim Anlegen des Profils: $e', stackTrace: stackTrace);
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(content: Text('Anlegen fehlgeschlagen: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neues Profil'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        maxLength: 40,
        decoration: const InputDecoration(
          labelText: 'Name (z.B. Arbeitgeber)',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Anlegen'),
        ),
      ],
    );
  }
}
