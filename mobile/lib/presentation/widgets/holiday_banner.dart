import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../utils/holiday_name_localizer.dart';
import '../view_models/holiday_today_provider.dart';

/// Rein informativer Hinweis "Heute ist Feiertag: …" im Dashboard (siehe #279).
///
/// Zeigt nichts, wenn heute laut Bundesland kein Feiertag ist. Aktualisiert
/// sich über `todayProvider` bei Tageswechsel und beim Zurückkehren in die App
/// (#379). Der Abstand nach unten ist im Banner gekapselt,
/// damit ohne Feiertag nichts verschoben wird.
class HolidayBanner extends ConsumerWidget {
  const HolidayBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holiday = ref.watch(holidayTodayProvider);
    if (holiday == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final text = l10n.holidayTodayBanner(holiday.localizedName(l10n));
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: text,
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.celebration_outlined,
                    color: scheme.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
