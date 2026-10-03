import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/clock_provider.dart';
import '../../l10n/app_localizations.dart';
import '../utils/holiday_name_localizer.dart';
import '../view_models/holiday_today_provider.dart';

/// Rein informativer Hinweis "Heute ist Feiertag: …" im Dashboard (siehe #279).
///
/// Zeigt nichts, wenn heute laut Bundesland kein Feiertag ist. Aktualisiert
/// sich bei Tageswechsel (Timer bis zur nächsten lokalen Mitternacht) und beim
/// Zurückkehren in die App. Der Abstand nach unten ist im Banner gekapselt,
/// damit ohne Feiertag nichts verschoben wird.
class HolidayBanner extends ConsumerStatefulWidget {
  const HolidayBanner({super.key});

  @override
  ConsumerState<HolidayBanner> createState() => _HolidayBannerState();
}

class _HolidayBannerState extends ConsumerState<HolidayBanner>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(holidayTodayProvider);
      _scheduleMidnight();
    }
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = ref.read(clockProvider)();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    var delay = nextMidnight.difference(now);
    if (delay < const Duration(seconds: 1)) delay = const Duration(seconds: 1);
    _midnightTimer = Timer(delay, () {
      if (!mounted) return;
      ref.invalidate(holidayTodayProvider);
      _scheduleMidnight();
    });
  }

  @override
  Widget build(BuildContext context) {
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
