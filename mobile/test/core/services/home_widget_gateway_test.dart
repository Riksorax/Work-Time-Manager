import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/services/home_widget_gateway.dart';
import 'package:flutter_work_time/domain/utils/timer_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('widgetSnapshotToMap', () {
    test('laufend: alle Schluessel, kein pauseStartMs', () {
      const s = TimerSnapshot(
        status: TimerStatus.running,
        dayKey: '2026-10-05',
        workStartMs: 1000,
        netMinutes: 95,
      );
      expect(widgetSnapshotToMap(s, locked: false, nowMs: 5000), {
        'status': 'running',
        'workStartMs': 1000,
        'pauseStartMs': null,
        'netMinutes': 95,
        'netAtMs': 5000,
        'dayKey': '2026-10-05',
        'locked': false,
      });
    });

    test('pausiert: pauseStartMs gesetzt', () {
      const s = TimerSnapshot(
        status: TimerStatus.paused,
        dayKey: '2026-10-05',
        workStartMs: 1000,
        pauseStartMs: 2000,
        netMinutes: 10,
      );
      final m = widgetSnapshotToMap(s, locked: false, nowMs: 5000);
      expect(m['status'], 'paused');
      expect(m['pauseStartMs'], 2000);
      expect(m['locked'], false);
    });

    test('locked: nur Status, Tag und locked, keine Zeiten', () {
      const s = TimerSnapshot(
        status: TimerStatus.paused,
        dayKey: '2026-10-05',
        workStartMs: 1000,
        pauseStartMs: 2000,
        netMinutes: 10,
      );
      expect(widgetSnapshotToMap(s, locked: true, nowMs: 5000), {
        'status': 'paused',
        'workStartMs': null,
        'pauseStartMs': null,
        'netMinutes': 0,
        'netAtMs': 5000,
        'dayKey': '2026-10-05',
        'locked': true,
      });
    });

    test('nicht gestartet und gestoppt', () {
      const n =
          TimerSnapshot(status: TimerStatus.notStarted, dayKey: '2026-10-05');
      expect(widgetSnapshotToMap(n, locked: false, nowMs: 5000)['status'],
          'notStarted');
      expect(widgetSnapshotToMap(n, locked: false, nowMs: 5000)['workStartMs'],
          isNull);
      const st = TimerSnapshot(
          status: TimerStatus.stopped,
          dayKey: '2026-10-05',
          workStartMs: 1,
          netMinutes: 480);
      expect(widgetSnapshotToMap(st, locked: false, nowMs: 5000)['status'],
          'stopped');
    });

    test('geleerter Snapshot hat Status none und dieselben Schluessel', () {
      final m = widgetClearedMap();
      expect(m['status'], 'none');
      expect(m['workStartMs'], isNull);
      expect(m['locked'], false);
      final running = widgetSnapshotToMap(
          const TimerSnapshot(status: TimerStatus.running, dayKey: 'x'),
          locked: false,
          nowMs: 5000);
      expect(m.keys, running.keys);
    });
  });

  group('PluginHomeWidgetGateway', () {
    const channel = MethodChannel('home_widget');
    late List<MethodCall> calls;
    Object? failWith;

    setUp(() {
      calls = [];
      failWith = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (failWith != null) throw failWith!;
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('saveData schreibt jeden Schluessel, update nennt die Provider-Klasse',
        () async {
      final gw = PluginHomeWidgetGateway();
      await gw.saveData({'status': 'running', 'netMinutes': 5});
      await gw.update();

      final saves = calls.where((c) => c.method == 'saveWidgetData').toList();
      expect(saves.map((c) => (c.arguments as Map)['id']),
          ['status', 'netMinutes']);
      final update = calls.singleWhere((c) => c.method == 'updateWidget');
      expect((update.arguments as Map)['qualifiedAndroidName'],
          statusWidgetAndroidProvider);
    });

    test('clear schreibt status none und aktualisiert', () async {
      await PluginHomeWidgetGateway().clear();

      final statusWrite = calls.firstWhere((c) =>
          c.method == 'saveWidgetData' &&
          (c.arguments as Map)['id'] == 'status');
      expect((statusWrite.arguments as Map)['data'], 'none');
      expect(calls.last.method, 'updateWidget');
    });

    test('Plugin-Fehler werden verschluckt', () async {
      failWith = PlatformException(code: 'boom');
      final gw = PluginHomeWidgetGateway();

      await gw.saveData({'status': 'running'});
      await gw.update();
      await gw.clear();
    });
  });
}
