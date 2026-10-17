import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// Schaltet die App auf allen Android-Versionen einheitlich auf Edge-to-Edge
/// (#468). Einmal in `main()` nach dem Binding-Init aufrufen. Ab Android 15
/// (Target SDK 35) erzwingt das System den Modus ohnehin; so verhalten sich
/// ältere Versionen gleich.
Future<void> enableEdgeToEdge() =>
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

/// Setzt die Icon-Helligkeit der Systemleisten passend zum aktuellen Theme
/// (Edge-to-Edge, #468). Wird in `MaterialApp.builder` über die ganze App
/// gelegt, damit auch Seiten ohne `AppBar` (Login, App-Sperre) lesbare Icons
/// bekommen; eine `AppBar` überschreibt den Wert mit ihrem Theme-Stil.
///
/// Es werden bewusst keine Farben gesetzt (`statusBarColor` und
/// `navigationBarColor` sind ab Android 15 wirkungslos und veraltet).
class SystemBarsStyle extends StatelessWidget {
  const SystemBarsStyle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? AppTheme.darkSystemOverlayStyle
          : AppTheme.lightSystemOverlayStyle,
      child: child,
    );
  }
}

/// Hält den Inhalt links und rechts frei von Display-Cutout und
/// Navigationsleiste (Querformat, 3-Tasten-Navigation). Oben und unten bleibt
/// es den Screens (`AppBar`, `BottomNavigationBar`, Sheets) überlassen.
///
/// `SafeArea` verbraucht die seitlichen Insets für die Kinder, ein
/// Screen-`SafeArea` rückt nicht doppelt ein.
class HorizontalSafeInsets extends StatelessWidget {
  const HorizontalSafeInsets({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(top: false, bottom: false, child: child);
  }
}
