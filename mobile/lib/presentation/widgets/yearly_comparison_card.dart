import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/yearly_comparison.dart';
import '../../l10n/app_localizations.dart';
import '../state/yearly_comparison_state.dart';
import '../utils/duration_hm.dart';
import '../view_models/yearly_comparison_view_model.dart';

/// Vergleichskarte „Vergleich {Jahr} mit {Vorjahr}“ im Jahres-Tab der
/// Berichte (#530, Premium). Alle Werte kommen fertig vom Backend, auch
/// Differenzen und Prozentwert; hier wird nur formatiert.
///
/// Das Anmelde-/Premium-Gate liegt beim Aufrufer (Jahres-Tab); dieses Widget
/// entsteht nur sichtbar und fordert dann das Laden an
/// ([YearlyComparisonViewModel.ensureLoaded]).
///
/// Darstellung wie die schmale Web-Ansicht: Spaltenköpfe Jahr, Vorjahr,
/// Differenz; je Kennzahl eine eigene Zeile über den drei Werten. Differenzen
/// neutral, nur über das Vorzeichen (0 ohne Vorzeichen), ohne Farbe.
class YearlyComparisonCard extends ConsumerWidget {
  const YearlyComparisonCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(yearlyComparisonViewModelProvider);
    if (state.status == YearlyComparisonStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(yearlyComparisonViewModelProvider.notifier).ensureLoaded();
        }
      });
    }
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(Icons.compare_arrows, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.yearCompareTitle(
                        '${state.year}',
                        '${state.year - 1}',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._content(context, ref, l10n, state),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    YearlyComparisonState state,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );
    switch (state.status) {
      case YearlyComparisonStatus.idle:
      case YearlyComparisonStatus.loading:
        return [
          SizedBox(
            height: 72,
            child: Center(
              child: Semantics(
                label: l10n.yearCompareLoading,
                child: const CircularProgressIndicator(),
              ),
            ),
          ),
        ];
      case YearlyComparisonStatus.unsupported:
        return [
          Text(l10n.yearCompareUnsupported('${state.year}'), style: muted),
        ];
      case YearlyComparisonStatus.error:
        return [
          Row(
            children: [
              Icon(Icons.error_outline, color: cs.error),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.yearCompareLoadError)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  ref.read(yearlyComparisonViewModelProvider.notifier).reload(),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retryButton),
            ),
          ),
        ];
      case YearlyComparisonStatus.data:
        final report = state.report;
        if (report == null) return const [];
        return _data(context, l10n, report);
    }
  }

  List<Widget> _data(
    BuildContext context,
    AppLocalizations l10n,
    YearlyComparison r,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final until = formatComparisonUntil(r.until, locale);

    final children = <Widget>[
      if (until != null) ...[
        Row(
          children: [
            Icon(Icons.event, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.yearCompareUntil(until),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    ];

    if (!r.current.hasData) {
      children.add(
        Text(l10n.yearCompareEmpty('${r.current.year}'), style: muted),
      );
      return children;
    }

    final rows = comparisonRows(r, l10n, locale);
    final headStyle = theme.textTheme.labelMedium?.copyWith(
      color: cs.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final numStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget three(Widget a, Widget b, Widget c) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 8),
            Expanded(child: b),
            const SizedBox(width: 8),
            Expanded(child: c),
          ],
        );
    Widget right(String text, TextStyle? style) =>
        Text(text, textAlign: TextAlign.right, style: style);

    children.add(
      ExcludeSemantics(
        child: three(
          right('${r.current.year}', headStyle),
          right('${r.previous.year}', headStyle),
          right(l10n.yearCompareDiff, headStyle),
        ),
      ),
    );
    children.add(const Divider(height: 16));

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final previousText = row.previous ?? l10n.yearCompareNoData;
      final diffText = row.diff == null
          ? l10n.yearCompareNoDiff
          : row.percent == null
              ? row.diff!
              : '${row.diff} (${row.percent})';
      children.add(
        Semantics(
          key: ValueKey('yearCompareRow-${row.key}'),
          container: true,
          label: '${row.label}: ${r.current.year} ${row.current}, '
              '${r.previous.year} $previousText, '
              '${l10n.yearCompareDiff} $diffText',
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    row.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  three(
                    right(row.current, numStyle),
                    row.previous != null
                        ? right(row.previous!, numStyle)
                        : right(
                            l10n.yearCompareNoData,
                            numStyle?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        right(row.diff ?? '–', numStyle),
                        if (row.percent != null)
                          right(
                            '(${row.percent})',
                            theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (i < rows.length - 1) children.add(const Divider(height: 16));
    }

    children.add(const SizedBox(height: 12));
    if (!r.previous.hasData) {
      children.add(
        Text(l10n.yearCompareNoPrevious('${r.previous.year}'), style: muted),
      );
      children.add(const SizedBox(height: 8));
    }
    children.add(
      Text(
        l10n.yearCompareNote,
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
    return children;
  }
}

/// Eine Zeile der Vergleichskarte, Werte bereits formatiert. [previous],
/// [diff] und [percent] fehlen, wenn das Vorjahr keine Daten hat; [percent]
/// gibt es nur bei der Arbeitszeit und nur, wenn das Backend ihn liefert.
class ComparisonRow {
  final String key;
  final String label;
  final String current;
  final String? previous;
  final String? diff;
  final String? percent;

  const ComparisonRow({
    required this.key,
    required this.label,
    required this.current,
    required this.previous,
    required this.diff,
    required this.percent,
  });
}

/// Baut die sechs Zeilen der Karte (reine Formatierung der Backend-Werte).
List<ComparisonRow> comparisonRows(
  YearlyComparison r,
  AppLocalizations l10n,
  String locale,
) {
  final prev = r.previous.hasData ? r.previous : null;
  final d = prev != null ? r.delta : null;
  final count = NumberFormat.decimalPattern(locale);
  String signedCount(int n) =>
      n == 0 ? count.format(0) : '${n > 0 ? '+' : '-'}${count.format(n.abs())}';
  String signedDuration(Duration v) =>
      v == Duration.zero ? formatDurationHm(v) : formatSignedDurationHm(v);
  String percent(double v) {
    final f = NumberFormat('0.0', locale);
    final abs = f.format(v.abs());
    // Gerundet 0,0 (z. B. -0.04) ohne Vorzeichen.
    final isZero = f.format(0) == abs;
    return '${isZero ? '' : v > 0 ? '+' : '-'}$abs %';
  }

  ComparisonRow days(
    String key,
    String label,
    int Function(YearlySummary) pick,
    int? delta,
  ) =>
      ComparisonRow(
        key: key,
        label: label,
        current: count.format(pick(r.current)),
        previous: prev != null ? count.format(pick(prev)) : null,
        diff: delta != null ? signedCount(delta) : null,
        percent: null,
      );

  return [
    ComparisonRow(
      key: 'worked',
      label: l10n.yearCompareWorked,
      current: formatDurationHm(r.current.totalWorked),
      previous: prev != null ? formatDurationHm(prev.totalWorked) : null,
      diff: d != null ? signedDuration(d.worked) : null,
      percent: d?.workedPercent != null ? percent(d!.workedPercent!) : null,
    ),
    ComparisonRow(
      key: 'overtime',
      label: l10n.yearCompareOvertime,
      current: formatSignedDurationHm(r.current.overtime),
      previous: prev != null ? formatSignedDurationHm(prev.overtime) : null,
      diff: d != null ? signedDuration(d.overtime) : null,
      percent: null,
    ),
    days('workDays', l10n.yearCompareWorkDays, (s) => s.workDays, d?.workDays),
    days(
      'vacationDays',
      l10n.yearCompareVacationDays,
      (s) => s.vacationDays,
      d?.vacationDays,
    ),
    days('sickDays', l10n.yearCompareSickDays, (s) => s.sickDays, d?.sickDays),
    days(
      'holidayDays',
      l10n.yearCompareHolidayDays,
      (s) => s.holidayDays,
      d?.holidayDays,
    ),
  ];
}

/// Stichtag `MM-dd` der Antwort als kurzes Datum in der App-Sprache
/// („15.11.“ bzw. „11/15“), sonst `null`. Reine Darstellung; kein Bezug zur
/// Uhr oder Zeitzone (2000 ist ein Schaltjahr, `02-29` bleibt gültig).
String? formatComparisonUntil(String? until, String locale) {
  final match =
      until == null ? null : RegExp(r'^(\d{2})-(\d{2})$').firstMatch(until);
  if (match == null) return null;
  final month = int.parse(match.group(1)!);
  final day = int.parse(match.group(2)!);
  final date = DateTime(2000, month, day);
  if (date.month != month || date.day != day) return null;
  return DateFormat.Md(locale).format(date);
}
