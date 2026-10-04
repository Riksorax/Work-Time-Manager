import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_lock_provider.dart';
import '../../domain/utils/app_lock_lockout.dart';
import '../../l10n/app_localizations.dart';

/// Gemeinsame Countdown-Logik für App-Sperre und "PIN vergessen"-Dialog
/// (siehe #358). Der 1-s-Timer läuft nur, solange eine Sperre aktiv ist, und
/// wird in `dispose` abgebrochen.
mixin LockoutCountdownMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Timer? _lockoutTimer;

  /// Verbleibende Wartezeit.
  Duration lockoutRemaining = Duration.zero;

  /// Gesamtdauer der aktuellen Sperre (bleibt während der Ticks konstant).
  Duration lockoutTotal = Duration.zero;

  bool _lockoutActive = false;

  /// Wartezeit ist in dieser Sitzung des Widgets abgelaufen.
  bool lockoutExpired = false;

  bool get lockedOut => lockoutRemaining > Duration.zero;

  /// Wird nach Ablauf der Wartezeit aufgerufen.
  void onLockoutEnded() {}

  /// In `initState` aufrufen: übernimmt den aktuellen Stand sofort (ohne
  /// Flackern) und gleicht danach mit der Uhr ab.
  void initLockout() {
    final service = ref.read(appLockServiceProvider);
    final initial = service.remainingLockout;
    if (initial > Duration.zero) {
      lockoutRemaining = initial;
      lockoutTotal = initial;
      _lockoutActive = true;
      _ensureTicker();
    }
    service.syncLockout().then((remaining) {
      if (mounted) applyLockout(remaining);
    });
  }

  void applyLockout(Duration remaining) {
    if (!mounted) return;
    var ended = false;
    setState(() {
      if (remaining > Duration.zero) {
        if (!_lockoutActive) {
          lockoutTotal = remaining;
          lockoutExpired = false;
        }
        _lockoutActive = true;
      } else if (_lockoutActive) {
        _lockoutActive = false;
        lockoutExpired = true;
        ended = true;
      }
      lockoutRemaining = remaining;
    });
    if (remaining > Duration.zero) {
      _ensureTicker();
    } else {
      _lockoutTimer?.cancel();
      _lockoutTimer = null;
    }
    if (ended) onLockoutEnded();
  }

  void _ensureTicker() {
    _lockoutTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      applyLockout(ref.read(appLockServiceProvider).remainingLockout);
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _lockoutTimer = null;
    super.dispose();
  }
}

/// Ansagetext für Screenreader bei Beginn der Wartezeit: volle Minuten als
/// Minuten, sonst Sekunden.
String lockoutAnnouncement(AppLocalizations l10n, Duration total) {
  final seconds = (total.inMilliseconds + 999) ~/ 1000;
  if (seconds >= 60 && seconds % 60 == 0) {
    return l10n.appLockTryAgainSemanticsMinutes(seconds ~/ 60);
  }
  return l10n.appLockTryAgainSemanticsSeconds(seconds);
}

/// Sichtbarer Countdown plus Live-Region für Screenreader. Der sichtbare Text
/// ist von der Semantik ausgenommen (keine Sekundenansage); das Label der
/// Live-Region ändert sich nur bei Sperrstart und Ablauf.
class LockoutNotice extends StatelessWidget {
  final Duration remaining;
  final Duration total;
  final bool expired;

  const LockoutNotice({
    super.key,
    required this.remaining,
    required this.total,
    required this.expired,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = remaining > Duration.zero;
    final announcement = active
        ? lockoutAnnouncement(l10n, total)
        : (expired ? l10n.appLockRetryNow : '');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (active)
          ExcludeSemantics(
            child: Text(
              l10n.appLockTooManyAttempts(formatLockoutCountdown(remaining)),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Semantics(
          liveRegion: true,
          label: announcement,
          child: const SizedBox(width: 1, height: 1),
        ),
      ],
    );
  }
}
