import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../view_models/settings_view_model.dart';

class EditSollArbeitsstundenDialog extends ConsumerStatefulWidget {
  const EditSollArbeitsstundenDialog({super.key});

  @override
  ConsumerState<EditSollArbeitsstundenDialog> createState() =>
      _EditSollArbeitsstundenDialogState();
}

class _EditSollArbeitsstundenDialogState
    extends ConsumerState<EditSollArbeitsstundenDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Safely read the initial value from the async state
    final settingsState = ref.read(settingsViewModelProvider);
    final initialValue = settingsState.asData?.value.weeklyTargetHours.toString() ?? '';
    _controller = TextEditingController(text: initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = int.tryParse(_controller.text);
    if (value != null && value > 0 && value <= 168) {
      // Call the correct method on the notifier
      ref.read(settingsViewModelProvider.notifier).setTargetWeeklyHours(value);
      Navigator.of(context).pop();
    } else {
      // Show an error message if the input is invalid
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte geben Sie eine gültige Zahl zwischen 1 und 168 ein.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider to rebuild if the value changes from outside
    ref.watch(settingsViewModelProvider);
    
    return AlertDialog(
      title: const Text('Soll-Arbeitsstunden festlegen'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Stunden pro Woche',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
