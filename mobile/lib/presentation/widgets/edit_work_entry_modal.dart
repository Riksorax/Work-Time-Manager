import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/break_entity.dart';
import '../../../domain/entities/work_entry_entity.dart';
import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

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
                l10n.editEntryForDate(DateFormat.yMd(locale).format(workEntry.date)),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<WorkEntryType>(
                value: state.type,
                decoration: InputDecoration(
                  labelText: l10n.typeLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: WorkEntryType.work, child: Text(l10n.workEntryTypeWorkPlain)),
                  DropdownMenuItem(value: WorkEntryType.vacation, child: Text(l10n.workEntryTypeVacationPlain)),
                  DropdownMenuItem(value: WorkEntryType.sick, child: Text(l10n.workEntryTypeSickPlain)),
                  DropdownMenuItem(value: WorkEntryType.holiday, child: Text(l10n.workEntryTypeHolidayPlain)),
                ],
                onChanged: (val) {
                  if (val != null) viewModel.setType(val);
                },
              ),
              const SizedBox(height: 24),
              if (state.type == WorkEntryType.work) ...[
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
              ] else
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.allDayEventNotice,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await viewModel.saveChanges();
                  if (context.mounted) Navigator.of(context).pop(true); // Return true on success
                },
                child: Text(l10n.saveChangesAction),
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
    final localizations = MaterialLocalizations.of(context);
    // Folgt der App-weiten Einstellung (siehe #218) statt hart auf 24h zu
    // stehen - MediaQuery.alwaysUse24HourFormat wird in main.dart gesetzt.
    final alwaysUse24HourFormat = MediaQuery.of(context).alwaysUse24HourFormat;
    final formatted = selectedTime != null
        ? localizations.formatTimeOfDay(selectedTime, alwaysUse24HourFormat: alwaysUse24HourFormat)
        : '';
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.access_time),
        isDense: dense,
      ),
      controller: TextEditingController(text: formatted),
      onTap: () async {
        // Kein builder-Override mehr: der TimePicker übernimmt automatisch
        // die App-weite Einstellung aus MediaQuery.alwaysUse24HourFormat
        // (siehe #218, main.dart).
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.workTimeSectionTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _buildTimePicker(
          context,
          labelText: l10n.startTimeLabel,
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
          labelText: l10n.endTimeLabel,
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.breaksTitle, style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: viewModel.addBreak,
            ),
          ],
        ),
        if (state.breaks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: Text(l10n.noBreaksAdded)),
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
                    labelText: AppLocalizations.of(context).startFieldLabel,
                    dense: true,
                    selectedTime: TimeOfDay.fromDateTime(breakEntry.start),
                    onTimeSelected: (time) {
                      final newStart = DateTime(workEntry.date.year, workEntry.date.month, workEntry.date.day, time.hour, time.minute);
                      // Berechne die bisherige Dauer, um die Endzeit mitzuverschieben
                      DateTime? newEnd = breakEntry.end;
                      if (breakEntry.end != null) {
                        final duration = breakEntry.end!.difference(breakEntry.start);
                        newEnd = newStart.add(duration);
                      }
                      viewModel.updateBreak(breakEntry.id, newStart: newStart, newEnd: newEnd);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildTimePicker(
                    context,
                    labelText: AppLocalizations.of(context).endFieldLabel,
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
              icon: Icon(Icons.delete, color: Colors.red.shade700),
              onPressed: () => viewModel.deleteBreak(breakEntry.id),
            ),
          ],
        ),
      ),
    );
  }
}
