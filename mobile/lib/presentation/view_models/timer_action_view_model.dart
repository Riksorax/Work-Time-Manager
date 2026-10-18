import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:equatable/equatable.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/logger.dart';
import '../../domain/utils/timer_action.dart';
import 'dashboard_view_model.dart';

/// Ergebnis der zuletzt ausgeführten Timer-Aktion von außen (#274).
class TimerActionState extends Equatable {
  /// Ergebnis der letzten Aktion; `null`, solange keine ausgeführt wurde.
  final TimerActionResult? lastResult;

  /// Anzahl bisher ausgeführter Aktionen (unterscheidet gleiche Ergebnisse).
  final int handled;

  const TimerActionState({this.lastResult, this.handled = 0});

  @override
  List<Object?> get props => [lastResult, handled];
}

/// Es steht ein Fehlerhinweis (`dashboardSaveError`) für eine fehlgeschlagene
/// Timer-Aktion von außen an. Der `DashboardScreen` zeigt ihn und setzt ihn
/// zurück. Eigener, leichter Provider, damit der Screen das ViewModel nicht
/// instanziieren muss.
final timerActionFailurePendingProvider = StateProvider<bool>((ref) => false);

final timerActionViewModelProvider =
    NotifierProvider<TimerActionViewModel, TimerActionState>(
        TimerActionViewModel.new);

/// Führt Timer-Aktionen von außen (Notification-Buttons, App-Shortcuts, #274)
/// aus, sobald es sicher ist.
///
/// Wartet auf (1) den ersten Auth-Wert (sonst landen Daten eines eingeloggten
/// Nutzers im lokalen Speicher) und (2) die Entsperrung der App-Sperre (#223),
/// holt die Aktion dann aus der [TimerActionInbox] ab (verfällt nach 2 Minuten)
/// und ruft [DashboardViewModel.performTimerAction]. Jede Aktion wird genau
/// einmal konsumiert. Instanziiert das Dashboard-ViewModel nur, wenn eine
/// Aktion ansteht. `main.dart` hält das ViewModel per `ref.watch` am Leben.
class TimerActionViewModel extends Notifier<TimerActionState> {
  bool _draining = false;

  @override
  TimerActionState build() {
    final inbox = ref.watch(timerActionInboxProvider);
    final sub = inbox.pushes.listen((_) => unawaited(_drain()));
    ref.onDispose(sub.cancel);
    ref.listen<bool>(isAppLockedProvider, (_, __) => unawaited(_drain()));
    ref.listen(authStateProvider, (_, __) => unawaited(_drain()));
    // Kaltstart: die Aktion liegt schon im Puffer, bevor das ViewModel steht.
    scheduleMicrotask(() => unawaited(_drain()));
    return const TimerActionState();
  }

  bool _ready() =>
      !ref.read(isAppLockedProvider) && ref.read(authStateProvider).hasValue;

  Future<void> _drain() async {
    if (_draining || !ref.mounted) return;
    _draining = true;
    try {
      final inbox = ref.read(timerActionInboxProvider);
      while (ref.mounted && _ready() && inbox.hasPending) {
        // Einen Schleifendurchlauf warten: Repos und Dashboard-ViewModel bauen
        // sich nach dem ersten Auth-Wert bzw. Profilwechsel neu auf.
        await Future<void>.delayed(Duration.zero);
        if (!ref.mounted || !_ready()) break;
        final action = inbox.takePending();
        if (action == null) break;

        TimerActionResult result;
        try {
          result = await ref
              .read(dashboardViewModelProvider.notifier)
              .performTimerAction(action);
        } catch (e, st) {
          logger.e('[TimerAction] Aktion fehlgeschlagen (${e.runtimeType})',
              stackTrace: st);
          result = TimerActionResult.failed;
        }
        if (!ref.mounted) return;
        state =
            TimerActionState(lastResult: result, handled: state.handled + 1);
        if (result == TimerActionResult.failed) {
          ref.read(timerActionFailurePendingProvider.notifier).state = true;
        }
      }
    } finally {
      _draining = false;
    }
  }
}
