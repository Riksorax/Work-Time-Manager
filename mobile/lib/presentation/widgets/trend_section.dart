import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/trend_report.dart';
import '../../l10n/app_localizations.dart';
import '../state/trend_state.dart';
import '../utils/duration_hm.dart';
import '../view_models/trend_view_model.dart';
import 'charts/trend_charts.dart';

/// Trend-Abschnitt oben im Insights-Tab der Berichte (#531, Premium):
/// Umschalter 12 Wochen / 12 Monate, Kennzahl „Wochen-Trend“, Arbeitszeit je
/// Zeitraum als Balken mit Soll-Marke und aufsummierte Überstunden im Zeitraum
/// als Linie. Alle Werte kommen fertig vom Backend; hier wird nur beschriftet
/// und gezeichnet.
///
/// Das Anmelde-/Premium-Gate liegt beim Aufrufer (Insights-Tab); dieses Widget
/// entsteht nur sichtbar und fordert dann das Laden an
/// ([TrendViewModel.ensureLoaded]).
class TrendSection extends ConsumerWidget {
  const TrendSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(trendViewModelProvider);
    if (state.status == TrendStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(trendViewModelProvider.notifier).ensureLoaded();
        }
      });
    }
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(l10n.trendTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: l10n.trendExplanation,
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 8),
              child: Icon(Icons.info_outline,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: l10n.trendRangeLabel,
          container: true,
          child: SegmentedButton<TrendGranularity>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: TrendGranularity.week,
                  label: Text(l10n.trendRangeWeeks)),
              ButtonSegment(
                  value: TrendGranularity.month,
                  label: Text(l10n.trendRangeMonths)),
            ],
            selected: {state.granularity},
            onSelectionChanged: (s) => ref
                .read(trendViewModelProvider.notifier)
                .setGranularity(s.first),
          ),
        ),
        const SizedBox(height: 12),
        ..._content(context, ref, l10n, state),
      ],
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, TrendState state) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final report = state.report;
    switch (state.status) {
      case TrendStatus.idle:
      case TrendStatus.loading:
        return [
          Card(
            child: SizedBox(
              height: 140,
              child: Center(
                child: Semantics(
                  label: l10n.trendLoading,
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
          ),
        ];
      case TrendStatus.error:
        return [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: cs.error),
                  const SizedBox(height: 8),
                  Text(l10n.trendLoadError, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(trendViewModelProvider.notifier).reload(),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retryButton),
                  ),
                ],
              ),
            ),
          ),
        ];
      case TrendStatus.data:
        if (report == null || report.isEmpty) {
          return [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.insights, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(state.granularity == TrendGranularity.week
                          ? l10n.trendEmptyWeeks
                          : l10n.trendEmptyMonths),
                    ),
                  ],
                ),
              ),
            ),
          ];
        }
        return _data(context, l10n, report);
    }
  }

  List<Widget> _data(
      BuildContext context, AppLocalizations l10n, TrendReport report) {
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isWeek = report.granularity == TrendGranularity.week;

    String axisLabel(TrendBucket b) => isWeek
        ? l10n.trendWeekAxis(b.weekNumber ?? 0)
        : DateFormat.MMM(locale).format(b.start);
    String fullLabel(TrendBucket b) => isWeek
        ? '${axisLabel(b)} · ${DateFormat.MMMd(locale).format(b.start)} – '
            '${DateFormat.yMMMd(locale).format(b.end)}'
        : DateFormat.yMMMM(locale).format(b.start);

    final last = report.buckets.length - 1;
    List<ChartPoint> points(
            int Function(TrendBucket) value,
            int? Function(TrendBucket) reference,
            int? Function(TrendBucket) secondary) =>
        [
          for (var i = 0; i < report.buckets.length; i++)
            ChartPoint(
              key: report.buckets[i].key,
              axisLabel: axisLabel(report.buckets[i]),
              label: fullLabel(report.buckets[i]),
              valueMs: value(report.buckets[i]),
              referenceMs: reference(report.buckets[i]),
              secondaryMs: secondary(report.buckets[i]),
              hasData: report.buckets[i].hasData,
              partial: i == last,
            ),
        ];

    final first = report.buckets.first;
    final from = isWeek
        ? DateFormat.yMMMd(locale).format(first.start)
        : DateFormat.yMMMM(locale).format(first.start);

    final titleStyle =
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);
    final subStyle =
        theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final wt = report.weeklyTrend;

    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Semantics(
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.trendWeekTitle, style: titleStyle),
                const SizedBox(height: 6),
                if (wt != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        wt.delta > Duration.zero
                            ? Icons.trending_up
                            : wt.delta < Duration.zero
                                ? Icons.trending_down
                                : Icons.trending_flat,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.trendWeekDelta(formatSignedDurationHm(wt.delta),
                              wt.comparedWeeks),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.trendWeekDetail(
                      l10n.trendWeekAxis(wt.lastWeekNumber ?? 0),
                      formatDurationHm(wt.lastWeekWorked),
                      formatDurationHm(wt.averageWorked),
                    ),
                    style: subStyle,
                  ),
                ] else
                  Text(l10n.trendWeekTooLittle, style: subStyle),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  isWeek
                      ? l10n.trendWorkedTitleWeek
                      : l10n.trendWorkedTitleMonth,
                  style: titleStyle),
              const SizedBox(height: 12),
              TrendBarChart(
                points: points((b) => b.worked.inMilliseconds,
                    (b) => b.target.inMilliseconds, (_) => null),
                labels: ChartLabels(
                  title: isWeek
                      ? l10n.trendWorkedTitleWeek
                      : l10n.trendWorkedTitleMonth,
                  value: l10n.trendActual,
                  reference: l10n.trendTarget,
                  noData: l10n.trendNoData,
                  partial: l10n.trendPartial,
                ),
                formatValue: formatDurationHm,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.trendOvertimeTitle, style: titleStyle),
              const SizedBox(height: 2),
              Text(l10n.trendOvertimeHint(from), style: subStyle),
              const SizedBox(height: 12),
              TrendLineChart(
                points: points((b) => b.cumulativeOvertime.inMilliseconds,
                    (_) => null, (b) => b.overtime.inMilliseconds),
                labels: ChartLabels(
                  title: l10n.trendOvertimeTitle,
                  value: l10n.trendOvertimeSum,
                  secondary: isWeek
                      ? l10n.trendOvertimePerWeek
                      : l10n.trendOvertimePerMonth,
                  noData: l10n.trendNoData,
                  partial: l10n.trendPartial,
                ),
                formatValue: formatSignedDurationHm,
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
