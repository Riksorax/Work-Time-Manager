import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_service.dart';
import '../../domain/entities/settings_entity.dart';
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

  final Map<int, String> _dayNames = {
    1: 'Mo',
    2: 'Di',
    3: 'Mi',
    4: 'Do',
    5: 'Fr',
    6: 'Sa',
    7: 'So',
  };

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.notificationsEnabled;
    _notifyWorkStart = widget.settings.notifyWorkStart;
    _notifyWorkEnd = widget.settings.notifyWorkEnd;
    _notifyBreaks = widget.settings.notifyBreaks;

    // Parse time
    final timeParts = widget.settings.notificationTime.split(':');
    _time = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    _selectedDays = Set.from(widget.settings.notificationDays);
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
          const SnackBar(
            content: Text('Benachrichtigungsberechtigungen wurden nicht erteilt'),
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
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Benachrichtigungseinstellungen gespeichert'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Benachrichtigungen'),
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
                      title: const Text('Benachrichtigungen aktivieren'),
                      subtitle: const Text(
                        'Erinnert Sie daran, fehlende Arbeitszeiten einzutragen',
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
                        'Uhrzeit',
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
                        'Erinnerungen für',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: const Text('Arbeitsbeginn'),
                        subtitle: const Text('Erinnert an fehlenden Arbeitsbeginn'),
                        value: _notifyWorkStart,
                        onChanged: (value) {
                          setState(() {
                            _notifyWorkStart = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Arbeitsende'),
                        subtitle: const Text('Erinnert an fehlendes Arbeitsende'),
                        value: _notifyWorkEnd,
                        onChanged: (value) {
                          setState(() {
                            _notifyWorkEnd = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Pausen'),
                        subtitle: const Text('Erinnert an fehlende Pausen'),
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
                        'Tage',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                          final isSelected = _selectedDays.contains(day);
                          return FilterChip(
                            label: Text(_dayNames[day]!),
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
                            'Bitte wählen Sie mindestens einen Tag aus',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (!_enabled || _selectedDays.isNotEmpty)
                            ? _save
                            : null,
                        child: const Text('Speichern'),
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
