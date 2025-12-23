import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/break_entity.dart';
import '../../domain/services/break_calculator_service.dart';
import '../view_models/dashboard_view_model.dart';
import '../widgets/common/responsive_center.dart';
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

    final workEntryWithAutoBreaks = workEntry.workStart != null && workEntry.workEnd != null
        ? BreakCalculatorService.calculateAndApplyBreaks(workEntry)
        : workEntry;

    final isTimerRunning = workEntry.workStart != null && workEntry.workEnd == null;
    final isBreakRunning = workEntry.breaks.isNotEmpty && workEntry.breaks.last.end == null;

    final totalOvertime = dashboardState.totalOvertime ?? Duration.zero;
    final netDuration = dashboardState.actualWorkDuration ?? dashboardState.elapsedTime;
    
    final totalBreakDuration = workEntryWithAutoBreaks.breaks.fold(Duration.zero, (prev, b) {
      final end = b.end ?? DateTime.now();
      return prev + end.difference(b.start);
    });

    final grossDuration = dashboardState.grossWorkDuration ?? (netDuration + totalBreakDuration);

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
      body: ResponsiveCenter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _formatDuration(netDuration),
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Anwesenheit (Brutto): ${_formatDuration(grossDuration)}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              _buildOvertime(context, totalOvertime, 'Überstunden Gesamt'),
              const SizedBox(height: 16),
              _buildOvertime(context, dashboardState.dailyOvertime, 'Heutige Überstunden'),
              _buildExpectedEndTime(context, dashboardState.expectedEndTime),
              _buildExpectedEndTimeWithBalance(context, dashboardState.expectedEndTotalZero),
              const SizedBox(height: 24),

              _TimeInputField(
                label: 'Startzeit',
                initialValue: workEntry.workStart,
                onTimeSelected: (time) => dashboardViewModel.setManualStartTime(time),
              ),
              const SizedBox(height: 16),
              _TimeInputField(
                label: 'Endzeit',
                initialValue: workEntry.workEnd,
                enabled: workEntry.workStart != null,
                onTimeSelected: (time) => dashboardViewModel.setManualEndTime(time),
                onClear: workEntry.workEnd != null ? () => dashboardViewModel.clearEndTime() : null,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () => dashboardViewModel.startOrStopTimer(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isTimerRunning
                    ? 'Zeiterfassung beenden'
                    : 'Zeiterfassung starten'),
              ),
              const SizedBox(height: 24),

              _buildBreaksSection(context, ref, workEntryWithAutoBreaks.breaks),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => dashboardViewModel.startOrStopBreak(),
                child: Text(isBreakRunning
                        ? 'Pause beenden'
                        : 'Pause hinzufügen'),
              ),
              const SizedBox(height: 24),
            ],
          ),
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

  Widget _buildExpectedEndTime(BuildContext context, DateTime? expectedEndTime) {
    if (expectedEndTime == null) {
      return const SizedBox.shrink();
    }

    final formattedTime = DateFormat.Hm().format(expectedEndTime);

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        'Voraussichtlicher Feierabend (±0): $formattedTime Uhr',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildExpectedEndTimeWithBalance(BuildContext context, DateTime? expectedEndTimeWithBalance) {
    if (expectedEndTimeWithBalance == null) {
      return const SizedBox.shrink();
    }

    final formattedTimeWithBalance = DateFormat.Hm().format(expectedEndTimeWithBalance);

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Text(
        'Mit Gleitzeit-Bilanz auf 0: $formattedTimeWithBalance Uhr',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[500],
          fontStyle: FontStyle.italic,
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
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
                            backgroundColor: Theme.of(context).colorScheme.secondary.withAlpha(77),
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
  final VoidCallback? onClear;
  final bool enabled;

  const _TimeInputField({
    required this.label,
    this.initialValue,
    this.onTimeSelected,
    this.onClear,
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
        suffixIcon: widget.initialValue != null && widget.onClear != null
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: widget.onClear,
                tooltip: '${widget.label} entfernen',
              )
            : (widget.enabled ? const Icon(Icons.access_time) : null),
      ),
      onTap: _selectTime,
    );
  }
}