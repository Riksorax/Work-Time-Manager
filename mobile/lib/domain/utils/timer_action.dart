/// Timer-Aktionen von außerhalb der App (Notification-Buttons, App-Shortcuts,
/// #274): reine Entscheidung, ob eine Aktion auf den heutigen Eintrag passt.
/// Reine Dart-Funktionen, kein Riverpod, kein Plugin.
library;

import '../entities/work_entry_entity.dart';

/// Aktion, die von außen den Timer steuert.
enum TimerAction { start, stop }

/// Ergebnis der Entscheidung: anwenden oder (still) nichts tun.
enum TimerDecision { apply, notApplicable }

/// Ergebnis von `DashboardViewModel.performTimerAction`.
///
/// `applied`: die Aktion wurde ausgeführt (bzw. gespeichert). `notApplicable`:
/// der Zustand passte nicht (oder das Profil wechselte beim Warten), es wurde
/// nichts geschrieben. `failed`: nicht ladbar oder Speichern gescheitert.
enum TimerActionResult { applied, notApplicable, failed }

/// Notification-Action-Id bzw. Shortcut-Typ für [TimerAction.start].
const String timerStartActionId = 'timer_start';

/// Notification-Action-Id bzw. Shortcut-Typ für [TimerAction.stop].
const String timerStopActionId = 'timer_stop';

/// Id (Notification-Action / Shortcut-Typ) zu einer [TimerAction].
String timerActionId(TimerAction action) => switch (action) {
      TimerAction.start => timerStartActionId,
      TimerAction.stop => timerStopActionId,
    };

/// [TimerAction] zu einer Id; unbekannt, leer oder `null` ergibt `null`.
TimerAction? timerActionFromId(String? id) => switch (id) {
      timerStartActionId => TimerAction.start,
      timerStopActionId => TimerAction.stop,
      _ => null,
    };

/// Entscheidet zustandsbewusst und idempotent, ob [action] auf [entry] passt.
///
/// Start nur bei einem Arbeitstag ohne Start und Ende; Stop nur bei laufendem
/// Arbeits-Eintrag (Typ `work`, Start gesetzt, kein Ende). Alles andere
/// (laufend + Start, gestoppt, Urlaub/Krank/Feiertag) ist nicht anwendbar, damit
/// ein Tipp auf „Einstempeln“ bei laufendem Timer diesen nie stoppt.
TimerDecision decideTimerAction(TimerAction action, WorkEntryEntity entry) {
  final isWork = entry.type == WorkEntryType.work;
  final applies = switch (action) {
    TimerAction.start =>
      isWork && entry.workStart == null && entry.workEnd == null,
    TimerAction.stop =>
      isWork && entry.workStart != null && entry.workEnd == null,
  };
  return applies ? TimerDecision.apply : TimerDecision.notApplicable;
}
