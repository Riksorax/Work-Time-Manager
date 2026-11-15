import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart' as core_providers;
import '../../core/providers/subscription_provider.dart';
import '../../core/providers/today_provider.dart';
import '../../core/utils/api_errors.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/trend_report.dart';

/// Wochen-Trend für die Sprachabfrage „Wochen-Trend“ (#287, Teil B).
///
/// Dieselbe Quelle wie die Karte „Wochen-Trend“ der Trend-Ansicht (#531):
/// `weeklyTrend` aus `GET /api/reports/trend/{heute}?granularity=week` für das
/// aktive Arbeitszeit-Profil, „heute“ aus [todayProvider]. Die App rechnet
/// nichts und hat keinen Offline-Fallback. `null` = zu wenig Daten.
///
/// Nur das Antwort-Sheet beobachtet den Provider, und nur angemeldet mit
/// Premium (das Gate liegt im Sheet). Als Absicherung fragt er ohne
/// Anmeldung oder ohne Premium das Backend nicht an. `autoDispose`: Schließen
/// des Sheets verwirft das Ergebnis, eine neue Abfrage lädt frisch.
/// Login-, Premium-, Profil- und Tageswechsel laden neu.
///
/// Ladefehler werden geloggt (erwartbare Netzwerkfehler und Aufrufe ohne
/// angemeldeten Nutzer nur `logger.i`) und als Fehlerzustand weitergegeben;
/// ohne automatisches Wiederholen.
final assistantWeeklyTrendProvider =
    FutureProvider.autoDispose<WeeklyTrend?>((ref) async {
  final userId = ref.watch(
      core_providers.authStateProvider.select((a) => a.asData?.value?.id));
  final premium = ref.watch(isPremiumProvider);
  final profileId = ref.watch(core_providers.activeWorkProfileIdProvider);
  final today = ref.watch(todayProvider);
  if (userId == null || !premium) return null;
  try {
    final report = await ref
        .read(core_providers.apiClientProvider)
        .getTrendReport(today, TrendGranularity.week, profileId: profileId);
    return report.weeklyTrend;
  } catch (e, st) {
    if (e is NotSignedInException) {
      // Kurz nach dem Abmelden (#522): das Sheet zeigt gleich den
      // Anmelde-Hinweis.
      logger.i('[AssistantWeeklyTrend] Laden ohne angemeldeten Nutzer');
    } else if (isExpectedLoadFailure(e)) {
      logger.i(
          '[AssistantWeeklyTrend] Netzwerkfehler beim Laden: ${errorLabel(e)}');
    } else {
      logger.e('[AssistantWeeklyTrend] Fehler beim Laden: ${errorLabel(e)}',
          stackTrace: st);
    }
    rethrow;
  }
},
        // Kein automatisches Wiederholen (Riverpod 3 wiederholt sonst mit
        // Backoff): ein Fehler bleibt sichtbar, „Erneut versuchen“ lädt neu.
        retry: (_, __) => null);
