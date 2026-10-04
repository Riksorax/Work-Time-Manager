import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock_provider.dart';

/// Zentrale "heute"-Quelle (lokaler Kalendertag, #379), Pendant zum
/// `TodayService` im Web.
///
/// Der State ist der lokale Tag als `DateTime(y, m, d)`. Er wechselt zur
/// lokalen Mitternacht (Timer bis `DateTime(y, m, d + 1)`), beim Zurückkehren
/// in die App (`resumed`) und bei [refresh]. Da `DateTime` per Wert verglichen
/// wird, feuern Listener nur bei einem echten Tageswechsel.
class TodayNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final now = ref.watch(clockProvider)();

    final observer = _ResumeObserver(_onResumed);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
      WidgetsBinding.instance.removeObserver(observer);
    });

    _scheduleMidnight(now);
    return _dayOf(now);
  }

  static DateTime _dayOf(DateTime now) =>
      DateTime(now.year, now.month, now.day);

  /// Liest die Uhr neu und setzt den Tag; plant den Timer nur bei einem
  /// Tageswechsel neu.
  void refresh() {
    if (!ref.mounted) return;
    final now = ref.read(clockProvider)();
    final today = _dayOf(now);
    if (today != state) {
      state = today;
      _scheduleMidnight(now);
    }
  }

  void _onResumed() {
    if (!ref.mounted) return;
    final now = ref.read(clockProvider)();
    state = _dayOf(now);
    _scheduleMidnight(now);
  }

  void _scheduleMidnight(DateTime now) {
    _timer?.cancel();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    var delay = nextMidnight.difference(now);
    if (delay < const Duration(seconds: 1)) delay = const Duration(seconds: 1);
    _timer = Timer(delay, () {
      if (!ref.mounted) return;
      final current = ref.read(clockProvider)();
      state = _dayOf(current);
      _scheduleMidnight(current);
    });
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this._onResumed);

  final VoidCallback _onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResumed();
  }
}

final todayProvider =
    NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);
