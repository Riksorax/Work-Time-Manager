import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/dashboard_view_model.dart';

class AddAdjustmentModal extends ConsumerStatefulWidget {
  const AddAdjustmentModal({super.key});

  @override
  ConsumerState<AddAdjustmentModal> createState() =>
      _AddAdjustmentModalState();
}

class _AddAdjustmentModalState extends ConsumerState<AddAdjustmentModal> {
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _save() {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;

    if (minutes < 0 || minutes > 59) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Minuten müssen zwischen 0 und 59 liegen.')),
      );
      return;
    }

    // Rufen die neue Methode im ViewModel auf
    final duration = Duration(hours: hours, minutes: minutes);
    ref.read(dashboardViewModelProvider.notifier).addAdjustment(duration);

    // Modal schließen
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Überstunden / Minusstunden'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Manuelle Eingabe für den heutigen Tag.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hoursController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Stunden (z.B. -1 oder 2)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minuten (0-59)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
