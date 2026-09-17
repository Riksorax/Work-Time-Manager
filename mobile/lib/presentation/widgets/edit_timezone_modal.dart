import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../view_models/settings_view_model.dart';

void showEditTimezoneModal(BuildContext context, String? currentTimezoneOverride) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => EditTimezoneModal(currentTimezoneOverride: currentTimezoneOverride),
  );
}

class EditTimezoneModal extends ConsumerStatefulWidget {
  final String? currentTimezoneOverride;

  const EditTimezoneModal({super.key, required this.currentTimezoneOverride});

  @override
  ConsumerState<EditTimezoneModal> createState() => _EditTimezoneModalState();
}

class _EditTimezoneModalState extends ConsumerState<EditTimezoneModal> {
  late final List<String> _allTimezones;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _allTimezones = tz.timeZoneDatabase.locations.keys.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = _query.isEmpty
        ? _allTimezones
        : _allTimezones.where((z) => z.toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.timezoneTitle, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: l10n.searchLabel,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        title: Text(l10n.systemDefaultTimezone),
                        subtitle: Text(l10n.systemDefaultTimezoneDescription),
                        trailing: widget.currentTimezoneOverride == null
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => _select(null),
                      );
                    }
                    final zone = filtered[index - 1];
                    return ListTile(
                      title: Text(zone),
                      trailing: widget.currentTimezoneOverride == zone
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => _select(zone),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _select(String? timezone) {
    ref.read(settingsViewModelProvider.notifier).updateTimezoneOverride(timezone);
    Navigator.of(context).pop();
  }
}
