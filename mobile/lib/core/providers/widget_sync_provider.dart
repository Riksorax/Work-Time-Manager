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
/// - Bei aktiver App-Sperre traegt der Snapshot `locked`, die Zeiten blendet
///   die native Seite aus.
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
    if (mapEquals(lastWritten, data)) return;
    lastWritten = data;
    enqueue(() async {
      await gateway.saveData(data);
      await gateway.update();
    });
  }

  void clear() {
    lastSnapshot = null;
    final cleared = widgetClearedMap();
    if (mapEquals(lastWritten, cleared)) return;
    lastWritten = cleared;
    enqueue(gateway.clear);
  }

  void pushSnapshot() {
    final snapshot = lastSnapshot;
    if (snapshot == null) return;
    write(widgetSnapshotToMap(snapshot, locked: ref.read(isAppLockedProvider)));
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
    lastSnapshot = buildTimerSnapshot(
      entry: next.workEntry,
      net: next.actualWorkDuration ?? next.elapsedTime,
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
  });

  ref.listen(activeWorkProfileIdProvider, (prev, next) {
    if (prev != next) clear();
  });
}
