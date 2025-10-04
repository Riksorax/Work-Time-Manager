import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/work_entry_extensions.dart';
import '../view_models/reports_view_model.dart';
import '../view_models/settings_view_model.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/edit_work_entry_modal.dart';
import '../../domain/entities/work_entry_entity.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Initiale Daten laden
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      ref
          .read(reportsViewModelProvider.notifier)
          .onMonthChanged(DateTime(now.year, now.month, 1));
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEditWorkEntryModal(WorkEntryEntity entry, BuildContext context) {
    final entryWithCalculatedBreaks = ref
        .read(reportsViewModelProvider.notifier)
        .applyBreakCalculation(entry);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          EditWorkEntryModal(workEntry: entryWithCalculatedBreaks),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Berichte'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Täglich'),
            Tab(text: 'Wöchentlich'),
            Tab(text: 'Monatlich'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DailyReportView(onEntryTap: (entry) => _showEditWorkEntryModal(entry, context)),
          const WeeklyReportView(),
          const MonthlyReportView(),
        ],
      ),
    );
  }
}

class DailyReportView extends ConsumerWidget {
  final Function(WorkEntryEntity) onEntryTap;
  const DailyReportView({required this.onEntryTap, super.key});

  String _formatDuration(Duration duration) {
    final bool isNegative = duration.isNegative;
    final Duration absDuration = duration.abs();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(absDuration.inHours);
    final minutes = twoDigits(absDuration.inMinutes.remainder(60));
    final sign = isNegative ? '-' : '+';
    return '$sign$hours:$minutes';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, WorkEntryEntity entry) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Eintrag löschen?'),
          content: const Text('Möchten Sie diesen Arbeitseintrag wirklich löschen?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Löschen'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(reportsViewModelProvider.notifier).deleteWorkEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsState = ref.watch(reportsViewModelProvider);
    final reportsNotifier = ref.read(reportsViewModelProvider.notifier);

    final settingsState = ref.watch(settingsViewModelProvider);
    Duration? dailyTarget;
    settingsState.when(
      data: (s) {
        dailyTarget = Duration(
          minutes: ((s.weeklyTargetHours / 5.0) * 60).round(),
        );
      },
      loading: () {},
      error: (_, __) {},
    );

    if (reportsState.isLoading) {
      return const LoadingIndicator();
    }

    final dailyReport = reportsState.dailyReportState; // Entries for the selected day
    final selectedDay = reportsState.selectedDay ?? DateTime.now();
    final selectedMonth = reportsState.selectedMonth ?? DateTime.now();

    // Ermitteln der Tage mit Einträgen für den aktuellen Kalendermonat
    final Set<int> daysWithEntriesInMonth = reportsState.monthlyReportState.dailyWork.keys
        .where((date) =>
            date.year == selectedMonth.year && // Korrektur: Filtere nach dem angezeigten Monat
            date.month == selectedMonth.month) 
        .map((date) => date.day)
        .toSet();

    Duration totalWorked = Duration.zero;
    Duration totalManualAdjustment = Duration.zero;
    // Calculate total worked for the *selected day* (for the summary below the calendar)
    // This uses dailyReport.entries which should be specific to the selectedDay
    for (final e in dailyReport.entries) { 
      final dE =
          ref.read(reportsViewModelProvider.notifier).applyBreakCalculation(e);
      final DateTime? start = dE.workStart;
      final DateTime? end = dE.workEnd ?? DateTime.now();
      if (start != null && end != null) {
        Duration breakDur = Duration.zero;
        for (final b in dE.breaks) {
          final DateTime bStart = b.start;
          final DateTime bEnd = b.end ?? end;
          final DateTime effStart = bStart.isBefore(start) ? start : bStart;
          final DateTime effEnd = bEnd.isAfter(end) ? end : bEnd;
          if (effEnd.isAfter(effStart)) {
            breakDur += effEnd.difference(effStart);
          }
        }
        totalWorked += end.difference(start) - breakDur;
      }
      if (dE.manualOvertime != null) {
        totalManualAdjustment += dE.manualOvertime!;
      }
    }
    Duration? dayOvertime;
    if (dailyTarget != null) {
      dayOvertime = totalWorked - dailyTarget! + totalManualAdjustment;
    }

    return ListView(
      children: [
        _Calendar(
          selectedDate: selectedDay,
          onDateSelected: (date) => reportsNotifier.selectDate(date),
          onPreviousMonthTapped: () {
            final currentMonth = reportsState.selectedMonth ?? DateTime.now();
            reportsNotifier.onMonthChanged(
                DateTime(currentMonth.year, currentMonth.month - 1, 1));
          },
          onNextMonthTapped: () {
            final currentMonth = reportsState.selectedMonth ?? DateTime.now();
            reportsNotifier.onMonthChanged(
                DateTime(currentMonth.year, currentMonth.month + 1, 1));
          },
          daysWithEntries: daysWithEntriesInMonth, // Pass the correctly calculated set
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tagesbericht für ${DateFormat.yMMMMd('de_DE').format(selectedDay)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (dailyReport.entries.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Keine Daten für diesen Tag.'),
                      Builder(builder: (context) {
                        final today = DateUtils.dateOnly(DateTime.now());
                        final selectedDateOnly = DateUtils.dateOnly(selectedDay);

                        if (selectedDateOnly.isBefore(today)) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton(
                              onPressed: () {
                                final newEntry = WorkEntryEntity(
                                  id: DateFormat('yyyy-MM-dd').format(selectedDay),
                                  date: selectedDay,
                                  workStart: null,
                                  workEnd: null,
                                  breaks: [],
                                  isManuallyEntered: true,
                                  description: null,
                                  manualOvertime: null,
                                );
                                onEntryTap(newEntry);
                              },
                              child: const Text('Eintrag hinzufügen'),
                            ),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }),
                    ],
                  ),
                )
              else ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Soll (Tag):',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              dailyTarget != null
                                  ? '${dailyTarget!.inHours.toString().padLeft(2, '0')}:${dailyTarget!.inMinutes.remainder(60).toString().padLeft(2, '0')}'
                                  : '—',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Ist (Tag):'),
                            Text(
                              '${totalWorked.inHours.toString().padLeft(2, '0')}:${totalWorked.inMinutes.remainder(60).toString().padLeft(2, '0')}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Saldo (Tag):',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              dayOvertime != null
                                  ? _formatDuration(dayOvertime!)
                                  : '—',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: dayOvertime == null
                                    ? Colors.grey
                                    : (dayOvertime!.isNegative
                                        ? Colors.red
                                        : Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                ...dailyReport.entries.map((entry) {
                  final displayEntry = ref
                      .read(reportsViewModelProvider.notifier)
                      .applyBreakCalculation(entry);
                  final DateTime? _start = displayEntry.workStart;
                  final DateTime? _end = displayEntry.workEnd ?? DateTime.now();
                  Duration _breakDuration = Duration.zero;
                  if (_start != null && _end != null) {
                    for (final b in displayEntry.breaks) {
                      final DateTime bStart = b.start;
                      final DateTime bEnd = b.end ?? _end;
                      final DateTime effStart =
                          bStart.isBefore(_start) ? _start : bStart;
                      final DateTime effEnd = bEnd.isAfter(_end) ? _end : bEnd;
                      if (effEnd.isAfter(effStart)) {
                        _breakDuration += effEnd.difference(effStart);
                      }
                    }
                  }
                  final Duration workedDuration =
                      (_start != null && _end != null)
                          ? _end.difference(_start) - _breakDuration
                          : Duration.zero;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Arbeitszeit: ${workedDuration.toString().split('.').first}',
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => onEntryTap(entry),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _confirmDelete(context, ref, entry),
                                  ),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                              'Start: ${displayEntry.workStart != null ? DateFormat('HH:mm').format(displayEntry.workStart!) : '-'}'
                          ),
                          Text(
                              'Ende: ${displayEntry.workEnd != null ? DateFormat('HH:mm').format(displayEntry.workEnd!) : 'läuft...'}'
                          ),
                          Text(
                              'Pause: ${displayEntry.totalBreakDuration.toString().split('.').first}'
                          ),
                          if (displayEntry.manualOvertime != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                  'Manuelle Anpassung: ${displayEntry.manualOvertime.toString().split('.').first}'
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              dailyTarget != null
                                  ? 'Überstunden: ${_formatDuration(displayEntry.calculateOvertime(dailyTarget!))}'
                                  : 'Überstunden: —',
                              style: TextStyle(
                                  color: dailyTarget != null
                                      ? (displayEntry
                                              .calculateOvertime(dailyTarget!)
                                              .isNegative
                                          ? Colors.red
                                          : Colors.green)
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class WeeklyReportView extends ConsumerWidget {
  const WeeklyReportView({super.key});

  String _formatDuration(Duration duration) {
    final bool isNegative = duration.isNegative;
    final Duration absDuration = duration.abs();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(absDuration.inHours);
    final minutes = twoDigits(absDuration.inMinutes.remainder(60));
    final sign = isNegative ? '-' : '+';
    return '$sign$hours:$minutes';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsState = ref.watch(reportsViewModelProvider);
    final reportsNotifier = ref.read(reportsViewModelProvider.notifier);

    final settingsState = ref.watch(settingsViewModelProvider);
    final double weeklyTargetHours = settingsState.maybeWhen(
      data: (s) => s.weeklyTargetHours,
      orElse: () => 40.0,
    );
    final Duration dailyTarget = Duration(
      minutes: ((weeklyTargetHours / 5.0) * 60).round(),
    );

    if (reportsState.isLoading) {
      return const LoadingIndicator();
    }

    final weeklyReport = reportsState.weeklyReportState;
    final selectedDay = reportsState.selectedDay ?? DateTime.now();
    final startOfWeek = DateTime(selectedDay.year, selectedDay.month,
        selectedDay.day - selectedDay.weekday + 1);
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final Duration weeklyOvertimeLocal = weeklyReport.dailyWork.entries
        .fold(Duration.zero, (sum, e) => sum + (e.value - dailyTarget));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => reportsNotifier
                    .selectDate(startOfWeek.subtract(const Duration(days: 7))),
                tooltip: 'Vorherige Woche',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Wochenbericht',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${DateFormat.MMMd('de_DE').format(startOfWeek)} - ${DateFormat.MMMd('de_DE').format(endOfWeek)}',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'KW ${(startOfWeek.difference(DateTime(startOfWeek.year, 1, 1)).inDays / 7).floor() + 1}',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => reportsNotifier
                    .selectDate(startOfWeek.add(const Duration(days: 7))),
                tooltip: 'Nächste Woche',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 16),
          if (weeklyReport.workDays == 0)
            const Center(child: Text('Keine Daten für diese Woche.'))
          else
            Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Gesamte Arbeitszeit:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                                weeklyReport.dailyWork.values
                                    .fold(Duration.zero, (prev, d) => prev + d)
                                    .toString()
                                    .split('.')
                                    .first,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Gesamte Pausen:'),
                            Text(weeklyReport.totalBreakDuration
                                .toString()
                                .split('.')
                                .first),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Arbeitstage:'),
                            Text('${weeklyReport.workDays}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Ø Arbeitszeit pro Tag:'),
                            Text(weeklyReport.averageWorkDuration
                                .toString()
                                .split('.')
                                .first),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Überstunden:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              _formatDuration(weeklyOvertimeLocal),
                              style: TextStyle(
                                  color: weeklyOvertimeLocal.isNegative
                                      ? Colors.red
                                      : Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Tägliche Arbeitszeiten:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...weeklyReport.dailyWork.entries.map((entry) {
                  final date = entry.key;
                  final duration = entry.value;
                  return GestureDetector(
                    onTap: () {
                      reportsNotifier.selectDate(date);
                      _showDayEntriesBottomSheet(context, ref, date);
                    },
                    child: Card(
                      child: ListTile(
                        title: Text(DateFormat.EEEE('de_DE').format(date)),
                        subtitle: Text(DateFormat.yMMMd('de_DE').format(date)),
                        trailing: Text(duration.toString().split('.').first),
                      ),
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}

void _showDayEntriesBottomSheet(BuildContext context, WidgetRef ref, DateTime date) {
  ref.read(reportsViewModelProvider.notifier).selectDate(date);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DayEntriesBottomSheet(date: date),
  );
}

class MonthlyReportView extends ConsumerWidget {
  const MonthlyReportView({super.key});

  String _formatDuration(Duration duration) {
    final bool isNegative = duration.isNegative;
    final Duration absDuration = duration.abs();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(absDuration.inHours);
    final minutes = twoDigits(absDuration.inMinutes.remainder(60));
    final sign = isNegative ? '-' : '+';
    return '$sign$hours:$minutes';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsState = ref.watch(reportsViewModelProvider);
    final reportsNotifier = ref.read(reportsViewModelProvider.notifier);

    if (reportsState.isLoading) {
      return const LoadingIndicator();
    }

    final monthlyReport = reportsState.monthlyReportState;
    final selectedMonth = reportsState.selectedMonth ?? DateTime.now();
    final month = DateFormat.yMMMM('de_DE')
        .format(DateTime(selectedMonth.year, selectedMonth.month));

    final settingsState = ref.watch(settingsViewModelProvider);
    final double weeklyTargetHours = settingsState.maybeWhen(
      data: (s) => s.weeklyTargetHours,
      orElse: () => 40.0,
    );
    final Duration dailyTarget = Duration(
      minutes: ((weeklyTargetHours / 5.0) * 60).round(),
    );
    final Duration monthlyOvertimeLocal = monthlyReport.dailyWork.entries
        .fold(Duration.zero, (sum, e) => sum + (e.value - dailyTarget));

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => reportsNotifier.onMonthChanged(
                  DateTime(selectedMonth.year, selectedMonth.month - 1, 1)),
              tooltip: 'Vorheriger Monat',
            ),
            Expanded(
              child: Text(
                month,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => reportsNotifier.onMonthChanged(
                  DateTime(selectedMonth.year, selectedMonth.month + 1, 1)),
              tooltip: 'Nächster Monat',
            ),
          ],
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 16),
        if (monthlyReport.workDays == 0)
          const Center(child: Text('Keine Daten für diesen Monat.'))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gesamte Arbeitszeit:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                              monthlyReport.dailyWork.values
                                  .fold(Duration.zero, (prev, d) => prev + d)
                                  .toString()
                                  .split('.')
                                  .first,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gesamte Pausen:'),
                          Text(monthlyReport.totalBreakDuration
                              .toString()
                              .split('.')
                              .first),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Arbeitstage:'),
                          Text('${monthlyReport.workDays}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ø Arbeitszeit pro Tag:'),
                          Text(monthlyReport.averageWorkDuration
                              .toString()
                              .split('.')
                              .first),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ø Arbeitszeit pro Woche:'),
                          Text(monthlyReport.avgWorkDurationPerWeek
                              .toString()
                              .split('.')
                              .first),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Überstunden Monat:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            _formatDuration(monthlyOvertimeLocal),
                            style: TextStyle(
                                color: monthlyOvertimeLocal.isNegative
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gesamt-Überstunden:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            _formatDuration(monthlyReport.totalOvertime),
                            style: TextStyle(
                                color: monthlyReport.totalOvertime.isNegative
                                    ? Colors.red
                                    : Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Wochenübersicht:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              ...monthlyReport.weeklyWork.entries.map((entry) {
                final weekNumber = entry.key;
                final duration = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text('Kalenderwoche $weekNumber'),
                    trailing: Text(duration.toString().split('.').first),
                  ),
                );
              }),
              const SizedBox(height: 24),
              const Text('Tagesübersicht:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              ...monthlyReport.dailyWork.entries.map((entry) {
                final date = entry.key;
                final duration = entry.value;
                return GestureDetector(
                  onTap: () {
                     _showDayEntriesBottomSheet(context, ref, date);
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      title: Text(DateFormat.EEEE('de_DE').format(date)),
                      subtitle: Text(DateFormat.yMMMd('de_DE').format(date)),
                      trailing: Text(duration.toString().split('.').first),
                    ),
                  ),
                );
              }),
            ],
          ),
      ],
    );
  }
}

class _Calendar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onPreviousMonthTapped;
  final VoidCallback? onNextMonthTapped;
  final Set<int>? daysWithEntries;

  const _Calendar({
    required this.selectedDate,
    required this.onDateSelected,
    this.onPreviousMonthTapped,
    this.onNextMonthTapped,
    this.daysWithEntries,
    super.key,
  });

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int _getFirstDayOffset(int year, int month) {
    int weekday = DateTime(year, month, 1).weekday;
    return weekday - 1; 
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: onPreviousMonthTapped,
                  tooltip: 'Vorheriger Monat',
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM('de_DE').format(selectedDate),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onNextMonthTapped,
                  tooltip: 'Nächster Monat',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(7, (index) {
                final day = DateFormat.E('de_DE').format(
                    DateTime(2023, 1, 2 + index)); // Example year for weekday names
                return Expanded(
                  child: Center(
                    child: Text(day),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7),
              itemCount:
                  _getDaysInMonth(selectedDate.year, selectedDate.month) +
                      _getFirstDayOffset(selectedDate.year, selectedDate.month),
              itemBuilder: (context, index) {
                final firstDayOffset =
                    _getFirstDayOffset(selectedDate.year, selectedDate.month);
                if (index < firstDayOffset) {
                  return const SizedBox.shrink();
                }

                final day = index - firstDayOffset + 1;
                final date =
                    DateTime(selectedDate.year, selectedDate.month, day);
                final isSelected = DateUtils.isSameDay(date, selectedDate);
                final hasEntry = daysWithEntries?.contains(day) ?? false;

                Widget dayWidget = Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                );

                if (hasEntry) {
                  dayWidget = Stack(
                    alignment: Alignment.center,
                    children: [
                      dayWidget, // The day number text
                      Positioned(
                        bottom: 4,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white70 : Theme.of(context).colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return InkWell(
                  onTap: () => onDateSelected(date),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: dayWidget,
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}

class DayEntriesBottomSheet extends ConsumerStatefulWidget {
  final DateTime date;
  const DayEntriesBottomSheet({super.key, required this.date});

  @override
  ConsumerState<DayEntriesBottomSheet> createState() =>
      _DayEntriesBottomSheetState();
}

class _DayEntriesBottomSheetState
    extends ConsumerState<DayEntriesBottomSheet> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { 
        final currentSelectedDayInViewModel = ref.read(reportsViewModelProvider).selectedDay;
        if (currentSelectedDayInViewModel == null || !DateUtils.isSameDay(currentSelectedDayInViewModel, widget.date)) {
           ref.read(reportsViewModelProvider.notifier).selectDate(widget.date);
        }
      }
    });
  }

  void _openEdit(WorkEntryEntity entry) {
    final entryWithCalculatedBreaks =
        ref.read(reportsViewModelProvider.notifier).applyBreakCalculation(entry);

    if (Navigator.of(context).canPop()) {
       Navigator.of(context).pop();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          EditWorkEntryModal(workEntry: entryWithCalculatedBreaks),
    );
  }

  Future<void> _confirmDelete(BuildContext btmSheetItemContext, WidgetRef ref, WorkEntryEntity entry) async {
    final bool? confirmed = await showDialog<bool>(
      context: btmSheetItemContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Eintrag löschen?'),
          content: const Text('Möchten Sie diesen Arbeitseintrag wirklich löschen?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop(false);
                }
              },
            ),
            TextButton(
              child: const Text('Löschen'),
              onPressed: () {
                 if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop(true);
                 }
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(reportsViewModelProvider.notifier).deleteWorkEntry(entry.id);
      if (mounted && Navigator.of(this.context).canPop()) {
        Navigator.of(this.context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsState = ref.watch(reportsViewModelProvider);

    if (reportsState.isLoading && (reportsState.selectedDay == null || !DateUtils.isSameDay(reportsState.selectedDay, widget.date))) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: LoadingIndicator()),
      );
    }

    final entriesForSheetDate = reportsState.dailyReportState.entries
        .where((entry) => DateUtils.isSameDay(entry.date, widget.date))
        .toList();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Einträge am ${DateFormat.yMMMMd('de_DE').format(widget.date)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (entriesForSheetDate.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Keine Einträge für diesen Tag.'),
                          Builder(builder: (context) {
                            final today = DateUtils.dateOnly(DateTime.now());
                            final sheetDateOnly = DateUtils.dateOnly(widget.date);

                            if (sheetDateOnly.isBefore(today)) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: ElevatedButton(
                                  onPressed: () {
                                    final newEntry = WorkEntryEntity(
                                      id: DateFormat('yyyy-MM-dd').format(widget.date),
                                      date: widget.date, 
                                      workStart: null,
                                      workEnd: null,
                                      breaks: [],
                                      isManuallyEntered: true,
                                      description: null,
                                      manualOvertime: null,
                                    );
                                    _openEdit(newEntry);
                                  },
                                  child: const Text('Eintrag hinzufügen'),
                                ),
                              );
                            } else {
                              return const SizedBox.shrink();
                            }
                          }),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: entriesForSheetDate.length,
                      itemBuilder: (ctx, index) {
                        final entry = entriesForSheetDate[index];
                        final displayEntry = ref
                            .read(reportsViewModelProvider.notifier)
                            .applyBreakCalculation(entry);

                        final DateTime? start = displayEntry.workStart;
                        final DateTime? end =
                            displayEntry.workEnd ?? DateTime.now();
                        Duration worked = Duration.zero;

                        if (start != null && end != null) {
                          Duration breakDur = Duration.zero;
                          for (final b in displayEntry.breaks) {
                            final DateTime bStart = b.start;
                            final DateTime bEnd = b.end ?? end;
                            final DateTime effStart =
                                bStart.isBefore(start) ? start : bStart;
                            final DateTime effEnd =
                                bEnd.isAfter(end) ? end : bEnd;
                            if (effEnd.isAfter(effStart)) {
                              breakDur += effEnd.difference(effStart);
                            }
                          }
                          worked = end.difference(start) - breakDur;
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            title: Text(
                                'Arbeitszeit: ${worked.toString().split('.').first}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Start: ${start != null ? DateFormat('HH:mm').format(start) : '-'}'
                                ),
                                Text(
                                    'Ende: ${displayEntry.workEnd != null ? DateFormat('HH:mm').format(displayEntry.workEnd!) : 'läuft...'}'
                                ),
                                Text(
                                    'Pause: ${displayEntry.totalBreakDuration.toString().split('.').first}'
                                ),
                                if (displayEntry.manualOvertime != null)
                                  Text(
                                      'Manuelle Anpassung: ${displayEntry.manualOvertime.toString().split('.').first}'
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _openEdit(entry),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _confirmDelete(ctx, ref, entry),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
