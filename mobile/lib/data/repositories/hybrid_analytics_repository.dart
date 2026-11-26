import '../../core/utils/timezone_utils.dart';
import '../../domain/entities/home_office_report.dart';
import '../../domain/entities/insights_report.dart';
import '../../domain/entities/work_entry_entity.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/work_repository.dart';
import '../../domain/utils/home_office_stats.dart';
import '../../domain/utils/insights_utils.dart';
import '../datasources/remote/api_client.dart';

/// Home-Office-Werte eines Monats für den Monats-Export (#282, #537).
typedef HomeOfficeMonth = ({HomeOfficeCounts counts, List<DateTime> dates});

/// Auswertungen Home-Office und Insights (#537), umgeschaltet wie die übrigen
/// Hybrid-Repositories nach dem Auth-Status:
///
/// - **Angemeldet** ([api] gesetzt): Werte vom Backend
///   (`GET /api/reports/home-office/{year}`, `GET /api/reports/insights/...`)
///   für das gebundene Profil; die App rechnet nichts nach und hat keinen
///   Offline-Ersatz. Fehler gehen unverändert an den Aufrufer.
/// - **Gast** ([api] `null`, dann sind [workRepository] und
///   [settingsRepository] Pflicht): lokale Rechnung über das Hybrid-Repository
///   (`calculateHomeOfficeStats`, `insights_utils.dart`), dieselben Regeln wie
///   das Backend (Paritätstests `*_parity_tz_test`).
///
/// Die Instanz ist an Nutzer und Profil gebunden; der Provider baut bei einem
/// Login- oder Profilwechsel eine neue.
class HybridAnalyticsRepository {
  HybridAnalyticsRepository({
    required ApiClient? api,
    WorkRepository? workRepository,
    SettingsRepository? settingsRepository,
    String? profileId,
    DeviceTimeZone timeZone = const DeviceTimeZone(),
  })  : _api = api,
        _work = workRepository,
        _settings = settingsRepository,
        _profileId = profileId,
        _timeZone = timeZone,
        assert(api != null ||
            (workRepository != null && settingsRepository != null));

  final ApiClient? _api;
  final WorkRepository? _work;
  final SettingsRepository? _settings;
  final String? _profileId;
  final DeviceTimeZone _timeZone;

  /// `true`, wenn die Werte vom Backend kommen.
  bool get usesBackend => _api != null;

  /// Home-Office-Auswertung des Jahres [year].
  Future<HomeOfficeReport> homeOfficeYear(int year) async {
    final api = _api;
    if (api != null) {
      return api.getHomeOfficeReport(year, profileId: _profileId);
    }
    final entriesPerMonth = await Future.wait([
      for (var m = 1; m <= 12; m++) _work!.getWorkEntriesForMonth(year, m),
    ]);
    return homeOfficeReportFromEntries(year, entriesPerMonth);
  }

  /// Home-Office-Werte des Monats [month] in [year]. Angemeldet aus der
  /// Jahresantwort (`months[]` und `homeOfficeDates` des Monats), als Gast aus
  /// den Einträgen dieses einen Monats.
  Future<HomeOfficeMonth> homeOfficeMonth(int year, int month) async {
    final api = _api;
    if (api != null) {
      final report = await api.getHomeOfficeReport(year, profileId: _profileId);
      return (counts: report.month(month), dates: report.datesInMonth(month));
    }
    final stats = calculateHomeOfficeStats(
        await _work!.getWorkEntriesForMonth(year, month));
    return (counts: stats.toCounts(), dates: stats.homeOfficeDates);
  }

  /// Insights der [insightsMonthCount] Monate bis zum Monat von [today]
  /// (lokaler Kalendertag).
  Future<InsightsReport> insights(DateTime today) async {
    final api = _api;
    if (api != null) {
      final zone = await _timeZone.ianaName();
      return api.getInsightsReport(today, zone, profileId: _profileId);
    }
    final months = List.generate(insightsMonthCount, (i) {
      final date = DateTime(today.year, today.month - i, 1);
      return (year: date.year, month: date.month);
    });
    final perMonth = await Future.wait<List<WorkEntryEntity>>(
      months.map((m) => _work!.getWorkEntriesForMonth(m.year, m.month)),
    );
    return calculateInsightsReport(
      entries: perMonth.expand((e) => e).toList(),
      today: today,
      workdays: _settings!.getWorkdays(),
      targetWeeklyHours: _settings!.getTargetWeeklyHours(),
    );
  }
}
