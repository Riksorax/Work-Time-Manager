import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/core/utils/logger.dart';
import 'package:flutter_work_time/core/utils/time_format.dart';
import 'package:flutter_work_time/core/utils/time_precision.dart';
import 'package:intl/intl.dart';
import '../../core/providers/subscription_provider.dart';
import '../../core/services/pdf_report_service.dart';

import '../../domain/entities/work_entry_extensions.dart';
import '../../domain/utils/german_holidays.dart';
import '../../domain/utils/weekday_labels.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/common/paywall_launcher.dart';
import '../widgets/common/responsive_center.dart';
import '../widgets/premium_blur_gate.dart';
import '../state/monthly_report_state.dart';
import '../state/reports_state.dart';
import '../state/weekly_report_state.dart';
import '../state/yearly_report_state.dart';
import '../view_models/insights_view_model.dart';
import '../view_models/reports_view_model.dart';
import '../view_models/settings_view_model.dart';
import '../view_models/yearly_report_view_model.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/edit_work_entry_modal.dart';
import '../widgets/quick_entry_dialog.dart';
import '../widgets/batch_quick_entry_dialog.dart';
import '../widgets/weekly_reflection_dialog.dart';
import '../widgets/work_profile_switcher.dart';
import '../../domain/entities/work_entry_entity.dart';
import 'login_page.dart';

// Provider für den gewünschten Tab-Index nach Login
final pendingReportTabIndexProvider =
    NotifierProvider<PendingTabIndexNotifier, int?>(
        PendingTabIndexNotifier.new);

class PendingTabIndexNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  set state(int? value) => super.state = value;
}


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
    _tabController = TabController(length: 5, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reportsViewModelProvider.notifier).loadCurrentMonthData();

      final pendingTabIndex = ref.read(pendingReportTabIndexProvider);
      if (pendingTabIndex != null) {
        _tabController.index = pendingTabIndex;
        ref.read(pendingReportTabIndexProvider.notifier).state = null;
      }
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
    // Reagiert auch dann auf einen Tab-Wechsel-Wunsch (z.B. Klick auf eine
    // Kalenderwoche im Monatsbericht oder einen Monat im Jahresbericht, siehe
    // #258), wenn ReportsPage schon gemountet ist - anders als der einmalige
    // Check in initState(), der nur den allerersten Frame abdeckt.
    ref.listen<int?>(pendingReportTabIndexProvider, (previous, next) {
      if (next != null) {
        _tabController.animateTo(next);
        ref.read(pendingReportTabIndexProvider.notifier).state = null;
      }
    });

    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navReports),
        actions: const [WorkProfileSwitcher()],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l10n.tabDaily),
            Tab(text: l10n.tabWeekly),
            Tab(text: l10n.tabMonthly),
            Tab(text: l10n.tabYearly),
            const Tab(text: 'Insights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DailyReportView(
              onEntryTap: (entry) => _showEditWorkEntryModal(entry, context)),
          const WeeklyReportView(),
          const MonthlyReportView(),
          const YearlyReportView(),
          const InsightsView(),
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

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, WorkEntryEntity entry) async {
    final l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.deleteEntryTitle),
          content: Text(l10n.deleteEntryConfirm),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: Text(l10n.deleteAction),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref
          .read(reportsViewModelProvider.notifier)
          .deleteWorkEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsState = ref.watch(reportsViewModelProvider);
    final reportsNotifier = ref.read(reportsViewModelProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    final settingsValue = ref.watch(settingsViewModelProvider);

    return settingsValue.when(
      data: (settingsState) {
        if (reportsState.isLoading) {
          return const LoadingIndicator();
        }

        final dailyReport = reportsState.dailyReportState;
        final DateTime selectedDay = reportsState.selectedDay ?? DateTime.now();

        // Effektives Tages-Soll: 0 für Zusatztage (mehr Arbeitstage als konfiguriert)
        final dailyTarget = reportsNotifier.getEffectiveDailyTargetForDate(selectedDay);
        final isExtraDay = dailyTarget == Duration.zero && dailyReport.entries.isNotEmpty;
        final DateTime selectedMonth =
            reportsState.selectedMonth ?? DateTime.now();

        final Set<int> daysWithEntriesInMonth = reportsState
            .monthlyReportState.dailyWork.keys
            .where((date) =>
                date.year == selectedMonth.year &&
                date.month == selectedMonth.month)
            .map((date) => date.day)
            .toSet();

        Duration totalWorked = Duration.zero;
        Duration totalManualAdjustment = Duration.zero;
        for (final e in dailyReport.entries) {
          final dE = ref
              .read(reportsViewModelProvider.notifier)
              .applyBreakCalculation(e);

          // Nur Arbeitseinträge zählen zur Arbeitszeit
          // Urlaub, Krankheit und Feiertage erfüllen das Soll automatisch
          if (dE.type == WorkEntryType.work) {
            final DateTime? start = dE.workStart;
            // FIX: DateTime type, not DateTime? to ensure non-null usage later
            final DateTime end = dE.workEnd ?? nowToMinute();
            if (start != null) {
              // end is always not null due to ??
              Duration breakDur = Duration.zero;
              for (final b in dE.breaks) {
                final DateTime bStart = b.start;
                // b.end is nullable, end is not
                final DateTime bEnd = b.end ?? end;
                final DateTime effStart = bStart.isBefore(start) ? start : bStart;
                final DateTime effEnd = bEnd.isAfter(end) ? end : bEnd;
                if (effEnd.isAfter(effStart)) {
                  breakDur += effEnd.difference(effStart);
                }
              }
              totalWorked += end.difference(start) - breakDur;
            }
          }

          if (dE.manualOvertime != null) {
            totalManualAdjustment += dE.manualOvertime!;
          }
        }

        // Bei speziellen Tagen (Urlaub, Krankheit, Feiertag) wird das Soll als erfüllt betrachtet
        // Daher: Wenn kein normaler Arbeitseintrag vorhanden ist, aber ein spezieller,
        // zählt totalWorked als erfüllt
        bool hasSpecialEntry = dailyReport.entries.any((e) => e.type != WorkEntryType.work);
        if (hasSpecialEntry && totalWorked == Duration.zero) {
          totalWorked = dailyTarget;
        }

        final dayOvertime = totalWorked - dailyTarget + totalManualAdjustment;

        // --- Widgets Construction ---

        final calendarWidget = Column(
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
              daysWithEntries: daysWithEntriesInMonth,
            ),
          ],
        );

        final detailsWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.dailyReportTitle(DateFormat.yMMMMd(locale).format(selectedDay)),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (dailyReport.entries.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.noDataForDay),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 280,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final newEntry = WorkEntryEntity(
                                  id: DateFormat('yyyy-MM-dd')
                                      .format(selectedDay),
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
                              icon: const Icon(Icons.add),
                              label: Text(l10n.addEntryAction),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 280,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (reportsState.selectedDates.isNotEmpty) {
                                  await _handleBatchQuickEntry(
                                      context, ref, reportsState, reportsNotifier);
                                } else {
                                  await _handleQuickEntry(
                                      context, ref, selectedDay);
                                }
                              },
                              icon: const Icon(Icons.flash_on),
                              label: reportsState.selectedDates.isNotEmpty
                                  ? Text(l10n.quickEntryTitleBatch(reportsState.selectedDates.length))
                                  : Text(l10n.quickEntryButton),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Batch-Button auch wenn aktueller Tag bereits Einträge hat
              if (reportsState.selectedDates.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: SizedBox(
                      width: 280,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _handleBatchQuickEntry(
                              context, ref, reportsState, reportsNotifier);
                        },
                        icon: const Icon(Icons.flash_on),
                        label: Text(l10n.quickEntryTitleBatch(reportsState.selectedDates.length)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondaryContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isExtraDay ? l10n.targetExtraDayLabel : l10n.targetDayLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            isExtraDay
                                ? '-' // Deutliche Kennzeichnung: kein Tages-Soll
                                : '${dailyTarget.inHours.toString().padLeft(2, '0')}:${dailyTarget.inMinutes.remainder(60).toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.actualDayLabel),
                          Text(
                            '${totalWorked.inHours.toString().padLeft(2, '0')}:${totalWorked.inMinutes.remainder(60).toString().padLeft(2, '0')}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.balanceDayLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            _formatDuration(dayOvertime),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (dayOvertime.isNegative
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
                final DateTime? start = displayEntry.workStart;
                final DateTime end = displayEntry.workEnd ?? nowToMinute();
                Duration breakDuration = Duration.zero;
                if (start != null) {
                  for (final b in displayEntry.breaks) {
                    final DateTime bStart = b.start;
                    final DateTime bEnd = b.end ?? end;
                    final DateTime effStart =
                        bStart.isBefore(start) ? start : bStart;
                    final DateTime effEnd = bEnd.isAfter(end) ? end : bEnd;
                    if (effEnd.isAfter(effStart)) {
                      breakDuration += effEnd.difference(effStart);
                    }
                  }
                }
                final Duration workedDuration = (start != null)
                    ? end.difference(start) - breakDuration
                    : Duration.zero;

                final isSpecialType = displayEntry.type != WorkEntryType.work;

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
                              isSpecialType
                                  ? _getWorkEntryTypeLabel(l10n, displayEntry.type)
                                  : l10n.workTimeLabel(workedDuration.toString().split('.').first),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => onEntryTap(entry),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete,
                                      color: Colors.red.shade700),
                                  onPressed: () =>
                                      _confirmDelete(context, ref, entry),
                                ),
                              ],
                            )
                          ],
                        ),
                        if (!isSpecialType ||
                            displayEntry.workStart != null ||
                            displayEntry.workEnd != null) ...[
                          const SizedBox(height: 8),
                          Text(l10n.startValueLabel(displayEntry.workStart != null ? formatTime(displayEntry.workStart!, use24HourFormat: settingsState.settings.use24HourFormat) : '-')),
                          Text(l10n.endValueLabel(displayEntry.workEnd != null ? formatTime(displayEntry.workEnd!, use24HourFormat: settingsState.settings.use24HourFormat) : (isSpecialType ? '-' : l10n.breakInProgress))),
                          if (!isSpecialType)
                            Text(l10n.breakValueLabel(displayEntry.totalBreakDuration.toString().split('.').first)),
                        ],
                        if (displayEntry.manualOvertime != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(l10n.manualAdjustmentLabel(displayEntry.manualOvertime.toString().split('.').first)),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            l10n.overtimeValueLabel(_formatDuration(displayEntry.calculateOvertime(dailyTarget))),
                            style: TextStyle(
                                color: (displayEntry
                                        .calculateOvertime(dailyTarget)
                                        .isNegative
                                    ? Colors.red
                                    : Colors.green),
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
        );

        return ResponsiveCenter(
          maxContentWidth: 1200, // Increased for side-by-side view
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                // Side-by-side layout for desktop/wide tablets
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 400,
                      child: SingleChildScrollView(
                        child: calendarWidget,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                        child: detailsWidget,
                      ),
                    ),
                  ],
                );
              } else {
                // Vertical layout for mobile
                return ListView(
                  children: [
                    calendarWidget,
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: detailsWidget,
                    ),
                  ],
                );
              }
            },
          ),
        );
      },
      loading: () => const LoadingIndicator(),
      error: (error, stackTrace) => Center(
        child: Text(l10n.errorLoadingSettings('$error')),
      ),
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
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    // 1. Nicht eingeloggt: Nur Anmelde-Aufforderung
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.loginRequiredWeekly),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(pendingReportTabIndexProvider.notifier).state = 1;
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const LoginPage(returnToIndex: 1)),
                );
              },
              child: Text(l10n.loginButton),
            ),
          ],
        ),
      );
    }

    // 2. Eingeloggt: Prüfe Premium-Status
    final isPremium = ref.watch(isPremiumProvider);

    if (!isPremium) {
      return PremiumBlurGate(
        featureTitle: l10n.weeklyReportsFeatureTitle,
        featureText: l10n.weeklyReportsFeatureText,
        onUpgrade: kIsWeb ? null : () {
          if (context.mounted) showPaywall(context);
        },
        child: const _WeeklyReportPlaceholder(),
      );
    }

    // 3. Eingeloggt & Premium: Zeige Bericht
    final reportsState = ref.watch(reportsViewModelProvider);
    final reportsNotifier = ref.read(reportsViewModelProvider.notifier);

    final settingsValue = ref.watch(settingsViewModelProvider);

    return settingsValue.when(
        data: (settingsState) {
          final double weeklyTargetHours =
              settingsState.settings.weeklyTargetHours;
          final Duration dailyTarget = Duration(
            minutes:
                ((weeklyTargetHours / settingsState.settings.workdays.length) *
                        60)
                    .round(),
          );

          if (reportsState.isLoading) {
            return const LoadingIndicator();
          }

          final weeklyReport = reportsState.weeklyReportState;
          final selectedDay = reportsState.selectedDay ?? DateTime.now();
          final startOfWeek = DateTime(selectedDay.year, selectedDay.month,
              selectedDay.day - selectedDay.weekday + 1);
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          final weekNumber =
              (startOfWeek.difference(DateTime(startOfWeek.year, 1, 1)).inDays / 7)
                      .floor() +
                  1;
          final Duration weeklyOvertimeLocal = weeklyReport.dailyWork.entries
              .fold(Duration.zero, (sum, e) => sum + (e.value - dailyTarget));

          return ResponsiveCenter(
              child: SingleChildScrollView(
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
                      tooltip: l10n.previousWeekTooltip,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            l10n.weeklyReportTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '${DateFormat.MMMd(locale).format(startOfWeek)} - ${DateFormat.MMMd(locale).format(endOfWeek)}',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.weekNumberLabel(weekNumber),
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
                      tooltip: l10n.nextWeekTooltip,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => WeeklyReflectionDialog(
                            year: startOfWeek.year,
                            week: weekNumber,
                          ),
                        ),
                        icon: const Icon(Icons.rate_review_outlined),
                        label: Text(l10n.weeklyReflectionButton,
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _exportWeeklyReportPdf(
                          context: context,
                          startOfWeek: startOfWeek,
                          endOfWeek: endOfWeek,
                          weekNumber: weekNumber,
                          weeklyReport: weeklyReport,
                          overtime: weeklyOvertimeLocal,
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(l10n.exportAsPdfButton,
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (weeklyReport.workDays == 0)
                  Center(child: Text(l10n.noDataForWeek))
                else
                  Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(l10n.totalWorkTimeLabel,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      weeklyReport.dailyWork.values
                                          .fold(Duration.zero,
                                              (prev, d) => prev + d)
                                          .toString()
                                          .split('.')
                                          .first,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(l10n.totalBreaksLabel),
                                  Text(weeklyReport.totalBreakDuration
                                      .toString()
                                      .split('.')
                                      .first),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(l10n.workdaysCountLabel),
                                  Text('${weeklyReport.workDays}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(l10n.avgWorkPerDayLabel),
                                  Text(weeklyReport.averageWorkDuration
                                      .toString()
                                      .split('.')
                                      .first),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(l10n.overtimeColonLabel,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
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
                      Text(l10n.dailyWorkTimesLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              title:
                                  Text(DateFormat.EEEE(locale).format(date)),
                              subtitle:
                                  Text(DateFormat.yMMMd(locale).format(date)),
                              trailing:
                                  Text(duration.toString().split('.').first),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
              ],
            ),
          ));
        },
        loading: () => const LoadingIndicator(),
        error: (error, stackTrace) => Center(
              child: Text(l10n.errorLoadingSettings('$error')),
            ));
  }
}

void _showDayEntriesBottomSheet(
    BuildContext context, WidgetRef ref, DateTime date) {
  ref.read(reportsViewModelProvider.notifier).selectDate(date);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DayEntriesBottomSheet(date: date),
  );
}

/// Entspricht exakt `_getWeekNumber` in [ReportsViewModel] - dort werden die
/// Schlüssel für `monthlyReport.weeklyWork` berechnet. Muss identisch bleiben,
/// damit ein Tap auf eine Kalenderwoche im Monatsbericht (#258) auf die
/// richtige Woche navigiert.
int _isoWeekNumber(DateTime date) {
  final firstWeek = DateTime(date.year, 1, 4);
  final dayOfWeek = firstWeek.weekday;
  final firstDayOfFirstWeek = firstWeek.subtract(Duration(days: dayOfWeek - 1));
  final diff = date.difference(firstDayOfFirstWeek).inDays;
  return (diff / 7).floor() + 1;
}

/// Sucht innerhalb von [month] den ersten Tag, dessen Kalenderwoche
/// [weekNumber] entspricht (siehe #258 - Klick auf Kalenderwoche im
/// Monatsbericht → Wochenbericht).
DateTime? _firstDateInMonthForWeek(DateTime month, int weekNumber) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  for (var day = 1; day <= daysInMonth; day++) {
    final date = DateTime(month.year, month.month, day);
    if (_isoWeekNumber(date) == weekNumber) return date;
  }
  return null;
}

