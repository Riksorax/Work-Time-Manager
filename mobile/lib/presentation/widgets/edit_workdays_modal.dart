import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/utils/weekday_labels.dart';
import '../../l10n/app_localizations.dart';
import '../view_models/settings_view_model.dart';

void showEditWorkdaysModal(BuildContext context, List<int> currentWorkdays) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => EditWorkdaysModal(currentWorkdays: currentWorkdays),
  );
}

class EditWorkdaysModal extends ConsumerStatefulWidget {
  final List<int> currentWorkdays;

  const EditWorkdaysModal({super.key, required this.currentWorkdays});

  @override
  ConsumerState<EditWorkdaysModal> createState() => _EditWorkdaysModalState();
}

class _EditWorkdaysModalState extends ConsumerState<EditWorkdaysModal> {
  late Set<int> _selectedWorkdays;

  @override
  void initState() {
    super.initState();
    _selectedWorkdays = widget.currentWorkdays.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.workdaysTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.workdaysDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                final isoWeekday = index + 1;
                final isSelected = _selectedWorkdays.contains(isoWeekday);
                return FilterChip(
                  label: Text(weekdayShortLabel(isoWeekday, locale)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedWorkdays.add(isoWeekday);
                      } else {
                        _selectedWorkdays.remove(isoWeekday);
                      }
                    });
                  },
                );
              }),
            ),
            if (_selectedWorkdays.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.selectAtLeastOneWorkday,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: _selectedWorkdays.isEmpty
                      ? null
                      : () {
                          final sorted = _selectedWorkdays.toList()..sort();
                          ref
                              .read(settingsViewModelProvider.notifier)
                              .updateWorkdays(ref, sorted);
                          Navigator.of(context).pop();
                        },
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
