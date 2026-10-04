import 'package:fake_async/fake_async.dart';

/// Veränderbare Uhr für Tests (#379).
///
/// `DateTime.now()` bewegt sich in `fakeAsync` nicht mit. Mit [bind] läuft die
/// Uhr zusammen mit `FakeAsync.elapsed` (`base + elapsed + offset`); [jumpTo]
/// setzt einen Uhrsprung ohne Timer-Ablauf (z. B. Standby/Resume).
class FakeClock {
  FakeClock(this._base);

  final DateTime _base;
  FakeAsync? _async;
  Duration _offset = Duration.zero;

  /// Koppelt die Uhr an [async]; `elapsed` zählt ab diesem Zeitpunkt.
  void bind(FakeAsync async) {
    _async = async;
    _elapsedAtBind = async.elapsed;
  }

  Duration _elapsedAtBind = Duration.zero;

  DateTime call() {
    final async = _async;
    final elapsed =
        async == null ? Duration.zero : async.elapsed - _elapsedAtBind;
    return _base.add(elapsed + _offset);
  }

  /// Springt auf [target], ohne dass Timer ablaufen.
  void jumpTo(DateTime target) {
    _offset = Duration.zero;
    final current = call();
    _offset = target.difference(current);
  }
}
