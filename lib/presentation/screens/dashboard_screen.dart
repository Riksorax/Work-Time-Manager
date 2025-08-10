import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/break_entity.dart';
import '../view_models/dashboard_view_model.dart';
import '../widgets/add_adjustment_modal.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardViewModelProvider);
    final dashboardViewModel = ref.read(dashboardViewModelProvider.notifier);
    final workEntry = dashboardState.workEntry;

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
            // Korrekter Zugriff auf breaks über workEntry
            _buildBreaksSection(context, ref, workEntry.breaks),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => dashboardViewModel.startOrStopBreak(),
              // Korrekte Verwendung des abgeleiteten isBreakRunning-Flags
              child: Text(isBreakRunning
                      ? 'Pause beenden'
                      : 'Pause hinzufügen'),
            ),
            const SizedBox(height: 16),

            // Overtime Balance Display
            _buildOvertimeBalance(context, dashboardState.overtimeBalance),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const AddAdjustmentModal(),
                );
              },
              child: const Text('Überstunden / Minusstunden hinzufügen'),
            ),
            const SizedBox(height: 24),
            _buildActualWorkDuration(context, dashboardState.actualWorkDuration),
          ],
        ),
      ),
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

  Widget _buildOvertimeBalance(BuildContext context, Duration overtimeBalance) {
    final bool isNegative = overtimeBalance.isNegative;
    final Duration absDuration = overtimeBalance.abs();

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(absDuration.inHours);
    final minutes = twoDigits(absDuration.inMinutes.remainder(60));
    final sign = isNegative ? '-' : '+';
    final formattedOvertime = '$sign$hours:$minutes';

    return Column(
      children: [
        Text(
          'Stunden-Bilanz',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          formattedOvertime,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: isNegative ? Colors.red : Colors.green,
              ),
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
                title: Text(b.name),
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
