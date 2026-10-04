import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/providers/providers.dart';

import '../../support/dashboard_harness.dart';
import '../../support/fake_repositories.dart';

void main() {
  // Sa 2026-10-03 09:00
  final start = DateTime(2026, 10, 3, 9);

  scenario('Suche folgt dem aktiven Profil (neue Instanz nach Wechsel)', start,
      (h) {
    final first = h.container.read(getOpenPastWorkEntriesUseCaseProvider);
    h.act(() => first());
    expect(h.work.monthReads, isNotEmpty);
    expect(h.workB.monthReads, isEmpty);

    h.switchProfile('b');
    final second = h.container.read(getOpenPastWorkEntriesUseCaseProvider);
    expect(identical(first, second), isFalse);
    h.act(() => second());
    expect(h.workB.monthReads, isNotEmpty);
  }, profiles: true);

  scenario('Beenden schreibt im Repo des aktiven Profils', start, (h) {
    final entry =
        entryOf(DateTime(2026, 10, 2), start: DateTime(2026, 10, 2, 8));
    h.work.store[dayKey(entry.date)] = entry;
    h.workB.store[dayKey(entry.date)] = entry;

    h.switchProfile('b');
    final uc = h.container.read(closeOpenWorkEntryUseCaseProvider);
    h.act(() => uc(
        entry: entry, end: DateTime(2026, 10, 2, 13), dailyTarget: eightHours));
    expect(h.writeLog, isNotEmpty);
    expect(h.writeLog.every((l) => l.startsWith('B:')), isTrue);
    expect(h.work.saved, isEmpty);
  }, profiles: true);
}
