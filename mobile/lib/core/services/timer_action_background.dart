import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/utils/timer_action.dart';
import '../utils/logger.dart';
import 'headless_timer_action.dart';
import 'timer_action_inbox.dart';

/// Name des Ports, unter dem die laufende App (Main-Isolate) Timer-Aktionen
/// aus dem Hintergrund-Isolate entgegennimmt (#485).
const String timerActionPortName = 'app.work_time_manager/timer_action';

/// SharedPreferences-Schlüssel einer aufgeschobenen Timer-Aktion (App-Sperre
/// aktiv): `<aktions-id>|<Epoch-ms>`.
const String pendingTimerActionKey = 'pending_timer_action';

/// Gültigkeit einer aufgeschobenen Aktion. Länger als die Inbox-TTL (2 Minuten),
/// weil der Nutzer erst die Benachrichtigung „App entsperren“ bemerken muss.
const Duration pendingTimerActionTtl = Duration(minutes: 5);

/// Was mit einer Notification-Aktion im Hintergrund geschah.
enum TimerActionDispatch {
  /// Unbekannte oder leere Aktion: nichts getan.
  ignored,

  /// An die laufende App (Main-Isolate) weitergereicht; sie führt sie aus.
  forwarded,

  /// Ohne laufende App im Hintergrund-Isolate ausgeführt.
  headless,

  /// App-Sperre aktiv: Aktion gemerkt, Nutzer wird zum Entsperren gebeten.
  deferred,
}

/// Entscheidet für eine Notification-Aktion, die ohne geöffnete App ankommt
/// (`showsUserInterface: false`), wer sie ausführt (#485).
///
/// Läuft die App (Port registriert), führt sie die Aktion selbst aus: eine
/// zweite Instanz des Dashboards im Hintergrund würde mit deren Autosave
/// kollidieren. Sonst läuft sie im Hintergrund-Isolate ([runHeadless]).
class TimerActionDispatcher {
  TimerActionDispatcher({
    SendPort? Function()? lookupPort,
    Future<TimerActionDispatch> Function(TimerAction action)? runHeadless,
  })  : _lookupPort = lookupPort ??
            (() => IsolateNameServer.lookupPortByName(timerActionPortName)),
        _runHeadless = runHeadless ?? runHeadlessTimerAction;

  final SendPort? Function() _lookupPort;
  final Future<TimerActionDispatch> Function(TimerAction action) _runHeadless;

  Future<TimerActionDispatch> dispatch(String? actionId) async {
    final action = timerActionFromId(actionId);
    if (action == null) {
      logger.w('[TimerAction] Unbekannte Hintergrund-Aktion ignoriert');
      return TimerActionDispatch.ignored;
    }
    final port = _lookupPort();
    if (port != null) {
      port.send(timerActionId(action));
      return TimerActionDispatch.forwarded;
    }
    try {
      return await _runHeadless(action);
    } catch (e, st) {
      logger.e(
          '[TimerAction] Hintergrund-Aktion fehlgeschlagen (${e.runtimeType})',
          stackTrace: st);
      return TimerActionDispatch.ignored;
    }
  }
}

/// Einstieg für Notification-Aktionen ohne geöffnete App. Läuft in einem
/// eigenen Isolate, das das Plugin startet; muss deshalb top-level sein.
@pragma('vm:entry-point')
Future<void> timerActionBackgroundHandler(NotificationResponse response) async {
  await TimerActionDispatcher().dispatch(response.actionId);
}

/// Registriert in der laufenden App den Port, über den das Hintergrund-Isolate
/// Aktionen übergibt, und legt sie in den Briefkasten. Liefert den Port zum
/// Schließen (Tests).
ReceivePort registerTimerActionPort(TimerActionInbox inbox) {
  final port = ReceivePort();
  IsolateNameServer.removePortNameMapping(timerActionPortName);
  IsolateNameServer.registerPortWithName(port.sendPort, timerActionPortName);
  port.listen((message) {
    if (message is! String) return;
    final action = timerActionFromId(message);
    if (action != null) inbox.push(action);
  });
  return port;
}

/// Merkt [action] für den nächsten App-Start (App-Sperre aktiv).
Future<void> storePendingTimerAction(
  SharedPreferences prefs,
  TimerAction action,
  DateTime now,
) =>
    prefs.setString(pendingTimerActionKey,
        '${timerActionId(action)}|${now.millisecondsSinceEpoch}');

/// Liefert eine gemerkte, noch gültige Aktion genau einmal und löscht den
/// Eintrag (auch einen verfallenen oder unlesbaren).
TimerAction? takePendingTimerAction(SharedPreferences prefs, DateTime now) {
  final raw = prefs.getString(pendingTimerActionKey);
  if (raw == null) return null;
  unawaited(prefs.remove(pendingTimerActionKey));
  final parts = raw.split('|');
  if (parts.length != 2) return null;
  final action = timerActionFromId(parts[0]);
  final at = int.tryParse(parts[1]);
  if (action == null || at == null) return null;
  final age = now.difference(DateTime.fromMillisecondsSinceEpoch(at));
  if (age.isNegative || age > pendingTimerActionTtl) return null;
  return action;
}
