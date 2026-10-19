import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/utils/timer_status.dart';
import '../../presentation/view_models/dashboard_view_model.dart';
import '../services/home_widget_gateway.dart';
import '../utils/logger.dart';
import 'app_lock_provider.dart';
import 'providers.dart';

part 'widget_sync_provider.g.dart';

/// Haelt das Android-Status-Widget (#276) aktuell: schreibt bei jeder
/// relevanten Aenderung des Dashboard-Zustands einen [TimerSnapshot] in das
/// Gateway. Das Widget wird nur von hier aktualisiert (kein Backend-Poll).
///
/// - Der Ladezustand wird nie geschrieben.
/// - Es wird nur geschrieben, wenn sich der Snapshot aendert (Status, Start,
///   Pausenstart, Netto-Minute, Tag, Sperre), nicht jede Sekunde.
/// - Logout/Nutzerwechsel und Profilwechsel leeren den Snapshot sofort; der
///   neue Ladelauf des Dashboards schreibt danach den neuen Stand.
/// - Vor dem ersten Auth-Wert wird nichts geschrieben (die Repositories fallen
///   davor auf den lokalen Speicher zurueck); mit dem Wert wird neu gepusht.
/// - Ist die App-Sperre aktiviert (PIN eingerichtet und aktiv, nicht nur
///   gerade gesperrt), werden nie Zeiten geschrieben: nur Status und
///   `locked: true`. So bleiben auch bei beendetem Dart-Prozess keine Zeiten
///   im Klartext im Widget. Die Konfiguration wird bei jedem Push gelesen;
///   Aenderungen greifen spaetestens beim naechsten Push (z. B. Wechsel in den
///   Hintergrund, der die Sperre setzt).
@Riverpod(keepAlive: true)
void widgetSync(Ref ref) {
  final gateway = ref.watch(homeWidgetGatewayProvider);

  var disposed = false;
  Map<String, Object?>? lastWritten;
  TimerSnapshot? lastSnapshot;
  var queue = Future<void>.value();

  ref.onDispose(() => disposed = true);

  // Schreibvorgaenge laufen nacheinander, damit die Reihenfolge erhalten
  // bleibt. Nach dem Dispose wird nichts mehr geschrieben.
  void enqueue(Future<void> Function() task) {
    queue = queue.then((_) async {
      if (disposed) return;
      try {
        await task();
      } catch (e, st) {
        logger.e('[WidgetSync] Fehler (${e.runtimeType})', stackTrace: st);
      }
    });
  }

  void write(Map<String, Object?> data) {
    final comparable = widgetMapWithoutClock(data);
    if (mapEquals(lastWritten, comparable)) return;
    lastWritten = comparable;
    enqueue(() async {
      await gateway.saveData(data);
      await gateway.update();
    });
  }

  void clear() {
    lastSnapshot = null;
    final cleared = widgetMapWithoutClock(widgetClearedMap());
    if (mapEquals(lastWritten, cleared)) return;
    lastWritten = cleared;
    enqueue(gateway.clear);
  }

  void pushSnapshot() {
    final snapshot = lastSnapshot;
    if (snapshot == null) return;
    if (!ref.read(authStateProvider).hasValue) return;
    final service = ref.read(appLockServiceProvider);
    final lockActive =
        ref.read(isAppLockedProvider) || (service.isEnabled && service.hasPin);
    write(widgetSnapshotToMap(
      snapshot,
      locked: lockActive,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  // Mehrere State-Aenderungen in einem Mikrotask-Durchlauf (z. B. Ladelauf und
  // anschliessendes Sofort-Update des Timers) ergeben genau einen Write mit
  // dem letzten Stand, ohne kurzzeitig falsche Zwischenwerte im Widget.
  var pushScheduled = false;
  void schedulePush() {
    if (pushScheduled) return;
    pushScheduled = true;
    scheduleMicrotask(() {
      pushScheduled = false;
      if (disposed) return;
      pushSnapshot();
    });
  }

  ref.listen(dashboardViewModelProvider, (_, next) {
    if (next.isLoading) return;
    final net = next.actualWorkDuration ?? next.elapsedTime;
    final dailyOvertime = next.dailyOvertime;
    lastSnapshot = buildTimerSnapshot(
      entry: next.workEntry,
      net: net,
      // Tagessoll aus Netto und Tagessaldo (Saldo = Netto - Soll).
      target: dailyOvertime == null ? null : net - dailyOvertime,
      expectedEnd: next.expectedEndTime,
      totalOvertime: next.totalOvertime,
    );
    schedulePush();
  }, fireImmediately: true);

  ref.listen(isAppLockedProvider, (_, __) => schedulePush());

  // Nutzerwechsel: der erste bekannte Wert (App-Start) leert nichts.
  String? knownUserId;
  var userKnown = false;
  ref.listen(authStateProvider, (_, next) {
    final value = next.asData;
    if (value == null) return;
    final userId = value.value?.id;
    final changed = userKnown && userId != knownUserId;
    userKnown = true;
    knownUserId = userId;
    if (changed) clear();
    schedulePush();
  });

  ref.listen(activeWorkProfileIdProvider, (prev, next) {
    if (prev != next) clear();
  });
}
