import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/break_entity.dart';
import '../../../domain/entities/work_entry_entity.dart';
import '../state/edit_work_entry_state.dart';
import '../view_models/edit_work_entry_view_model.dart';

class EditWorkEntryModal extends ConsumerWidget {
  final WorkEntryEntity workEntry;

  const EditWorkEntryModal({super.key, required this.workEntry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = editWorkEntryViewModelProvider(workEntry);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Text(
                'Eintrag für den ${DateFormat.yMd('de_DE').format(workEntry.date)} bearbeiten',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    _buildTimeSection(context, state, viewModel),
                    const SizedBox(height: 24),
                    _buildBreaksSection(context, state, viewModel),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await viewModel.saveChanges();
                  if (context.mounted) Navigator.of(context).pop(true); // Return true on success
                },
                child: const Text('Änderungen speichern'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimePicker(
    BuildContext context, {
    required String labelText,
    required TimeOfDay? selectedTime,
    required ValueChanged<TimeOfDay> onTimeSelected,
    bool dense = false,
  }) {
    final format = MaterialLocalizations.of(context).formatTimeOfDay;
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.access_time),
        isDense: dense,
      ),
      controller: TextEditingController(text: selectedTime != null ? format(selectedTime) : ''),
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: selectedTime ?? TimeOfDay.now(),
        );
        if (time != null) {
          onTimeSelected(time);
        }
      },
    );
  }

  Widget _buildTimeSection(BuildContext context, EditWorkEntryState state, EditWorkEntryViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Arbeitszeit', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _buildTimePicker(
          context,
          labelText: 'Startzeit',
          selectedTime: state.newStartTime != null ? TimeOfDay.fromDateTime(state.newStartTime!) : null,
          onTimeSelected: (time) {
            final newDateTime = DateTime(
              state.originalEntry.date.year,
              state.originalEntry.date.month,
              state.originalEntry.date.day,
              time.hour,
              time.minute,
            );
            viewModel.setStartTime(newDateTime);
          },
        ),
        const SizedBox(height: 16),
        _buildTimePicker(
          context,
          labelText: 'Endzeit',
          selectedTime: state.newEndTime != null ? TimeOfDay.fromDateTime(state.newEndTime!) : null,
          onTimeSelected: (time) {
            final newDateTime = DateTime(
              state.originalEntry.date.year,
              state.originalEntry.date.month,
              state.originalEntry.date.day,
              time.hour,
              time.minute,
            );
            viewModel.setEndTime(newDateTime);
          },
        ),
      ],
    );
  }

  Widget _buildBreaksSection(BuildContext context, EditWorkEntryState state, EditWorkEntryViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pausen', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: viewModel.addBreak,
            ),
          ],
        ),
        if (state.breaks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: Text('Keine Pausen hinzugefügt')),
          )
        else
          ...state.breaks.map((breakEntry) {
            return _buildBreakTile(context, breakEntry, viewModel);
          }),
      ],
    );
  }

  Widget _buildBreakTile(BuildContext context, BreakEntity breakEntry, EditWorkEntryViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildTimePicker(
                    context,
                    labelText: 'Start',
                    dense: true,
                    selectedTime: TimeOfDay.fromDateTime(breakEntry.start),
                    onTimeSelected: (time) {
                      final newStart = DateTime(workEntry.date.year, workEntry.date.month, workEntry.date.day, time.hour, time.minute);
                      viewModel.updateBreak(breakEntry.id, newStart: newStart, newEnd: breakEntry.end);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildTimePicker(
                    context,
                    labelText: 'Ende',
                    dense: true,
                    selectedTime: breakEntry.end != null ? TimeOfDay.fromDateTime(breakEntry.end!) : null,
                    onTimeSelected: (time) {
                      final newEnd = DateTime(workEntry.date.year, workEntry.date.month, workEntry.date.day, time.hour, time.minute);
                      viewModel.updateBreak(breakEntry.id, newStart: breakEntry.start, newEnd: newEnd);
                    },
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => viewModel.deleteBreak(breakEntry.id),
            ),
          ],
        ),
      ),
    );
  }
}