/// Navigiert vom Monatsbericht zum Wochenbericht der angetippten
/// Kalenderwoche (#258).
void _navigateToWeek(
    WidgetRef ref, {required DateTime month, required int weekNumber}) {
  final date = _firstDateInMonthForWeek(month, weekNumber) ?? month;
  ref.read(reportsViewModelProvider.notifier).selectDate(date);
  ref.read(pendingReportTabIndexProvider.notifier).state = 1;
}

/// Navigiert vom Jahresbericht zum Monatsbericht des angetippten Monats
/// (#258).
void _navigateToMonth(WidgetRef ref, {required int year, required int month}) {
  ref.read(reportsViewModelProvider.notifier).onMonthChanged(DateTime(year, month, 1));
  ref.read(pendingReportTabIndexProvider.notifier).state = 2;
}

final _pdfReportService = PdfReportService();

Future<void> _exportWeeklyReportPdf({
  required BuildContext context,
  required DateTime startOfWeek,
  required DateTime endOfWeek,
  required int weekNumber,
  required WeeklyReportState weeklyReport,
  required Duration overtime,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await _pdfReportService.exportWeeklyReport(
      startOfWeek: startOfWeek,
      endOfWeek: endOfWeek,
      weekNumber: weekNumber,
      workDays: weeklyReport.workDays,
      totalWorkDuration:
          weeklyReport.dailyWork.values.fold(Duration.zero, (prev, d) => prev + d),
      totalBreakDuration: weeklyReport.totalBreakDuration,
      averageWorkDuration: weeklyReport.averageWorkDuration,
      overtime: overtime,
      dailyWork: weeklyReport.dailyWork,
    );
  } catch (e) {
    logger.e('[PDF-Export] Wochenbericht fehlgeschlagen: $e');
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pdfExportFailed('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _exportMonthlyReportPdf({
  required BuildContext context,
  required DateTime month,
  required MonthlyReportState monthlyReport,
  required Duration monthlyOvertime,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await _pdfReportService.exportMonthlyReport(
      month: month,
      workDays: monthlyReport.workDays,
      totalWorkDuration:
          monthlyReport.dailyWork.values.fold(Duration.zero, (prev, d) => prev + d),
      totalBreakDuration: monthlyReport.totalBreakDuration,
      averageWorkDuration: monthlyReport.averageWorkDuration,
      avgWorkDurationPerWeek: monthlyReport.avgWorkDurationPerWeek,
      monthlyOvertime: monthlyOvertime,
      totalOvertime: monthlyReport.totalOvertime,
      weeklyWork: monthlyReport.weeklyWork,
      dailyWork: monthlyReport.dailyWork,
    );
  } catch (e) {
    logger.e('[PDF-Export] Monatsbericht fehlgeschlagen: $e');
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pdfExportFailed('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Exportiert den Jahresbericht als PDF (siehe #256 - fehlte bisher im
/// Gegensatz zu Wochen-/Monatsbericht).
Future<void> _exportYearlyReportPdf({
  required BuildContext context,
  required YearlyReportState yearlyReport,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final locale = Localizations.localeOf(context).toString();
  try {
    await _pdfReportService.exportYearlyReport(
      year: yearlyReport.year,
      totalWorkDays: yearlyReport.totalWorkDays,
      totalVacationDays: yearlyReport.totalVacationDays,
      totalSickDays: yearlyReport.totalSickDays,
      totalHolidayDays: yearlyReport.totalHolidayDays,
      totalNetWorkDuration: yearlyReport.totalNetWorkDuration,
      totalOvertime: yearlyReport.totalOvertime,
      months: [
        for (final m in yearlyReport.months)
          (
            DateFormat.MMMM(locale).format(DateTime(yearlyReport.year, m.month)),
            m.netWorkDuration,
            m.overtime,
            m.workDays,
          ),
      ],
    );
  } catch (e) {
    logger.e('[PDF-Export] Jahresbericht fehlgeschlagen: $e');
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pdfExportFailed('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
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
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    // 1. Nicht eingeloggt: Nur Anmelde-Aufforderung
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.loginRequiredMonthly),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(pendingReportTabIndexProvider.notifier).state = 2;
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const LoginPage(returnToIndex: 1)),
                );
              },
              child: Text(l10n.loginButton),
            ),
          ],
        ),
      );
    }

    // 2. Eingeloggt: Prüfe Premium-Status
    final isPremium = ref.watch(isPremiumProvider);

    if (!isPremium) {
      return PremiumBlurGate(
        featureTitle: l10n.monthlyReportsFeatureTitle,
        featureText: l10n.monthlyReportsFeatureText,
        onUpgrade: kIsWeb ? null : () {
          if (context.mounted) showPaywall(context);
        },
        child: const _MonthlyReportPlaceholder(),
      );
    }

    // 3. Eingeloggt & Premium: Zeige Bericht
    final reportsState = ref.watch(reportsViewModelProvider);
    final reportsNotifier = ref.read(reportsViewModelProvider.notifier);

    if (reportsState.isLoading) {
      return const LoadingIndicator();
    }

    final monthlyReport = reportsState.monthlyReportState;
    final selectedMonth = reportsState.selectedMonth ?? DateTime.now();
    final month = DateFormat.yMMMM(locale)
        .format(DateTime(selectedMonth.year, selectedMonth.month));

    final settingsValue = ref.watch(settingsViewModelProvider);
    return settingsValue.when(
      data: (settingsState) {
        final double weeklyTargetHours =
            settingsState.settings.weeklyTargetHours;
        final Duration dailyTarget = Duration(
          minutes:
              ((weeklyTargetHours / settingsState.settings.workdays.length) *
                      60)
                  .round(),
        );
        final Duration monthlyOvertimeLocal = monthlyReport.dailyWork.entries
            .fold(Duration.zero, (sum, e) => sum + (e.value - dailyTarget));

        // Baue children explizit in einer Liste auf, um Verschachtelungs-/Parserprobleme zu vermeiden
        final List<Widget> monthChildren = [];

        // Header-Row (Monatsnavigation)
        monthChildren.add(Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => reportsNotifier.onMonthChanged(
                  DateTime(selectedMonth.year, selectedMonth.month - 1, 1)),
              tooltip: l10n.previousMonthTooltip,
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
              tooltip: l10n.nextMonthTooltip,
            ),
          ],
        ));

        monthChildren.add(Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _exportMonthlyReportPdf(
              context: context,
              month: DateTime(selectedMonth.year, selectedMonth.month),
              monthlyReport: monthlyReport,
              monthlyOvertime: monthlyOvertimeLocal,
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(l10n.exportAsPdfButton),
          ),
        ));

        monthChildren.add(const SizedBox(height: 8));

        if (monthlyReport.workDays == 0) {
          monthChildren.add(Center(child: Text(l10n.noDataForMonth)));
        } else {
          // Statistikkarte
          monthChildren.add(Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.totalWorkTimeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(monthlyReport.dailyWork.values.fold(Duration.zero, (prev, d) => prev + d).toString().split('.').first,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.totalBreaksLabel),
                      Text(monthlyReport.totalBreakDuration.toString().split('.').first),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.workdaysCountLabel),
                      Text('${monthlyReport.workDays}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.avgWorkPerDayLabel),
                      Text(monthlyReport.averageWorkDuration.toString().split('.').first),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.avgWorkPerWeekLabel),
                      Text(monthlyReport.avgWorkDurationPerWeek.toString().split('.').first),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.monthlyOvertimeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(_formatDuration(monthlyOvertimeLocal),
                          style: TextStyle(color: monthlyOvertimeLocal.isNegative ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.totalOvertimeColonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(_formatDuration(monthlyReport.totalOvertime),
                          style: TextStyle(color: monthlyReport.totalOvertime.isNegative ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ));

          monthChildren.add(const SizedBox(height: 24));
          monthChildren.add(Text(l10n.weekOverviewTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)));
          monthChildren.add(const SizedBox(height: 8));

          // Weekly entries
          for (final entry in monthlyReport.weeklyWork.entries) {
            final weekNumber = entry.key;
            final duration = entry.value;
            monthChildren.add(Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(l10n.calendarWeekLabel(weekNumber)),
                trailing: Text(duration.toString().split('.').first),
                onTap: () => _navigateToWeek(ref,
                    month: selectedMonth, weekNumber: weekNumber),
              ),
            ));
          }

          monthChildren.add(const SizedBox(height: 24));
          monthChildren.add(Text(l10n.dayOverviewTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)));
          monthChildren.add(const SizedBox(height: 8));

          // Daily entries
          for (final entry in monthlyReport.dailyWork.entries) {
            final date = entry.key;
            final duration = entry.value;
            monthChildren.add(
              GestureDetector(
                onTap: () {
                  _showDayEntriesBottomSheet(context, ref, date);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text(DateFormat.EEEE(locale).format(date)),
                    subtitle: Text(DateFormat.yMMMd(locale).format(date)),
                    trailing: Text(duration.toString().split('.').first),
                  ),
                ),
              ),
            );
          }
        }

        return ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: monthChildren,
          ),
        );
      },
      loading: () => const LoadingIndicator(),
      error: (error, stackTrace) => Center(
        child: Text(l10n.errorLoadingSettings('$error')),
      ),
    );
  }
}

