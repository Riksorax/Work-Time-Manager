import 'package:flutter/material.dart';

import 'app_lock_screen.dart';

/// Legt die App-Sperre (siehe #223) als deckende Ebene über die App. Wird in
/// `MaterialApp.builder` verwendet.
///
/// Die Sperre läuft in einem **eigenen Navigator** (siehe #450): Sie liegt
/// oberhalb des App-Navigators. Dialoge (z. B. „PIN vergessen?“) würden sonst
/// in dessen Overlay landen, also hinter dem deckenden Sperrbildschirm. Mit
/// eigenem Navigator (und damit eigenem Overlay) öffnen `showDialog` & Co.
/// über den Kontext des Sperrbildschirms oberhalb davon. Dialoge der Sperre
/// daher nie über den globalen `navigatorKey` öffnen.
class AppLockLayer extends StatelessWidget {
  const AppLockLayer({super.key, required this.isLocked, required this.child});

  final bool isLocked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLocked) const _AppLockNavigator(),
      ],
    );
  }
}

class _AppLockNavigator extends StatelessWidget {
  const _AppLockNavigator();

  @override
  Widget build(BuildContext context) {
    // Einzige Route, kein Zurück: die Sperre lässt sich nicht wegnavigieren.
    return PopScope(
      canPop: false,
      // Der HeroController des App-Navigators darf nicht geteilt werden.
      child: HeroControllerScope.none(
        child: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const AppLockScreen(),
          ),
        ),
      ),
    );
  }
}
