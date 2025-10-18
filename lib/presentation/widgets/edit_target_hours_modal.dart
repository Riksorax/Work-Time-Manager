import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/settings_view_model.dart';

void showEditTargetHoursModal(BuildContext context, double currentHours) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: EditTargetHoursModal(currentHours: currentHours),
    ),
  );
}

class EditTargetHoursModal extends ConsumerStatefulWidget {
  final double currentHours;

  const EditTargetHoursModal({super.key, required this.currentHours});

  @override
  ConsumerState<EditTargetHoursModal> createState() =>
      _EditTargetHoursModalState();
}

class _EditTargetHoursModalState extends ConsumerState<EditTargetHoursModal> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentHours.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final hours = double.tryParse(_controller.text.replaceAll(',', '.'));
      if (hours != null) {
        await ref
            .read(settingsViewModelProvider.notifier)
            .updateWeeklyTargetHours(hours);

        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Soll-Arbeitsstunden bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Wöchentliche Soll-Stunden',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Bitte geben Sie eine Zahl ein.';
                }
                final number = double.tryParse(value.replaceAll(',', '.'));
                if (number == null) {
                  return 'Ungültige Zahl.';
                }
                if (number <= 0 || number > 100) {
                  return 'Bitte geben Sie einen Wert zwischen 1 und 100 ein.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Speichern'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
