import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/utils/leave_balance_utils.dart';
import '../../l10n/app_localizations.dart';
import '../view_models/leave_balance_view_model.dart';

enum LeaveBalanceCardVariant {
  /// Nur Rest-Zeile (Dashboard).
  compact,

  /// Zusätzlich Fortschrittsbalken sowie Genommen/Anspruch/Kranktage
  /// (Einstellungen).
  detailed,
}

/// Free-Karte mit dem Resturlaub des laufenden Jahres (siehe #278).
class LeaveBalanceCard extends ConsumerWidget {
  final LeaveBalanceCardVariant variant;

  const LeaveBalanceCard({
    super.key,
    this.variant = LeaveBalanceCardVariant.detailed,
  });

  const LeaveBalanceCard.compact({super.key})
      : variant = LeaveBalanceCardVariant.compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(leaveBalanceViewModelProvider);
    final balance = state.balance;
    final detailed = variant == LeaveBalanceCardVariant.detailed;

    Widget content;
    if (state.hasError && balance == null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.leaveLoadError),
          TextButton(
            onPressed: () =>
                ref.read(leaveBalanceViewModelProvider.notifier).reload(),
            child: Text(l10n.leaveRetry),
          ),
        ],
      );
    } else if (balance == null) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      content = _buildData(context, l10n, balance, detailed, state.isLoading);
    }

    return Card(
      margin: detailed
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
          : EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.remainingVacationTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildData(BuildContext context, AppLocalizations l10n,
      LeaveBalance balance, bool detailed, bool isRefreshing) {
    final theme = Theme.of(context);
    final over = balance.remaining < 0;
    final hasEntitlement = balance.entitlement > 0;

    final String headline;
    if (!hasEntitlement && balance.taken == 0) {
      headline = l10n.vacationEntitlementZero;
    } else if (over) {
      headline = l10n.vacationOverEntitlement(-balance.remaining);
    } else {
      headline =
          l10n.remainingVacationOf(balance.remaining, balance.entitlement);
    }

    final progress = hasEntitlement
        ? (balance.taken / balance.entitlement).clamp(0.0, 1.0)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: over ? theme.colorScheme.error : null,
          ),
        ),
        if (detailed && progress != null) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            semanticsLabel: headline,
            color: over ? theme.colorScheme.error : null,
          ),
        ],
        if (detailed) ...[
          const SizedBox(height: 12),
          _row(context, l10n.vacationTakenLabel, '${balance.taken}'),
          _row(
              context, l10n.vacationEntitlementLabel, '${balance.entitlement}'),
          _row(context, l10n.sickDaysYearLabel(balance.year),
              '${balance.sickDays}'),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }
}
