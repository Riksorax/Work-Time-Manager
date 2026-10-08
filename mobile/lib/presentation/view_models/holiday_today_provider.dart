import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/today_provider.dart';
import '../../domain/utils/german_holidays.dart';
import 'settings_view_model.dart';

/// Der heutige gesetzliche Feiertag laut gewähltem Bundesland, sonst `null`
/// (siehe #279). Rein lesend; "heute" kommt aus [todayProvider] (lokaler Tag,
/// wechselt zur Mitternacht und bei Resume, siehe #379).
final holidayTodayProvider = Provider<GermanHoliday?>((ref) {
  final bundesland = ref.watch(
      settingsViewModelProvider.select((s) => s.value?.settings.bundesland));
  if (bundesland == null) return null;
  final today = ref.watch(todayProvider);
  return getGermanHolidayIds(today.year, bundesland)[today];
});
