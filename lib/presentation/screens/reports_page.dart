import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/work_entry_extensions.dart';
import '../view_models/reports_view_model.dart';
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
      ref.read(reportsViewModelProvider.notifier).onMonthChanged(DateTime.now());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEditWorkEntryModal(WorkEntryEntity entry) {
    // Anwenden der automatischen Pausenberechnung vor dem Anzeigen des Modals
    final entryWithCalculatedBreaks = ref.read(reportsViewModelProvider.notifier).applyBreakCalculation(entry);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditWorkEntryModal(workEntry: entryWithCalculatedBreaks),
    ).then((_) {
      ref.read(reportsViewModelProvider.notifier).onMonthChanged(DateTime.now());
    });
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
          DailyReportView(onEntryTap: _showEditWorkEntryModal),
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

  // Hilfsmethode zum Formatieren der Dauer mit Vorzeichen
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

    final dailyReport = reportsState.dailyReportState;

    return ListView(
      children: [
        _Calendar(
          selectedDate: reportsState.selectedDay ?? DateTime.now(),
          onDateSelected: (date) => reportsNotifier.selectDate(date),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tagesbericht für ${DateFormat.yMMMMd('de_DE').format(reportsState.selectedDay ?? DateTime.now())}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (dailyReport.entries.isEmpty)
                const Center(child: Text('Keine Daten für diesen Tag.'))
              else
                ...dailyReport.entries.map((entry) {
                  // Automatische Pausen für die Darstellung berücksichtigen
                  final displayEntry = ref.read(reportsViewModelProvider.notifier).applyBreakCalculation(entry);
                  return GestureDetector(
                    onTap: () => onEntryTap(entry),
                    child: Card(
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
                                  'Arbeitszeit: ${displayEntry.effectiveWorkDuration.toString().split('.').first}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => onEntryTap(entry),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Start: ${DateFormat('HH:mm').format(displayEntry.workStart!)}'),
                            Text('Ende: ${DateFormat('HH:mm').format(displayEntry.workEnd!)}'),
                            Text('Pause: ${displayEntry.totalBreakDuration.toString().split('.').first}'),
                            if (displayEntry.manualOvertime != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('Manuelle Anpassung: ${displayEntry.manualOvertime.toString().split('.').first}'),
                              ),
                            // Berechnete Überstunden anzeigen
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Überstunden: ${_formatDuration(displayEntry.calculateOvertime(const Duration(hours: 8)))}',
                                style: TextStyle(
                                  color: displayEntry.calculateOvertime(const Duration(hours: 8)).isNegative 
                                      ? Colors.red 
                                      : Colors.green,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class WeeklyReportView extends ConsumerWidget {
  const WeeklyReportView({super.key});

  // Hilfsmethode zum Formatieren der Dauer mit Vorzeichen
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

    final weeklyReport = reportsState.weeklyReportState;
    final selectedDay = reportsState.selectedDay ?? DateTime.now();
    final startOfWeek = DateTime(selectedDay.year, selectedDay.month, selectedDay.day - selectedDay.weekday + 1);
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

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
                onPressed: () => reportsNotifier.selectDate(
                  startOfWeek.subtract(const Duration(days: 7))),
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
                onPressed: () => reportsNotifier.selectDate(
                  startOfWeek.add(const Duration(days: 7))),
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
                            const Text('Gesamte Arbeitszeit:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(weeklyReport.totalWorkDuration.toString().split('.').first, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Gesamte Pausen:'),
                            Text(weeklyReport.totalBreakDuration.toString().split('.').first),
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
                            Text(weeklyReport.avgWorkDurationPerDay.toString().split('.').first),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Überstunden:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              _formatDuration(weeklyReport.overtime),
                              style: TextStyle(
                                color: weeklyReport.overtime.isNegative ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Tägliche Arbeitszeiten:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...weeklyReport.dailyWork.entries.map((entry) {
                  final date = entry.key;
                  final duration = entry.value;
                  return GestureDetector(
                    onTap: () => reportsNotifier.selectDate(date),
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

class MonthlyReportView extends ConsumerWidget {
  const MonthlyReportView({super.key});

  // Hilfsmethode zum Formatieren der Dauer mit Vorzeichen
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
    final month = DateFormat.yMMMM('de_DE').format(DateTime(selectedMonth.year, selectedMonth.month));

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => reportsNotifier.onMonthChanged(
                DateTime(selectedMonth.year, selectedMonth.month - 1)),
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
                DateTime(selectedMonth.year, selectedMonth.month + 1)),
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
                          const Text('Gesamte Arbeitszeit:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(monthlyReport.totalWorkDuration.toString().split('.').first, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gesamte Pausen:'),
                          Text(monthlyReport.totalBreakDuration.toString().split('.').first),
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
                          Text(monthlyReport.avgWorkDurationPerDay.toString().split('.').first),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ø Arbeitszeit pro Woche:'),
                          Text(monthlyReport.avgWorkDurationPerWeek.toString().split('.').first),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Überstunden Monat:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            _formatDuration(monthlyReport.overtime),
                            style: TextStyle(
                              color: monthlyReport.overtime.isNegative ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gesamt-Überstunden:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            _formatDuration(monthlyReport.totalOvertime),
                            style: TextStyle(
                              color: monthlyReport.totalOvertime.isNegative ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Wochenübersicht:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              const Text('Tagesübersicht:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              ...monthlyReport.dailyWork.entries.map((entry) {
                final date = entry.key;
                final duration = entry.value;
                return GestureDetector(
                  onTap: () => reportsNotifier.selectDate(date),
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

  const _Calendar({required this.selectedDate, required this.onDateSelected});

  // Hilfsmethode zur Berechnung der Tage im Monat
  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  // Hilfsmethode zur Berechnung des Offsets für den ersten Tag des Monats
  int _getFirstDayOffset(int year, int month) {
    int weekday = DateTime(year, month, 1).weekday;
    // In Europa beginnt die Woche mit Montag (1), daher Offset -1
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
            Text(
              DateFormat.yMMMM('de_DE').format(selectedDate),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(7, (index) {
                // Wir generieren Wochentagsabkürzungen von Montag bis Sonntag
                final day =
                    DateFormat.E('de_DE').format(DateTime(2023, 1, 2 + index)); // 2023-01-02 ist ein Montag
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
              itemCount: _getDaysInMonth(selectedDate.year, selectedDate.month) +
                  _getFirstDayOffset(selectedDate.year, selectedDate.month),
              itemBuilder: (context, index) {
                // Berücksichtigung des Monatsanfangs-Offsets
                final firstDayOffset = _getFirstDayOffset(selectedDate.year, selectedDate.month);
                if (index < firstDayOffset) {
                  return const SizedBox.shrink(); // Leere Zellen vor dem Monatsbeginn
                }

                final day = index - firstDayOffset + 1;
                final date = DateTime(selectedDate.year, selectedDate.month, day);
                final isSelected = date.day == selectedDate.day &&
                    date.month == selectedDate.month &&
                    date.year == selectedDate.year;
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
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
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
