import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:quick_actions/quick_actions.dart';

import '../../domain/utils/timer_action.dart';
import '../../l10n/app_localizations.dart';
import '../utils/logger.dart';

/// App-Icon-Shortcuts „Einstempeln“/„Ausstempeln“ (#274) sowie „Pause starten“/„Pause beenden“
/// (#485), nur Android.
///
/// Dünner Wrapper um `quick_actions`. Die Labels kommen aus `AppLocalizations`
/// (dynamische Shortcuts, keine `shortcuts.xml`) und müssen bei Sprachwechsel
/// neu gesetzt werden. Auf Web und anderen Plattformen ist alles ein No-op.
/// Plugin-Fehler werden geloggt und nie weitergeworfen.
class ShortcutService {
  ShortcutService({
    QuickActions quickActions = const QuickActions(),
    bool? supported,
  })  : _quickActions = quickActions,
        _supported = supported ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final QuickActions _quickActions;
  final bool _supported;

  /// Registriert den Handler. Das Plugin liefert einen Kaltstart-Shortcut
  /// direkt nach `initialize` an den Handler. Unbekannte Typen werden ignoriert.
  Future<void> initialize(void Function(TimerAction action) onAction) async {
    if (!_supported) return;
    try {
      await _quickActions.initialize((type) {
        final action = timerActionFromId(type);
        if (action == null) {
          logger.w('[ShortcutService] Unbekannter Shortcut ignoriert: $type');
          return;
        }
        onAction(action);
      });
    } catch (e, st) {
      logger.e('[ShortcutService] Initialisierung fehlgeschlagen',
          error: e, stackTrace: st);
    }
  }

  /// Setzt (ersetzt) die Shortcuts mit Labels aus [l10n].
  Future<void> setShortcuts(AppLocalizations l10n) async {
    if (!_supported) return;
    try {
      await _quickActions.setShortcutItems([
        ShortcutItem(
          type: timerStartActionId,
          localizedTitle: l10n.timerActionStart,
          icon: _icon,
        ),
        ShortcutItem(
          type: timerStopActionId,
          localizedTitle: l10n.timerActionStop,
          icon: _icon,
        ),
        ShortcutItem(
          type: timerPauseActionId,
          localizedTitle: l10n.timerActionPause,
          icon: _icon,
        ),
        ShortcutItem(
          type: timerResumeActionId,
          localizedTitle: l10n.timerActionResume,
          icon: _icon,
        ),
      ]);
    } catch (e, st) {
      logger.e('[ShortcutService] Shortcuts nicht setzbar',
          error: e, stackTrace: st);
    }
  }

  /// Launcher-Icon (Mipmap `launcher_icon`, vor dem R8-Resource-Shrinking in
  /// `res/raw/keep.xml` geschützt, weil es nur per Name aufgelöst wird).
  static const String _icon = 'launcher_icon';
}
