import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/clock_provider.dart';
import '../../domain/utils/german_holidays.dart';
import 'settings_view_model.dart';

/// Der heutige gesetzliche Feiertag laut gewähltem Bundesland, sonst `null`
/// (siehe #279). Rein lesend; "heute" kommt aus [clockProvider] (lokale
/// Gerätezeit). Wird bei Tageswechsel/Resume vom Banner invalidiert.
final holidayTodayProvider = Provider<GermanHoliday?>((ref) {
  final bundesland = ref.watch(
      settingsViewModelProvider.select((s) => s.value?.settings.bundesland));
  if (bundesland == null) return null;
  final now = ref.watch(clockProvider)();
  return getGermanHolidayIds(
      now.year, bundesland)[DateTime(now.year, now.month, now.day)];
});
