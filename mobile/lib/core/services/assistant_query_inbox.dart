import 'dart:async';

import '../../domain/utils/assistant_query.dart';

/// Briefkasten für Sprachabfragen des Assistant (#287), Vorbild
/// `TimerActionInbox`.
///
/// Der Plugin-Callback feuert vor dem Widget-Baum (Kaltstart) und es gibt
/// keinen globalen `ProviderContainer`. Deshalb puffert diese reine
/// Dart-Klasse die jüngste Abfrage mit Zeitstempel; das
/// `AssistantQueryViewModel` holt sie ab, sobald die App entsperrt und die
/// Anmeldung geklärt ist. Eine Abfrage verfällt nach [ttl] still, damit eine
/// bei gesperrter App vergessene Abfrage nicht viel später aufspringt.
class AssistantQueryInbox {
  AssistantQueryInbox({
    DateTime Function()? clock,
    this.ttl = const Duration(minutes: 2),
  }) : _clock = clock ?? DateTime.now;

  /// Prozessweites Singleton für `main.dart` (Callbacks vor `runApp`).
  static final AssistantQueryInbox instance = AssistantQueryInbox();

  final DateTime Function() _clock;

  /// Gültigkeitsdauer einer gepufferten Abfrage.
  final Duration ttl;

  AssistantQuery? _query;
  DateTime? _pushedAt;
  final StreamController<void> _pushes = StreamController<void>.broadcast();

  /// Meldet jedes [push] (nur Signal, die Abfrage holt [takePending] ab).
  Stream<void> get pushes => _pushes.stream;

  /// Legt [query] ab; eine ältere, noch nicht abgeholte wird ersetzt.
  void push(AssistantQuery query) {
    _query = query;
    _pushedAt = _clock();
    _pushes.add(null);
  }

  bool get hasPending => _valid() != null;

  /// Liefert die anstehende, noch gültige Abfrage genau einmal und leert den
  /// Puffer. Eine verfallene Abfrage wird verworfen (`null`).
  AssistantQuery? takePending() {
    final query = _valid();
    clear();
    return query;
  }

  /// Verwirft eine anstehende Abfrage.
  void clear() {
    _query = null;
    _pushedAt = null;
  }

  AssistantQuery? _valid() {
    final query = _query;
    final at = _pushedAt;
    if (query == null || at == null) return null;
    return _clock().difference(at) > ttl ? null : query;
  }
}
