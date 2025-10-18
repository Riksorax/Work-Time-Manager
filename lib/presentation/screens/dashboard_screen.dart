import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/break_entity.dart';
import '../../domain/services/break_calculator_service.dart';
import '../view_models/dashboard_view_model.dart';
import '../widgets/edit_break_modal.dart';
import 'settings_page.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  String _formatOvertime(Duration overtime) {
    final isNegative = overtime.isNegative;
    final absoluteOvertime = isNegative ? -overtime : overtime;
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(absoluteOvertime.inHours);
    final minutes = twoDigits(absoluteOvertime.inMinutes.remainder(60));
    final sign = isNegative ? '-' : '+';
    return '$sign$hours:$minutes';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardViewModelProvider);
    final dashboardViewModel = ref.read(dashboardViewModelProvider.notifier);
    final workEntry = dashboardState.workEntry;

    // Berechne automatische Pausen, falls Start- und Endzeit vorhanden sind
    final workEntryWithAutoBreaks = workEntry.workStart != null && workEntry.workEnd != null
        ? BreakCalculatorService.calculateAndApplyBreaks(workEntry)
        : workEntry;

    // Den Timer-Status basierend auf den Daten von workEntry ableiten
    final isTimerRunning = workEntry.workStart != null && workEntry.workEnd == null;
    final isBreakRunning = workEntry.breaks.isNotEmpty && workEntry.breaks.last.end == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arbeitszeit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timer Display
            Text(
              _formatDuration(dashboardState.elapsedTime),
              style: Theme.of(context).textTheme.displayLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (dashboardState.actualWorkDuration != null)
              Text(
                'Gearbeitete Zeit: ${_formatDuration(dashboardState.actualWorkDuration!)}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),

            _buildOvertime(context, dashboardState.overtime, 'Überstunden Gesamt'),
            const SizedBox(height: 16),
            _buildOvertime(context, dashboardState.dailyOvertime, 'Heutige Überstunden'),
            const SizedBox(height: 24),

            // Time Input Fields
            _TimeInputField(
              label: 'Startzeit',
              // Korrekter Zugriff auf workStart über workEntry
              initialValue: workEntry.workStart,
              onTimeSelected: (time) => dashboardViewModel.setManualStartTime(time),
            ),
            const SizedBox(height: 16),
            _TimeInputField(
              label: 'Endzeit',
              initialValue: workEntry.workEnd,
              enabled: workEntry.workStart != null,
              onTimeSelected: (time) => dashboardViewModel.setManualEndTime(time),
            ),
            const SizedBox(height: 24),

            // Timer Button
            ElevatedButton(
              onPressed: () => dashboardViewModel.startOrStopTimer(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              // Korrekte Verwendung des abgeleiteten isTimerRunning-Flags
              child: Text(isTimerRunning
                  ? 'Zeiterfassung beenden'
                  : 'Zeiterfassung starten'),
            ),
            const SizedBox(height: 24),

            // Breaks Section
            // Zugriff auf breaks mit automatischen Pausen
            _buildBreaksSection(context, ref, workEntryWithAutoBreaks.breaks),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => dashboardViewModel.startOrStopBreak(),
              // Korrekte Verwendung des abgeleiteten isBreakRunning-Flags
              child: Text(isBreakRunning
                      ? 'Pause beenden'
                      : 'Pause hinzufügen'),
            ),
            const SizedBox(height: 24),
            _buildActualWorkDuration(context, dashboardState.actualWorkDuration),
          ],
        ),
      ),
    );
  }

  Widget _buildOvertime(BuildContext context, Duration? overtime, String title) {
    if (overtime == null) {
      return const SizedBox.shrink();
    }
    final formattedOvertime = _formatOvertime(overtime);
    final overtimeColor = overtime.isNegative ? Colors.red : Colors.green;

    return Column(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          formattedOvertime,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: overtimeColor),
        ),
      ],
    );
  }

  Widget _buildActualWorkDuration(BuildContext context, Duration? actualWorkDuration) {
    if (actualWorkDuration == null) {
      return const SizedBox.shrink();
    }
    final formattedDuration = _formatDuration(actualWorkDuration);
    return Column(
      children: [
        Text(
          'Gearbeitete Stunden',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          formattedDuration,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ],
    );
  }

  Widget _buildBreaksSection(
      BuildContext context, WidgetRef ref, List<BreakEntity> breaks) {
    final dashboardViewModel = ref.read(dashboardViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pausen', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (breaks.isEmpty)
          const Center(child: Text('Noch keine Pausen vorhanden.')),
        ...breaks.map((b) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (b.isAutomatic)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Tooltip(
                          message: 'Automatisch berechnet basierend auf der Arbeitszeit',
                          child: Chip(
                            label: const Text('Automatisch'),
                            backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                            labelStyle: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSecondary),
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                    '${DateFormat.Hm().format(b.start)} - ${b.end != null ? DateFormat.Hm().format(b.end!) : 'läuft...'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => EditBreakModal(breakEntity: b),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => dashboardViewModel.deleteBreak(b.id),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

class _TimeInputField extends StatefulWidget {
  final String label;
  final DateTime? initialValue;
  final ValueChanged<TimeOfDay>? onTimeSelected;
  final bool enabled;

  const _TimeInputField({
    required this.label,
    this.initialValue,
    this.onTimeSelected,
    this.enabled = true,
  });

  @override
  State<_TimeInputField> createState() => _TimeInputFieldState();
}

class _TimeInputFieldState extends State<_TimeInputField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _updateText();
  }

  @override
  void didUpdateWidget(covariant _TimeInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _updateText();
    }
  }

  void _updateText() {
    if (widget.initialValue != null) {
      _controller.text = DateFormat.Hm().format(widget.initialValue!);
    } else {
      _controller.text = '';
    }
  }

  Future<void> _selectTime() async {
    if (!widget.enabled || widget.onTimeSelected == null) return;

    final initialTime = widget.initialValue != null
        ? TimeOfDay.fromDateTime(widget.initialValue!)
        : TimeOfDay.now();

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime != null) {
      widget.onTimeSelected!(pickedTime);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      readOnly: true,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        suffixIcon: widget.enabled ? const Icon(Icons.access_time) : null,
      ),
      onTap: _selectTime,
    );
  }
}
