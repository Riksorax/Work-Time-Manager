import 'dart:async';

import '../../domain/utils/timer_action.dart';

/// Briefkasten für Timer-Aktionen von außen (Notification-Button, App-Shortcut,
/// #274).
///
/// Die Plugin-Callbacks feuern vor dem Widget-Baum (Kaltstart) und es gibt
/// keinen globalen `ProviderContainer`. Deshalb puffert diese reine
/// Dart-Klasse die jüngste Aktion mit Zeitstempel; das `TimerActionViewModel`
/// holt sie ab, sobald die App entsperrt und die Anmeldung geklärt ist. Eine
/// Aktion verfällt nach [ttl], damit eine vergessene, gesperrte Aktion nicht
/// Stunden später feuert.
class TimerActionInbox {
  TimerActionInbox({
    DateTime Function()? clock,
    this.ttl = const Duration(minutes: 2),
  }) : _clock = clock ?? DateTime.now;

  /// Prozessweites Singleton für `main.dart` (Callbacks vor `runApp`).
  static final TimerActionInbox instance = TimerActionInbox();

  final DateTime Function() _clock;

  /// Gültigkeitsdauer einer gepufferten Aktion.
  final Duration ttl;

  TimerAction? _action;
  DateTime? _pushedAt;
  final StreamController<void> _pushes = StreamController<void>.broadcast();

  /// Meldet jedes [push] (nur Signal, die Aktion holt [takePending] ab).
  Stream<void> get pushes => _pushes.stream;

  /// Legt [action] ab; eine ältere, noch nicht abgeholte wird ersetzt.
  void push(TimerAction action) {
    _action = action;
    _pushedAt = _clock();
    _pushes.add(null);
  }

  bool get hasPending => _validAction() != null;

  /// Liefert die anstehende, noch gültige Aktion genau einmal und leert den
  /// Puffer. Eine verfallene Aktion wird verworfen (`null`).
  TimerAction? takePending() {
    final action = _validAction();
    clear();
    return action;
  }

  /// Verwirft eine anstehende Aktion.
  void clear() {
    _action = null;
    _pushedAt = null;
  }

  TimerAction? _validAction() {
    final action = _action;
    final at = _pushedAt;
    if (action == null || at == null) return null;
    return _clock().difference(at) > ttl ? null : action;
  }
}
