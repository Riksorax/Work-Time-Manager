import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/logger.dart';
import '../../domain/utils/assistant_query.dart';

/// Zustand der Sprachabfragen von außen (#287).
class AssistantQueryState extends Equatable {
  /// Zuletzt zugestellte Abfrage; `null`, solange keine zugestellt wurde.
  final AssistantQuery? lastQuery;

  /// Anzahl bisher zugestellter Abfragen (unterscheidet gleiche Abfragen).
  final int handled;

  const AssistantQueryState({this.lastQuery, this.handled = 0});

  @override
  List<Object?> get props => [lastQuery, handled];
}

/// Abfrage, deren Antwort der `DashboardScreen` als Bottom Sheet zeigen soll.
/// Der Screen öffnet das Sheet und setzt den Wert zurück. Eigener, leichter
/// Provider (Vorbild `timerActionFailurePendingProvider`), damit der Screen
/// das ViewModel nicht instanziieren muss.
final assistantQueryPendingProvider =
    StateProvider<AssistantQuery?>((ref) => null);

final assistantQueryViewModelProvider =
    NotifierProvider<AssistantQueryViewModel, AssistantQueryState>(
        AssistantQueryViewModel.new);

/// Stellt Sprachabfragen des Assistant (#287) zu, sobald es sicher ist.
///
/// Vorbild `TimerActionViewModel`, mit denselben Warte-Bedingungen: (1) der
/// erste Auth-Wert (sonst zeigt die Antwort kurz den Gast statt des
/// angemeldeten Nutzers) und (2) die Entsperrung der App-Sperre (#223; die
/// Antwort erscheint erst danach). Holt die Abfrage dann aus der
/// [AssistantQueryInbox] ab (verfällt nach 2 Minuten still) und legt sie in
/// [assistantQueryPendingProvider]. Jede Abfrage wird genau einmal
/// konsumiert.
///
/// Eine Abfrage verändert keine Daten: dieses ViewModel liest und schreibt
/// weder Einträge noch Saldo und ruft das Dashboard-ViewModel nicht auf.
/// `main.dart` hält das ViewModel per `ref.watch` am Leben.
class AssistantQueryViewModel extends Notifier<AssistantQueryState> {
  bool _draining = false;

  @override
  AssistantQueryState build() {
    final inbox = ref.watch(assistantQueryInboxProvider);
    final sub = inbox.pushes.listen((_) => unawaited(_drain()));
    ref.onDispose(sub.cancel);
    ref.listen<bool>(isAppLockedProvider, (_, __) => unawaited(_drain()));
    ref.listen(authStateProvider, (_, __) => unawaited(_drain()));
    // Kaltstart: die Abfrage liegt schon im Puffer, bevor das ViewModel steht.
    scheduleMicrotask(() => unawaited(_drain()));
    return const AssistantQueryState();
  }

  bool _ready() =>
      !ref.read(isAppLockedProvider) && ref.read(authStateProvider).hasValue;

  Future<void> _drain() async {
    if (_draining || !ref.mounted) return;
    _draining = true;
    try {
      final inbox = ref.read(assistantQueryInboxProvider);
      while (ref.mounted && _ready() && inbox.hasPending) {
        // Einen Schleifendurchlauf warten: Repos bauen sich nach dem ersten
        // Auth-Wert bzw. Profilwechsel neu auf.
        await Future<void>.delayed(Duration.zero);
        if (!ref.mounted || !_ready()) break;
        final query = inbox.takePending();
        if (query == null) break;
        logger.i('[AssistantQuery] ${assistantQueryId(query)}: zugestellt');
        ref.read(assistantQueryPendingProvider.notifier).state = query;
        state =
            AssistantQueryState(lastQuery: query, handled: state.handled + 1);
      }
    } finally {
      _draining = false;
    }
  }
}
