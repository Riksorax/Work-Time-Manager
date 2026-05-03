import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddManualTimeDialog extends ConsumerStatefulWidget {
  const AddManualTimeDialog({super.key});

  @override
  ConsumerState<AddManualTimeDialog> createState() => _AddManualTimeDialogState();
}

class _AddManualTimeDialogState extends ConsumerState<AddManualTimeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isPositive = true;

  @override
  void dispose() {
    _durationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      // TODO: Call the view model to save the manual entry
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manuelle Zeitkorrektur'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                DropdownButton<bool>(
                  value: _isPositive,
                  items: const [
                    DropdownMenuItem(value: true, child: Text('+')),
                    DropdownMenuItem(value: false, child: Text('-')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _isPositive = value;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Dauer (HH:mm)',
                      hintText: '00:30',
                    ),
                    keyboardType: TextInputType.datetime,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bitte geben Sie eine Dauer an.';
                      }
                      // Basic format check
                      if (!RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value)) {
                        return 'Ungültiges Format (HH:mm).';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Grund',
                hintText: 'z.B. Arztbesuch',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Bitte geben Sie einen Grund an.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
