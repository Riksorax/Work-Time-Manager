import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/settings_view_model.dart';

void showEditWorkdaysModal(BuildContext context, int currentWorkdays) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => EditWorkdaysModal(currentWorkdays: currentWorkdays),
  );
}

class EditWorkdaysModal extends ConsumerStatefulWidget {
  final int currentWorkdays;

  const EditWorkdaysModal({super.key, required this.currentWorkdays});

  @override
  ConsumerState<EditWorkdaysModal> createState() => _EditWorkdaysModalState();
}

class _EditWorkdaysModalState extends ConsumerState<EditWorkdaysModal> {
  late int _selectedWorkdays;

  @override
  void initState() {
    super.initState();
    _selectedWorkdays = widget.currentWorkdays;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arbeitstage pro Woche',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            DropdownButton<int>(
              value: _selectedWorkdays,
              isExpanded: true,
              items: List.generate(7, (index) => index + 1)
                  .map((days) => DropdownMenuItem(
                        value: days,
                        child: Text('$days Tage'),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedWorkdays = value;
                  });
                }
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
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () {
                    ref
                        .read(settingsViewModelProvider.notifier)
                        .updateWorkdaysPerWeek(ref, _selectedWorkdays);
                    Navigator.of(context).pop();
                  },
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
