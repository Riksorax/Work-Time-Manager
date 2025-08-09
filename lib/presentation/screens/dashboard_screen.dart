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
              initialValue: dashboardState.manualStartTime,
              onTimeSelected: (time) => dashboardViewModel.setManualStartTime(time),
            ),
            const SizedBox(height: 16),
            _TimeInputField(
              label: 'Endzeit',
              initialValue: dashboardState.manualEndTime,
              enabled: false,
            ),
            const SizedBox(height: 24),

            // Timer Button
            ElevatedButton(
              onPressed: () => dashboardViewModel.startOrStopTimer(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(dashboardState.isTimerRunning
                  ? 'Zeiterfassung beenden'
                  : 'Zeiterfassung starten'),
            ),
            const SizedBox(height: 24),

            // Breaks Section
            _buildBreaksSection(context, ref, dashboardState.breaks),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => dashboardViewModel.startOrStopBreak(),
              child: Text(
                  dashboardState.breaks.any((b) => b.end == null)
                      ? 'Pause beenden'
                      : 'Pause hinzufügen'),
            ),
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
          ],
        ),
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
