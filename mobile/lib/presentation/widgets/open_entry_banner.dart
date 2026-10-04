import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/clock_provider.dart';
import '../../core/utils/time_format.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/usecases/close_open_work_entry.dart';
import '../../l10n/app_localizations.dart';
import '../view_models/open_entry_view_model.dart';
import '../view_models/settings_view_model.dart';
import 'open_entry_end_dialog.dart';

/// Nicht-modaler Hinweis im Dashboard auf einen offenen Eintrag vor heute
/// (#385). Der Nutzer beendet ihn mit gewähltem Ende oder wählt "Später"
/// (blendet den Banner nur für diese Sitzung aus). Ohne Kandidaten rendert er
/// nichts; der Abstand nach unten ist im Banner gekapselt.
class OpenEntryBanner extends ConsumerWidget {
  const OpenEntryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(openEntryViewModelProvider);
    final entry = state.current;
    if (entry == null) return const SizedBox.shrink();

    final use24HourFormat =
        ref.watch(settingsViewModelProvider).value?.settings.use24HourFormat ??
            true;
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final date = DateFormat.MMMEd(locale).format(entry.date);
    final time = formatTime(entry.workStart!, use24HourFormat: use24HourFormat);
    final title = l10n.openEntryBannerTitle(date, time);
    final more =
        state.moreCount > 0 ? l10n.openEntryBannerMore(state.moreCount) : null;
    final onContainer = scheme.onSecondaryContainer;

    final endAction = state.busy
        ? null
        : () => _end(context, ref, entry, use24HourFormat: use24HourFormat);
    final laterAction = state.busy
        ? null
        : () => ref.read(openEntryViewModelProvider.notifier).later();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: more == null ? title : '$title $more',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.history_toggle_off, color: onContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleSmall
                                ?.copyWith(color: onContainer),
                          ),
                          if (more != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                more,
                                style: textTheme.bodySmall
                                    ?.copyWith(color: onContainer),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Semantics(
                    button: true,
                    enabled: laterAction != null,
                    excludeSemantics: true,
                    label: l10n.openEntryLaterSemantics(date),
                    onTap: laterAction,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: onContainer,
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: laterAction,
                      child: Text(l10n.openEntryLater),
                    ),
                  ),
                  Semantics(
                    button: true,
                    enabled: endAction != null,
                    excludeSemantics: true,
                    label: l10n.openEntryEndSemantics(date),
                    onTap: endAction,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: endAction,
                      child: Text(l10n.openEntryEnd),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _end(
    BuildContext context,
    WidgetRef ref,
    WorkEntryEntity entry, {
    required bool use24HourFormat,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorText = AppLocalizations.of(context).openEntrySaveError;
    final viewModel = ref.read(openEntryViewModelProvider.notifier);
    final now = ref.read(clockProvider)();

    final end = await showOpenEntryEndDialog(
      context,
      entry: entry,
      now: now,
      dailyTarget: viewModel.targetFor(entry),
      use24HourFormat: use24HourFormat,
    );
    if (end == null) return;

    final result = await viewModel.endEntry(end);
    if (result == CloseOpenEntryResult.failed ||
        result == CloseOpenEntryResult.invalidEnd ||
        result == CloseOpenEntryResult.invalidEntry) {
      messenger.showSnackBar(SnackBar(content: Text(errorText)));
    }
  }
}
