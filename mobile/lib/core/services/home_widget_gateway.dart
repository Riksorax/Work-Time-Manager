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
const widgetKeyDayKey = 'dayKey';
const widgetKeyLocked = 'locked';

/// Status `none` = Snapshot geleert (Logout/Profilwechsel).
const widgetStatusNone = 'none';

/// Serialisiert [snapshot] fuer das Widget. [locked] (App-Sperre) kommt nicht
/// aus dem Snapshot; `pauseStartMs` ist nur bei `paused` gesetzt.
Map<String, Object?> widgetSnapshotToMap(
  TimerSnapshot snapshot, {
  required bool locked,
}) =>
    {
      widgetKeyStatus: snapshot.status.name,
      widgetKeyWorkStartMs: snapshot.workStartMs,
      widgetKeyPauseStartMs:
          snapshot.status == TimerStatus.paused ? snapshot.pauseStartMs : null,
      widgetKeyNetMinutes: snapshot.netMinutes,
      widgetKeyDayKey: snapshot.dayKey,
      widgetKeyLocked: locked,
    };

/// Geleerter Snapshot (Status `none`, keine Zeiten).
Map<String, Object?> widgetClearedMap() => {
      widgetKeyStatus: widgetStatusNone,
      widgetKeyWorkStartMs: null,
      widgetKeyPauseStartMs: null,
      widgetKeyNetMinutes: 0,
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