/// Jahresbericht (Premium, siehe #136): Monatsvergleich, Gesamtüberstunden
/// sowie Urlaubs-/Kranktage über ein Kalenderjahr.
class YearlyReportView extends ConsumerStatefulWidget {
  const YearlyReportView({super.key});

  @override
  ConsumerState<YearlyReportView> createState() => _YearlyReportViewState();
}

class _YearlyReportViewState extends ConsumerState<YearlyReportView> {
  // TabBarView baut alle Tabs sofort auf - der Ladevorgang wird daher nicht
  // in initState() ausgelöst, sondern erst wenn der Bericht tatsächlich
  // sichtbar wäre (eingeloggt + Premium). Vermeidet unnötige
  // Firestore-/API-Reads für Nutzer ohne Zugriff auf diesen Tab und lädt
  // auch nach, falls ein Premium-Upgrade erst während der Session passiert.
  bool _loadTriggered = false;

  void _loadIfNeeded() {
    if (_loadTriggered) return;
    _loadTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(yearlyReportViewModelProvider.notifier).loadYear(DateTime.now().year);
    });
  }

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
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    // 1. Nicht eingeloggt: Nur Anmelde-Aufforderung
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.loginRequiredYearly),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(pendingReportTabIndexProvider.notifier).state = 3;
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const LoginPage(returnToIndex: 1)),
                );
              },
              child: Text(l10n.loginButton),
            ),
          ],
        ),
      );
    }

    // 2. Eingeloggt: Prüfe Premium-Status
    final isPremium = ref.watch(isPremiumProvider);

    if (!isPremium) {
      return PremiumBlurGate(
        featureTitle: l10n.yearlyReportsFeatureTitle,
        featureText: l10n.yearlyReportsFeatureText,
        onUpgrade: kIsWeb ? null : () {
          if (context.mounted) showPaywall(context);
        },
        child: const _MonthlyReportPlaceholder(),
      );
    }

    // 3. Eingeloggt & Premium: Zeige Bericht
    _loadIfNeeded();
    final yearlyState = ref.watch(yearlyReportViewModelProvider);
    final yearlyNotifier = ref.read(yearlyReportViewModelProvider.notifier);

    if (yearlyState.isLoading) {
      return const LoadingIndicator();
    }

    final monthNames = List.generate(
        12, (i) => DateFormat.MMMM(locale).format(DateTime(2024, i + 1)));

    return ResponsiveCenter(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Jahresnavigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => yearlyNotifier.loadYear(yearlyState.year - 1),
                tooltip: l10n.previousYearTooltip,
              ),
              Expanded(
                child: Text(
                  '${yearlyState.year}',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => yearlyNotifier.loadYear(yearlyState.year + 1),
                tooltip: l10n.nextYearTooltip,
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _exportYearlyReportPdf(
                context: context,
                yearlyReport: yearlyState,
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(l10n.exportAsPdfButton),
            ),
          ),
          const SizedBox(height: 8),
          if (yearlyState.totalWorkDays == 0 &&
              yearlyState.totalVacationDays == 0 &&
              yearlyState.totalSickDays == 0)
            Center(child: Text(l10n.noDataForYear))
          else ...[
            // Statistikkarte
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.totalWorkTimeLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            yearlyState.totalNetWorkDuration.toString().split('.').first,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.workdaysCountLabel),
                        Text('${yearlyState.totalWorkDays}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.vacationDaysLabel),
                        Text('${yearlyState.totalVacationDays}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.sickDaysLabel),
                        Text('${yearlyState.totalSickDays}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.holidaysLabel),
                        Text('${yearlyState.totalHolidayDays}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.totalOvertimeColonLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          _formatDuration(yearlyState.totalOvertime),
                          style: TextStyle(
                              color: yearlyState.totalOvertime.isNegative
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
            Text(l10n.monthOverviewTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            for (final monthSummary in yearlyState.months)
              if (monthSummary.workDays > 0 ||
                  monthSummary.vacationDays > 0 ||
                  monthSummary.sickDays > 0 ||
                  monthSummary.holidayDays > 0)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text(monthNames[monthSummary.month - 1]),
                    subtitle: Text(
                        l10n.workdaysCountInline(monthSummary.workDays, monthSummary.netWorkDuration.toString().split('.').first)),
                    trailing: Text(
                      _formatDuration(monthSummary.overtime),
                      style: TextStyle(
                          color: monthSummary.overtime.isNegative
                              ? Colors.red
                              : Colors.green),
                    ),
                    onTap: () => _navigateToMonth(ref,
                        year: yearlyState.year, month: monthSummary.month),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

/// Zeigt automatisch erkannte Muster in der Arbeitszeit: Wochentags-Analyse,
/// Burnout-Indikator und Produktivitäts-Heatmap nach Startzeit (siehe #134).
class InsightsView extends ConsumerStatefulWidget {
  const InsightsView({super.key});

  @override
  ConsumerState<InsightsView> createState() => _InsightsViewState();
}

class _InsightsViewState extends ConsumerState<InsightsView> {
  // Siehe _YearlyReportViewState: TabBarView baut alle Tabs sofort auf, der
  // Ladevorgang wird daher erst ausgelöst, wenn der Tab tatsächlich sichtbar
  // wäre (eingeloggt + Premium).
  bool _loadTriggered = false;

  void _loadIfNeeded() {
    if (_loadTriggered) return;
    _loadTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(insightsViewModelProvider.notifier).loadInsights();
    });
  }

  String _formatSignedDuration(Duration duration) {
    final isNegative = duration.isNegative;
    final abs = duration.abs();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(abs.inHours);
    final minutes = twoDigits(abs.inMinutes.remainder(60));
    return '${isNegative ? '-' : '+'}$hours:$minutes';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.loginRequiredInsights),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(pendingReportTabIndexProvider.notifier).state = 4;
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const LoginPage(returnToIndex: 1)),
                );
              },
              child: Text(l10n.loginButton),
            ),
          ],
        ),
      );
    }

    final isPremium = ref.watch(isPremiumProvider);

    if (!isPremium) {
      return PremiumBlurGate(
        featureTitle: l10n.insightsFeatureTitle,
        featureText: l10n.insightsFeatureText,
        onUpgrade: kIsWeb ? null : () {
          if (context.mounted) showPaywall(context);
        },
        child: const _MonthlyReportPlaceholder(),
      );
    }

    _loadIfNeeded();
    final insightsState = ref.watch(insightsViewModelProvider);

    if (insightsState.isLoading) {
      return const LoadingIndicator();
    }

    if (insightsState.hasNoData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            l10n.notEnoughDataInsights,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ResponsiveCenter(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (insightsState.burnoutStatus.isWarning)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.burnoutWarning('${insightsState.burnoutStatus.currentStreak}'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (insightsState.burnoutStatus.isWarning) const SizedBox(height: 16),
          if (insightsState.weekdayAverages.isNotEmpty) ...[
            _InsightSectionHeader(
              title: l10n.weekdayAnalysisTitle,
              explanation: l10n.weekdayAnalysisExplanation,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final weekdayAverage in insightsState.weekdayAverages)
                    ListTile(
                      title: Text(weekdayShortLabel(weekdayAverage.weekday, locale)),
                      subtitle: Text(
                          l10n.avgWorkTimeWithCount(weekdayAverage.averageWorkDuration.toString().split('.').first, weekdayAverage.sampleCount)),
                      trailing: Text(
                        _formatSignedDuration(weekdayAverage.deviationFromOverallAverage),
                        style: TextStyle(
                          color: weekdayAverage.deviationFromOverallAverage.isNegative
                              ? Colors.blue
                              : Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (insightsState.heatmap.isNotEmpty) ...[
            _InsightSectionHeader(
              title: l10n.productivityHeatmapTitle,
              explanation: l10n.productivityHeatmapExplanation,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final bucket in insightsState.heatmap)
                    ListTile(
                      title: Text(l10n.startHourLabel(bucket.startHour.toString().padLeft(2, '0'))),
                      subtitle: Text(l10n.sampleCountLabel(bucket.sampleCount)),
                      trailing: Text(
                        _formatSignedDuration(bucket.averageOvertime),
                        style: TextStyle(
                          color: bucket.averageOvertime.isNegative
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Überschrift einer Insights-Sektion mit Info-Icon, das per Tooltip erklärt,
/// was die Zahlen darunter bedeuten und wie sie zustande kommen (siehe #259 -
/// Insights waren bisher ohne jede Erläuterung).
class _InsightSectionHeader extends StatelessWidget {
  final String title;
  final String explanation;

  const _InsightSectionHeader({required this.title, required this.explanation});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(width: 4),
        Tooltip(
          message: explanation,
          triggerMode: TooltipTriggerMode.tap,
          showDuration: const Duration(seconds: 8),
          child: Icon(Icons.info_outline,
              size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Calendar extends ConsumerStatefulWidget {
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
  });

  @override
  ConsumerState<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends ConsumerState<_Calendar> {
  DateTime? _dragStartDate; // Tracks where drag started
  DateTime? _dragEndDate;   // Tracks current drag position
  bool _isDragging = false;
  final GlobalKey _gridKey = GlobalKey();

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int _getFirstDayOffset(int year, int month) {
    int weekday = DateTime(year, month, 1).weekday;
    return weekday - 1;
  }

  /// Prüft, ob ein bestimmtes Datum ein konfigurierter Arbeitstag ist.
  /// Wochentag: 1 = Montag, 7 = Sonntag (siehe #217).
  bool _isWorkday(DateTime date, List<int> workdays) {
    return workdays.contains(date.weekday);
  }

  void _selectDateRange(DateTime startDate, DateTime endDate, List<int> workdays) {
    final reportsNotifier = ref.read(reportsViewModelProvider.notifier);

    // Normalize dates
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    // Ensure start is before end
    final minDate = start.isBefore(end) ? start : end;
    final maxDate = start.isBefore(end) ? end : start;

    // Clear previous selection and select all dates in range
    reportsNotifier.clearDateSelection();

    DateTime currentDate = minDate;
    while (!currentDate.isAfter(maxDate)) {
      if (_isWorkday(currentDate, workdays)) {
        reportsNotifier.addDateToSelection(currentDate);
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }
  }

  /// Berechnet das Datum anhand einer globalen Bildschirm-Position innerhalb des Kalender-Grids.
  DateTime? _getDateFromGlobalPosition(Offset globalPosition) {
    final RenderBox? renderBox =
        _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final localPosition = renderBox.globalToLocal(globalPosition);
    final gridSize = renderBox.size;

    // Außerhalb des Grids → kein Datum
    if (localPosition.dx < 0 ||
        localPosition.dy < 0 ||
        localPosition.dx > gridSize.width ||
        localPosition.dy > gridSize.height) {
      return null;
    }

    // crossAxisCount: 7, childAspectRatio: 1.0 → quadratische Zellen
    final cellWidth = gridSize.width / 7;
    final col = (localPosition.dx / cellWidth).floor().clamp(0, 6);
    final row = (localPosition.dy / cellWidth).floor();

    final gridIndex = row * 7 + col;
    final firstDayOffset = _getFirstDayOffset(
      widget.selectedDate.year,
      widget.selectedDate.month,
    );

    if (gridIndex < firstDayOffset) return null;

    final day = gridIndex - firstDayOffset + 1;
    final daysInMonth = _getDaysInMonth(
      widget.selectedDate.year,
      widget.selectedDate.month,
    );

    if (day < 1 || day > daysInMonth) return null;

    return DateTime(widget.selectedDate.year, widget.selectedDate.month, day);
  }

  void _startDragAt(Offset globalPosition, List<int> workdays) {
    final date = _getDateFromGlobalPosition(globalPosition);
    if (date == null || !_isWorkday(date, workdays)) return;

    final reportsNotifier = ref.read(reportsViewModelProvider.notifier);
    setState(() {
      _dragStartDate = date;
      _dragEndDate = date;
      _isDragging = true;
    });
    reportsNotifier.clearDateSelection();
    reportsNotifier.addDateToSelection(date);
  }

  void _updateDragAt(Offset globalPosition, List<int> workdays) {
    if (!_isDragging || _dragStartDate == null) return;
    final date = _getDateFromGlobalPosition(globalPosition);
    if (date == null) return;
    if (!DateUtils.isSameDay(date, _dragEndDate)) {
      setState(() => _dragEndDate = date);
      _selectDateRange(_dragStartDate!, date, workdays);
    }
  }

  void _endDrag(List<int> workdays) {
    if (_dragStartDate != null && _dragEndDate != null) {
      _selectDateRange(_dragStartDate!, _dragEndDate!, workdays);
    }
    setState(() {
      _dragStartDate = null;
      _dragEndDate = null;
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportsState = ref.watch(reportsViewModelProvider);
    final reportsNotifier = ref.read(reportsViewModelProvider.notifier);
    final settingsState = ref.watch(settingsViewModelProvider);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    // Hole die konfigurierten Arbeitstage aus den Settings (default Mo-Fr)
    final workdays =
        settingsState.whenData((s) => s.settings.workdays).value ?? const [1, 2, 3, 4, 5];

    // Feiertage des angezeigten Monats/Jahres für das gewählte Bundesland (#222).
    // Rein visuelle Markierung - es werden keine WorkEntryType.holiday-Einträge erzeugt.
    // Namen zusätzlich zur Datumsmarkierung, damit im Kalender ersichtlich ist,
    // um welchen Feiertag es sich handelt (siehe #253).
    final bundesland = settingsState.whenData((s) => s.settings.bundesland).value;
    final Map<DateTime, String> holidayNames = bundesland != null
        ? getGermanHolidayNames(widget.selectedDate.year, bundesland)
        : const <DateTime, String>{};
    final Set<DateTime> holidays = holidayNames.keys.toSet();

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
                  onPressed: widget.onPreviousMonthTapped,
                  tooltip: l10n.previousMonthTooltip,
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM(locale).format(widget.selectedDate),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: widget.onNextMonthTapped,
                  tooltip: l10n.nextMonthTooltip,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Range Selection Hint
            if (reportsState.selectedDates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.selectedDaysCount(reportsState.selectedDates.length),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => reportsNotifier.clearDateSelection(),
                      child: Text(l10n.resetAction),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  l10n.dragSelectHint,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            Row(
              children: List.generate(7, (index) {
                final day = DateFormat.E(locale).format(DateTime(2023, 1, 2 + index));
                final fullDay = DateFormat.EEEE(locale).format(DateTime(2023, 1, 2 + index));
                return Expanded(
                  child: Semantics(
                    label: fullDay,
                    excludeSemantics: true,
                    child: Center(
                      child: Text(day),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            // Grid-level Gesture-Handling für Mehrfachauswahl per Drag.
            // Mobile: Long-Press + Ziehen → onLongPressStart/MoveUpdate/End
            // Web/Desktop: Mausklick + Ziehen → Listener.onPointerDown/Move/Up
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPressStart: (details) {
                if (!_isDragging) {
                  _startDragAt(details.globalPosition, workdays);
                }
              },
              onLongPressMoveUpdate: (details) {
                _updateDragAt(details.globalPosition, workdays);
              },
              onLongPressEnd: (_) => _endDrag(workdays),
              onLongPressCancel: () => _endDrag(workdays),
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  // Nur für Maus: Drag sofort starten (kein Long-Press nötig)
                  if (event.kind == PointerDeviceKind.mouse && event.buttons == 1) {
                    _startDragAt(event.position, workdays);
                  }
                },
                onPointerMove: (event) {
                  if (event.kind == PointerDeviceKind.mouse && _isDragging) {
                    _updateDragAt(event.position, workdays);
                  }
                },
                onPointerUp: (event) {
                  if (event.kind == PointerDeviceKind.mouse && _isDragging) {
                    _endDrag(workdays);
                  }
                },
                child: GridView.builder(
                  key: _gridKey,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7),
                  itemCount:
                      _getDaysInMonth(widget.selectedDate.year, widget.selectedDate.month) +
                          _getFirstDayOffset(widget.selectedDate.year, widget.selectedDate.month),
                  itemBuilder: (context, index) {
                    final firstDayOffset =
                        _getFirstDayOffset(widget.selectedDate.year, widget.selectedDate.month);
                    if (index < firstDayOffset) {
                      return const SizedBox.shrink();
                    }

                    final day = index - firstDayOffset + 1;
                    final date =
                        DateTime(widget.selectedDate.year, widget.selectedDate.month, day);
                    final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
                    final isMultiSelected = reportsState.selectedDates
                        .contains(DateTime(date.year, date.month, date.day));
                    final hasEntry = widget.daysWithEntries?.contains(day) ?? false;
                    final isWorkday = _isWorkday(date, workdays);
                    final isHoliday = holidays.contains(DateTime(date.year, date.month, date.day));
                    final holidayName = holidayNames[DateTime(date.year, date.month, date.day)];

                    Widget dayWidget = Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: isSelected || isMultiSelected
                              ? Colors.white
                              : (isHoliday
                                  ? Colors.red
                                  : (isWorkday ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey)),
                          fontWeight: isHoliday ? FontWeight.bold : null,
                        ),
                      ),
                    );

                    // Name des Feiertags per Tooltip (Long-Press/Hover) sichtbar
                    // machen - vorher war nur die rote Markierung ohne
                    // Erklärung, welcher Feiertag es ist (siehe #253).
                    if (holidayName != null) {
                      dayWidget = Tooltip(
                        message: holidayName,
                        child: dayWidget,
                      );
                    }

                    if (hasEntry) {
                      dayWidget = Stack(
                        alignment: Alignment.center,
                        children: [
                          dayWidget,
                          Positioned(
                            bottom: 4,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected || isMultiSelected
                                    ? Colors.white70
                                    : Theme.of(context).colorScheme.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final semanticLabel =
                        '${DateFormat('EEEE, d. MMMM yyyy', locale).format(date)}${holidayName != null ? l10n.holidaySemanticSuffix(holidayName) : ''}';
                    return Semantics(
                      label: semanticLabel,
                      button: true,
                      selected: isSelected || isMultiSelected,
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => widget.onDateSelected(date),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isMultiSelected
                                ? Theme.of(context).colorScheme.secondary
                                : isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.transparent,
                            shape: BoxShape.circle,
                            border: isMultiSelected
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: dayWidget,
                        ),
                      ),
                    );
                  },
                ),
              ),
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

class _DayEntriesBottomSheetState extends ConsumerState<DayEntriesBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final currentSelectedDayInViewModel =
            ref.read(reportsViewModelProvider).selectedDay;
        if (currentSelectedDayInViewModel == null ||
            !DateUtils.isSameDay(currentSelectedDayInViewModel, widget.date)) {
          ref.read(reportsViewModelProvider.notifier).selectDate(widget.date);
        }
      }
    });
  }

  void _openEdit(WorkEntryEntity entry) {
    final entryWithCalculatedBreaks = ref
        .read(reportsViewModelProvider.notifier)
        .applyBreakCalculation(entry);

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

  Future<void> _confirmDelete(BuildContext btmSheetItemContext, WidgetRef ref,
      WorkEntryEntity entry) async {
    final l10n = AppLocalizations.of(btmSheetItemContext);
    final bool? confirmed = await showDialog<bool>(
      context: btmSheetItemContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.deleteEntryTitle),
          content: Text(l10n.deleteEntryConfirm),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () {
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop(false);
                }
              },
            ),
            TextButton(
              child: Text(l10n.deleteAction),
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
      await ref
          .read(reportsViewModelProvider.notifier)
          .deleteWorkEntry(entry.id);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsState = ref.watch(reportsViewModelProvider);
    final use24HourFormat =
        ref.watch(settingsViewModelProvider).value?.settings.use24HourFormat ?? true;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    if (reportsState.isLoading &&
        (reportsState.selectedDay == null ||
            !DateUtils.isSameDay(reportsState.selectedDay, widget.date))) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: LoadingIndicator()),
      );
    }

    final List<WorkEntryEntity> entriesForSheetDate = reportsState
        .dailyReportState.entries
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
                  l10n.entriesForDayTitle(DateFormat.yMMMMd(locale).format(widget.date)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (entriesForSheetDate.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.noEntriesForDay),
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 280,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      final newEntry = WorkEntryEntity(
                                        id: DateFormat('yyyy-MM-dd')
                                            .format(widget.date),
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
                                    icon: const Icon(Icons.add),
                                    label: Text(l10n.addEntryAction),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: 280,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _handleQuickEntry(
                                        context, ref, widget.date),
                                    icon: const Icon(Icons.flash_on),
                                    label: Text(l10n.quickEntryButton),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

                        final isSpecialType =
                            displayEntry.type != WorkEntryType.work;

                        final DateTime? start = displayEntry.workStart;
                        final DateTime? end =
                            displayEntry.workEnd ?? nowToMinute();
                        Duration worked = Duration.zero;

                        if (start != null && end != null) {
                          Duration breakDur = Duration.zero;
                          for (final b in displayEntry.breaks) {
                            final DateTime bStart = b.start;
                            final DateTime bEnd = b.end ?? end;
                            final DateTime effStart =
                                bStart.isBefore(start) ? start : bStart;
                            final DateTime effEnd = bEnd.isAfter(end) ? end : bEnd;
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
                            title: Text(isSpecialType
                                ? _getWorkEntryTypeLabel(l10n, displayEntry.type)
                                : l10n.workTimeLabel(worked.toString().split('.').first)),
                            subtitle: (isSpecialType &&
                                    displayEntry.workStart == null &&
                                    displayEntry.workEnd == null)
                                ? null
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(l10n.startValueLabel(start != null ? formatTime(start, use24HourFormat: use24HourFormat) : '-')),
                                      Text(l10n.endValueLabel(displayEntry.workEnd != null ? formatTime(displayEntry.workEnd!, use24HourFormat: use24HourFormat) : (isSpecialType ? '-' : l10n.breakInProgress))),
                                      if (!isSpecialType)
                                        Text(l10n.breakValueLabel(displayEntry.totalBreakDuration.toString().split('.').first)),
                                      if (displayEntry.manualOvertime != null)
                                        Text(l10n.manualAdjustmentLabel(displayEntry.manualOvertime.toString().split('.').first)),
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
                                  icon: Icon(Icons.delete,
                                      color: Colors.red.shade700),
                                  onPressed: () =>
                                      _confirmDelete(ctx, ref, entry),
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

Future<void> _handleQuickEntry(
    BuildContext context, WidgetRef ref, DateTime date) async {
  final settingsState = ref.read(settingsViewModelProvider).asData?.value;
  Duration? dailyTarget;

  if (settingsState != null) {
    dailyTarget = Duration(
      minutes: ((settingsState.settings.weeklyTargetHours /
                  settingsState.settings.workdays.length) *
              60)
          .round(),
    );
  }

  final WorkEntryEntity? newEntry = await showDialog<WorkEntryEntity>(
    context: context,
    builder: (BuildContext context) {
      return QuickEntryDialog(
        date: date,
        dailyTarget: dailyTarget,
      );
    },
  );

  if (newEntry != null) {
    await ref.read(reportsViewModelProvider.notifier).saveWorkEntry(newEntry);
  }
}

String _getWorkEntryTypeLabel(AppLocalizations l10n, WorkEntryType type) {
  switch (type) {
    case WorkEntryType.vacation:
      return l10n.workEntryTypeVacationPlain;
    case WorkEntryType.sick:
      return l10n.workEntryTypeSickPlain;
    case WorkEntryType.holiday:
      return l10n.workEntryTypeHolidayPlain;
    case WorkEntryType.work:
      return l10n.workEntryTypeWorkPlain;
  }
}

Future<void> _handleBatchQuickEntry(
  BuildContext context,
  WidgetRef ref,
  ReportsState reportsState,
  ReportsViewModel reportsNotifier,
) async {
  final settingsState = ref.read(settingsViewModelProvider).asData?.value;
  Duration? dailyTarget;
  if (settingsState != null) {
    dailyTarget = Duration(
      minutes: ((settingsState.settings.weeklyTargetHours /
                  settingsState.settings.workdays.length) *
              60)
          .round(),
    );
  }

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (BuildContext dialogContext) {
      return BatchQuickEntryDialog(
        dates: List<DateTime>.from(reportsState.selectedDates)..sort(),
        dailyTarget: dailyTarget,
      );
    },
  );

  if (result != null) {
    final count = reportsState.selectedDates.length;
    await reportsNotifier.saveBatchWorkEntries(
      List<DateTime>.from(reportsState.selectedDates),
      result['type'] as WorkEntryType,
      result['startTime'] as TimeOfDay?,
      result['endTime'] as TimeOfDay?,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).batchEntriesCreated(count)),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Platzhalter-Widgets für den Blur-Effekt (nicht-Premium-Nutzer)
// ---------------------------------------------------------------------------

class _WeeklyReportPlaceholder extends StatelessWidget {
  const _WeeklyReportPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Navigations-Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.chevron_left),
              Column(
                children: [
                  Text(
                    AppLocalizations.of(context).weeklyReportTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Container(
                    width: 160,
                    height: 14,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 16),
          // Summary-Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 120,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Tages-Einträge
          ...List.generate(
            4,
            (i) => Card(
              child: ListTile(
                title: Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                trailing: Container(
                  width: 48,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyReportPlaceholder extends StatelessWidget {
  const _MonthlyReportPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Navigations-Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.chevron_left),
              Column(
                children: [
                  Text(
                    AppLocalizations.of(context).monthlyReportTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Container(
                    width: 140,
                    height: 14,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 16),
          // Summary-Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(
                  5,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 130,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Tages-Einträge
          ...List.generate(
            4,
            (i) => Card(
              child: ListTile(
                title: Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                trailing: Container(
                  width: 48,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
