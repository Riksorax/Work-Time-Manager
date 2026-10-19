import 'package:home_widget/home_widget.dart';

import '../../domain/utils/timer_status.dart';
import '../utils/logger.dart';

/// Qualifizierter Klassenname des Android-Widget-Providers (#276). Muss zu
/// `StatusWidgetProvider.kt` und dem `<receiver>` im Manifest passen.
const statusWidgetAndroidProvider =
    'app.work_time_manager.StatusWidgetProvider';

/// Schluessel des Snapshots (Dart -> Native). Muss zu `StatusWidgetProvider.kt`
/// passen.
const widgetKeyStatus = 'status';
const widgetKeyWorkStartMs = 'workStartMs';
const widgetKeyPauseStartMs = 'pauseStartMs';
const widgetKeyNetMinutes = 'netMinutes';

/// Zeitpunkt (Epoch-ms), zu dem `netMinutes` galt. Das Widget zaehlt davon aus
/// selbst weiter (Chronometer), auch wenn die App nicht laeuft.
const widgetKeyNetAtMs = 'netAtMs';
const widgetKeyTargetMinutes = 'targetMinutes';
const widgetKeyBreakMinutes = 'breakMinutes';
const widgetKeyExpectedEndMs = 'expectedEndMs';
const widgetKeyWorkEndMs = 'workEndMs';
const widgetKeyOvertimeMinutes = 'overtimeMinutes';
const widgetKeyDayKey = 'dayKey';
const widgetKeyLocked = 'locked';

/// Status `none` = Snapshot geleert (Logout/Profilwechsel).
const widgetStatusNone = 'none';

/// Serialisiert [snapshot] fuer das Widget. [nowMs] ist der Schreibzeitpunkt
/// (Basis des nativen Live-Timers). [locked] (App-Sperre aktiv) kommt
/// nicht aus dem Snapshot; `pauseStartMs` ist nur bei `paused` gesetzt.
///
/// Bei [locked] werden nie Zeiten geschrieben (nur Status, Tag und
/// `locked: true`): die Werte stuenden sonst im Klartext in den
/// Widget-Preferences, auch wenn der Dart-Prozess nicht mehr laeuft.
Map<String, Object?> widgetSnapshotToMap(
  TimerSnapshot snapshot, {
  required bool locked,
  required int nowMs,
}) =>
    {
      widgetKeyStatus: snapshot.status.name,
      widgetKeyWorkStartMs: locked ? null : snapshot.workStartMs,
      widgetKeyPauseStartMs: !locked && snapshot.status == TimerStatus.paused
          ? snapshot.pauseStartMs
          : null,
      widgetKeyNetMinutes: locked ? 0 : snapshot.netMinutes,
      widgetKeyNetAtMs: nowMs,
      widgetKeyTargetMinutes: locked ? null : snapshot.targetMinutes,
      widgetKeyBreakMinutes: locked ? 0 : snapshot.breakMinutes,
      widgetKeyExpectedEndMs: locked ? null : snapshot.expectedEndMs,
      widgetKeyWorkEndMs: locked ? null : snapshot.workEndMs,
      widgetKeyOvertimeMinutes: locked ? null : snapshot.overtimeMinutes,
      widgetKeyDayKey: snapshot.dayKey,
      widgetKeyLocked: locked,
    };

/// Geleerter Snapshot (Status `none`, keine Zeiten).
Map<String, Object?> widgetClearedMap() => {
      widgetKeyStatus: widgetStatusNone,
      widgetKeyWorkStartMs: null,
      widgetKeyPauseStartMs: null,
      widgetKeyNetMinutes: 0,
      widgetKeyNetAtMs: null,
      widgetKeyTargetMinutes: null,
      widgetKeyBreakMinutes: 0,
      widgetKeyExpectedEndMs: null,
      widgetKeyWorkEndMs: null,
      widgetKeyOvertimeMinutes: null,
      widgetKeyDayKey: null,
      widgetKeyLocked: false,
    };

/// Schmale Schnittstelle zum Home-Screen-Widget (testbar ohne Plugin).
/// Implementierungen duerfen nie werfen: ein Widget-Fehler darf die App nicht
/// beeintraechtigen.
abstract class HomeWidgetGateway {
  Future<void> saveData(Map<String, Object?> data);
  Future<void> update();
  Future<void> clear();
}

/// Ohne Widget-Unterstuetzung (Web, iOS, Desktop).
class NoopHomeWidgetGateway implements HomeWidgetGateway {
  const NoopHomeWidgetGateway();

  @override
  Future<void> saveData(Map<String, Object?> data) async {}

  @override
  Future<void> update() async {}

  @override
  Future<void> clear() async {}
}

class PluginHomeWidgetGateway implements HomeWidgetGateway {
  @override
  Future<void> saveData(Map<String, Object?> data) async {
    try {
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<Object>(e.key, e.value,
            deleteFile: false);
      }
    } catch (e, st) {
      logger.e('[HomeWidget] Schreiben fehlgeschlagen (${e.runtimeType})',
          stackTrace: st);
    }
  }

  @override
  Future<void> update() async {
    try {
      await HomeWidget.updateWidget(
          qualifiedAndroidName: statusWidgetAndroidProvider);
    } catch (e, st) {
      logger.e('[HomeWidget] Aktualisieren fehlgeschlagen (${e.runtimeType})',
          stackTrace: st);
    }
  }

  @override
  Future<void> clear() async {
    await saveData(widgetClearedMap());
    await update();
  }
}

/// Vergleichsbasis fuer das Entdoppeln von Writes: ohne den Schreibzeitpunkt,
/// der sich bei jedem Aufruf aendert.
Map<String, Object?> widgetMapWithoutClock(Map<String, Object?> data) =>
    {...data}..remove(widgetKeyNetAtMs);
