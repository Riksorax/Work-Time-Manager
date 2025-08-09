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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEditWorkEntryModal(WorkEntryEntity entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditWorkEntryModal(workEntry: entry),
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
                  return GestureDetector(
                    onTap: () => onEntryTap(entry),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        title: Text('Arbeitszeit: ${entry.effectiveWorkDuration.toString().split('.').first}'),
                        subtitle: Text('Pause: ${entry.totalBreakDuration.toString().split('.').first}'),
                        trailing: const Icon(Icons.edit),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsState = ref.watch(reportsViewModelProvider);

    if (reportsState.isLoading) {
      return const LoadingIndicator();
    }

    final weeklyReport = reportsState.weeklyReportState;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wochenbericht',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (weeklyReport.workDays == 0)
            const Center(child: Text('Keine Daten für diese Woche.'))
          else
            ListTile(
              title: const Text('Gesamte Arbeitszeit'),
              trailing: Text(weeklyReport.totalWorkDuration.toString().split('.').first),
            ),
        ],
      ),
    );
  }
}

class MonthlyReportView extends ConsumerWidget {
  const MonthlyReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsState = ref.watch(reportsViewModelProvider);

    if (reportsState.isLoading) {
      return const LoadingIndicator();
    }

    final monthlyReport = reportsState.monthlyReportState;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monatsbericht',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (monthlyReport.workDays == 0)
            const Center(child: Text('Keine Daten für diesen Monat.'))
          else
            ListTile(
              title: const Text('Gesamte Arbeitszeit'),
              trailing: Text(monthlyReport.totalWorkDuration.toString().split('.').first),
            )
        ],
      ),
    );
  }
}

class _Calendar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _Calendar({required this.selectedDate, required this.onDateSelected});

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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final day =
                    DateFormat.E('de_DE').format(DateTime(2023, 1, 2 + index));
                return Text(day);
              }),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7),
              itemCount:
                  DateTime(selectedDate.year, selectedDate.month + 1, 0).day,
              itemBuilder: (context, index) {
                final day = index + 1;
                final date =
                    DateTime(selectedDate.year, selectedDate.month, day);
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
