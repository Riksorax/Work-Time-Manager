import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../view_models/weekly_reflection_view_model.dart';

/// Dialog für die Wochen-Reflexion (siehe #137): kurzer strukturierter
/// Rückblick auf eine Kalenderwoche, manuell aus dem Wochenbericht heraus
/// geöffnet.
class WeeklyReflectionDialog extends ConsumerStatefulWidget {
  final int year;
  final int week;

  const WeeklyReflectionDialog({
    super.key,
    required this.year,
    required this.week,
  });

  @override
  ConsumerState<WeeklyReflectionDialog> createState() =>
      _WeeklyReflectionDialogState();
}

class _WeeklyReflectionDialogState extends ConsumerState<WeeklyReflectionDialog> {
  final _whatWentWellController = TextEditingController();
  final _whatWasHardController = TextEditingController();
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(weeklyReflectionViewModelProvider.notifier)
          .loadReflection(widget.year, widget.week);
    });
  }

  @override
  void dispose() {
    _whatWentWellController.dispose();
    _whatWasHardController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(weeklyReflectionViewModelProvider.notifier).saveReflection(
            whatWentWell: _whatWentWellController.text,
            whatWasHard: _whatWasHardController.text,
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.reflectionSaved)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.saveFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(weeklyReflectionViewModelProvider);
    final l10n = AppLocalizations.of(context);

    if (!state.isLoading && !_controllersInitialized && state.reflection != null) {
      _whatWentWellController.text = state.reflection!.whatWentWell;
      _whatWasHardController.text = state.reflection!.whatWasHard;
      _controllersInitialized = true;
    }

    return AlertDialog(
      title: Text(l10n.weeklyReflectionDialogTitle(widget.week)),
      content: state.isLoading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _whatWentWellController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.whatWentWellLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _whatWasHardController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.whatWasHardLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: state.isLoading || state.isSaving ? null : _save,
          child: state.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}
