import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/services/shortcut_service.dart';
import 'package:flutter_work_time/domain/utils/timer_action.dart';
import 'package:flutter_work_time/l10n/app_localizations.dart';
import 'package:quick_actions/quick_actions.dart';

class _FakeQuickActions implements QuickActions {
  QuickActionHandler? handler;
  int initializeCalls = 0;
  final List<List<ShortcutItem>> setCalls = [];
  bool throwOnSet = false;

  @override
  Future<void> initialize(QuickActionHandler handler) async {
    initializeCalls++;
    this.handler = handler;
  }

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async {
    if (throwOnSet) throw Exception('plugin');
    setCalls.add(items);
  }

  @override
  Future<void> clearShortcutItems() async {}
}

void main() {
  final de = lookupAppLocalizations(const Locale('de'));
  final en = lookupAppLocalizations(const Locale('en'));

  late _FakeQuickActions fake;
  late ShortcutService service;
  late List<TimerAction> received;

  setUp(() {
    fake = _FakeQuickActions();
    service = ShortcutService(quickActions: fake, supported: true);
    received = [];
  });

  test('setShortcuts setzt zwei Items mit Typen und deutschen Labels',
      () async {
    await service.setShortcuts(de);

    final items = fake.setCalls.single;
    expect(items.map((i) => i.type), ['timer_start', 'timer_stop']);
    expect(items.map((i) => i.localizedTitle), ['Einstempeln', 'Ausstempeln']);
  });

  test('englische Labels aus AppLocalizations', () async {
    await service.setShortcuts(en);

    expect(fake.setCalls.single.map((i) => i.localizedTitle),
        ['Clock in', 'Clock out']);
  });

  test('erneuter Aufruf ersetzt die Items (Sprachwechsel)', () async {
    await service.setShortcuts(de);
    await service.setShortcuts(en);

    expect(fake.setCalls, hasLength(2));
    expect(fake.setCalls.last.first.localizedTitle, 'Clock in');
  });

  test('Callback mit bekanntem Typ liefert die TimerAction', () async {
    await service.initialize(received.add);

    fake.handler!('timer_start');
    fake.handler!('timer_stop');

    expect(received, [TimerAction.start, TimerAction.stop]);
  });

  test('unbekannter Typ wird ignoriert', () async {
    await service.initialize(received.add);

    fake.handler!('etwas_anderes');

    expect(received, isEmpty);
  });

  test('nicht unterstuetzte Plattform (Web/iOS): No-op', () async {
    final noop = ShortcutService(quickActions: fake, supported: false);

    await noop.initialize(received.add);
    await noop.setShortcuts(de);

    expect(fake.initializeCalls, 0);
    expect(fake.setCalls, isEmpty);
  });

  test('Plugin-Fehler beim Setzen wird geschluckt', () async {
    fake.throwOnSet = true;

    await service.setShortcuts(de);

    expect(fake.setCalls, isEmpty);
  });
}
