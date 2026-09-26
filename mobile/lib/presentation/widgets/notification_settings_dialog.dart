import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_service.dart';
import '../../domain/entities/settings_entity.dart';
import '../../domain/utils/weekday_labels.dart';
import '../../l10n/app_localizations.dart';
import '../view_models/settings_view_model.dart';

class NotificationSettingsDialog extends ConsumerStatefulWidget {
  final SettingsEntity settings;

  const NotificationSettingsDialog({
    required this.settings,
    super.key,
  });

  @override
  ConsumerState<NotificationSettingsDialog> createState() =>
      _NotificationSettingsDialogState();

  static Future<void> show(BuildContext context, SettingsEntity settings) {
    return showDialog(
      context: context,
      builder: (context) => NotificationSettingsDialog(settings: settings),
    );
  }
}

class _NotificationSettingsDialogState
    extends ConsumerState<NotificationSettingsDialog> {
  late bool _enabled;
  late TimeOfDay _time;
  late Set<int> _selectedDays;
  late bool _notifyWorkStart;
  late bool _notifyWorkEnd;
  late bool _notifyBreaks;
  late bool _warnOnOvertimeThreshold;
  late final TextEditingController _overtimeThresholdController;
  late bool _warnOnUndertimeThreshold;
  late final TextEditingController _undertimeThresholdController;

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.notificationsEnabled;
    _notifyWorkStart = widget.settings.notifyWorkStart;
    _notifyWorkEnd = widget.settings.notifyWorkEnd;
    _notifyBreaks = widget.settings.notifyBreaks;
    _warnOnOvertimeThreshold = widget.settings.warnOnOvertimeThreshold;
    _overtimeThresholdController =
        TextEditingController(text: widget.settings.overtimeThresholdHours.toString());
    _warnOnUndertimeThreshold = widget.settings.warnOnUndertimeThreshold;
    _undertimeThresholdController =
        TextEditingController(text: widget.settings.undertimeThresholdHours.toString());

    // Parse time
    final timeParts = widget.settings.notificationTime.split(':');
    _time = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    _selectedDays = Set.from(widget.settings.notificationDays);
  }

  @override
  void dispose() {
    _overtimeThresholdController.dispose();
    _undertimeThresholdController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );

    if (picked != null) {
      setState(() {
        _time = picked;
      });
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  Future<void> _save() async {
    final notificationService = NotificationService();

    // Request permissions if enabling
    if (_enabled) {
      final hasPermission = await notificationService.requestPermissions();
      if (!hasPermission && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).notificationPermissionDenied),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // Save settings
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    await viewModel.updateNotificationsEnabled(_enabled);

    final timeString = '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
    await viewModel.updateNotificationTime(timeString);

    final daysList = _selectedDays.toList()..sort();
    await viewModel.updateNotificationDays(daysList);

    await viewModel.updateNotifyWorkStart(_notifyWorkStart);
    await viewModel.updateNotifyWorkEnd(_notifyWorkEnd);
    await viewModel.updateNotifyBreaks(_notifyBreaks);

    await viewModel.updateWarnOnOvertimeThreshold(_warnOnOvertimeThreshold);
    final overtimeThreshold =
        double.tryParse(_overtimeThresholdController.text.replaceAll(',', '.')) ??
            widget.settings.overtimeThresholdHours;
    await viewModel.updateOvertimeThresholdHours(overtimeThreshold);

    await viewModel.updateWarnOnUndertimeThreshold(_warnOnUndertimeThreshold);
    final undertimeThreshold =
        double.tryParse(_undertimeThresholdController.text.replaceAll(',', '.')) ??
            widget.settings.undertimeThresholdHours;
    await viewModel.updateUndertimeThresholdHours(undertimeThreshold);

    // Schedule or cancel notifications
    if (_enabled && _selectedDays.isNotEmpty) {
      await notificationService.scheduleDailyReminder(
        time: timeString,
        days: daysList,
        checkWorkStart: _notifyWorkStart,
        checkWorkEnd: _notifyWorkEnd,
        checkBreaks: _notifyBreaks,
      );
    } else {
      await notificationService.cancelAllNotifications();
    }

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notificationSettingsSaved),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(l10n.notificationsTitle),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              automaticallyImplyLeading: false,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enable/Disable Switch
                    SwitchListTile(
                      title: Text(l10n.enableNotificationsTitle),
                      subtitle: Text(
                        l10n.enableNotificationsDescription,
                      ),
                      value: _enabled,
                      onChanged: (value) {
                        setState(() {
                          _enabled = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),

                    if (_enabled) ...[
                      // Time Selection
                      Text(
                        l10n.timeSectionTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _selectTime,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: colorScheme.primary),
                              const SizedBox(width: 16),
                              Text(
                                '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                                style: theme.textTheme.titleLarge,
                              ),
                              const Spacer(),
                              Icon(Icons.edit, color: colorScheme.primary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Notification Types
                      Text(
                        l10n.reminderForSectionTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: Text(l10n.notifyWorkStartTitle),
                        subtitle: Text(l10n.notifyWorkStartDescription),
                        value: _notifyWorkStart,
                        onChanged: (value) {
                          setState(() {
                            _notifyWorkStart = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: Text(l10n.notifyWorkEndTitle),
                        subtitle: Text(l10n.notifyWorkEndDescription),
                        value: _notifyWorkEnd,
                        onChanged: (value) {
                          setState(() {
                            _notifyWorkEnd = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: Text(l10n.breaksTitle),
                        subtitle: Text(l10n.notifyBreaksDescription),
                        value: _notifyBreaks,
                        onChanged: (value) {
                          setState(() {
                            _notifyBreaks = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 24),

                      // Day Selection
                      Text(
                        l10n.daysSectionTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                          final isSelected = _selectedDays.contains(day);
                          return FilterChip(
                            label: Text(weekdayShortLabel(day, locale)),
                            selected: isSelected,
                            onSelected: (selected) => _toggleDay(day),
                            showCheckmark: false,
                            selectedColor: colorScheme.primaryContainer,
                            checkmarkColor: colorScheme.primary,
                            side: BorderSide(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedDays.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l10n.selectAtLeastOneDay,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),

                    // Gleitzeit-Warnungen (siehe #219) - unabhängig von den
                    // täglichen Erinnerungen oben.
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      l10n.overtimeWarningsSectionTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    SwitchListTile(
                      title: Text(l10n.warnOnOvertimeTitle),
                      subtitle: Text(l10n.warnThresholdDescription),
                      value: _warnOnOvertimeThreshold,
                      onChanged: (value) {
                        setState(() {
                          _warnOnOvertimeThreshold = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_warnOnOvertimeThreshold)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 12),
                        child: TextField(
                          controller: _overtimeThresholdController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: l10n.thresholdHoursLabel,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    SwitchListTile(
                      title: Text(l10n.warnOnUndertimeTitle),
                      subtitle: Text(l10n.warnThresholdDescription),
                      value: _warnOnUndertimeThreshold,
                      onChanged: (value) {
                        setState(() {
                          _warnOnUndertimeThreshold = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_warnOnUndertimeThreshold)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 12),
                        child: TextField(
                          controller: _undertimeThresholdController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: l10n.thresholdHoursLabel,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (!_enabled || _selectedDays.isNotEmpty)
                            ? _save
                            : null,
                        child: Text(l10n.save),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
