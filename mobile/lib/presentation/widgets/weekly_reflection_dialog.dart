import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    try {
      await ref.read(weeklyReflectionViewModelProvider.notifier).saveReflection(
            whatWentWell: _whatWentWellController.text,
            whatWasHard: _whatWasHardController.text,
          );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Reflexion gespeichert.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(weeklyReflectionViewModelProvider);

    if (!state.isLoading && !_controllersInitialized && state.reflection != null) {
      _whatWentWellController.text = state.reflection!.whatWentWell;
      _whatWasHardController.text = state.reflection!.whatWasHard;
      _controllersInitialized = true;
    }

    return AlertDialog(
      title: Text('Wochen-Reflexion KW ${widget.week}'),
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
                    decoration: const InputDecoration(
                      labelText: 'Was lief gut?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _whatWasHardController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Was war anstrengend?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: state.isLoading || state.isSaving ? null : _save,
          child: state.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Speichern'),
        ),
      ],
    );
  }
}
