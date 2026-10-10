import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/domain/entities/work_entry_entity.dart';
import 'package:flutter_work_time/presentation/state/dashboard_state.dart';
import 'package:flutter_work_time/presentation/view_models/dashboard_view_model.dart';
import 'package:flutter_work_time/presentation/view_models/open_entry_view_model.dart';

import '../../support/dashboard_harness.dart';

/// Block B (#418), Banner fuer offene Eintraege: Der Tag eines Eintrags kommt
/// aus der Id. Fixtures sind **inkonsistent** (Id und `date` meinen
/// verschiedene Tage), zonenunabhaengig. Uhr: Mo 05.10.2026 12:00.
///
/// Das Dashboard wird durch ein Fake ersetzt, das einen festen Zustand
/// liefert und `resumePastEntry` protokolliert.
class _FakeDashboard extends DashboardViewModel {
  _FakeDashboard(this.entry);

  final WorkEntryEntity entry;
  static final List<WorkEntryEntity> resumed = [];

  @override
  DashboardState build() => DashboardState(
        workEntry: entry,
        elapsedTime: Duration.zero,
        totalOvertime: Duration.zero,
        dailyOvertime: Duration.zero,
      );

  @override
  Future<bool> resumePastEntry(WorkEntryEntity entry) async {
    resumed.add(entry);
    return true;
  }
}

final _monday = DateTime(2026, 10, 5, 12);

/// Heutiger leerer Eintrag laut Id, `date` aber am Vortag.
final _todayEmptyDashboardEntry =
    WorkEntryEntity(id: '2026-10-05', date: DateTime(2026, 10, 4));

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  OpenEntryState openState(Harness h) =>
      h.container.read(openEntryViewModelProvider);
  OpenEntryViewModel openVm(Harness h) =>
      h.container.read(openEntryViewModelProvider.notifier);

  void boot(Harness h) {
    h.boot();
    h.container.listen(openEntryViewModelProvider, (_, __) {});
    openVm(h);
    h.async.flushMicrotasks();
  }

  /// Offener Eintrag: Id [id], gespeichertes `date` [date].
  void seedOpen(Harness h, String id, DateTime date, DateTime start) {
    h.work.store[id] = WorkEntryEntity(id: id, date: date, workStart: start);
  }

  scenario(
      'Soll richtet sich nach dem Wochentag der Id (Montag, nicht Sonntag)',
      _monday, (h) {
    boot(h);
    final entry = WorkEntryEntity(
      id: '2026-10-05',
      date: DateTime(2026, 10, 4),
      workStart: DateTime(2026, 10, 5, 8),
    );
    expect(openVm(h).targetFor(entry), eightHours);
  }, overrides: [
    dashboardViewModelProvider
        .overrideWith(() => _FakeDashboard(_todayEmptyDashboardEntry)),
  ], profiles: true);

  scenario('"Später" speichert den Schluessel mit dem Tag der Id', _monday,
      (h) {
    boot(h);
    expect(openState(h).entries.map((e) => e.id), ['2026-10-02']);
    openVm(h).later();
    h.async.flushMicrotasks();
    expect(
        h.container.read(openEntryDismissedProvider), {'default|2026-10-02'});
    expect(openState(h).entries, isEmpty);
  }, setUp: (h) {
    seedOpen(h, '2026-10-02', DateTime(2026, 10, 1), DateTime(2026, 10, 2, 8));
  }, overrides: [
    dashboardViewModelProvider
        .overrideWith(() => _FakeDashboard(_todayEmptyDashboardEntry)),
  ], profiles: true);

  scenario(
      'Fortsetzen: heute gilt als leer, wenn die Id (nicht date) heute ist',
      _monday, (h) {
    _FakeDashboard.resumed.clear();
    boot(h);
    expect(openState(h).current?.id, '2026-10-04');
    expect(openState(h).canResume, isTrue);

    var result = false;
    h.act(() async => result = await openVm(h).resume());
    expect(result, isTrue);
    expect(_FakeDashboard.resumed.map((e) => e.id), ['2026-10-04']);
  }, setUp: (h) {
    // Sonntag 22:00 gestartet (14 h alt, fortsetzbar), date inkonsistent.
    seedOpen(h, '2026-10-04', DateTime(2026, 10, 3), DateTime(2026, 10, 4, 22));
  }, overrides: [
    dashboardViewModelProvider
        .overrideWith(() => _FakeDashboard(_todayEmptyDashboardEntry)),
  ], profiles: true);

  scenario('der im Dashboard laufende Eintrag (Tag laut Id) ist nie Kandidat',
      _monday, (h) {
    boot(h);
    expect(openState(h).entries, isEmpty);
  }, setUp: (h) {
    seedOpen(h, '2026-10-04', DateTime(2026, 10, 3), DateTime(2026, 10, 4, 22));
  }, overrides: [
    // Das Dashboard fuehrt dieselbe Sitzung mit korrektem date.
    dashboardViewModelProvider.overrideWith(() => _FakeDashboard(
          WorkEntryEntity(
            id: '2026-10-04',
            date: DateTime(2026, 10, 4),
            workStart: DateTime(2026, 10, 4, 22),
          ),
        )),
  ], profiles: true);
}
