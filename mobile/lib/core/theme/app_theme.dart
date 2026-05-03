import 'package:flutter/material.dart';

/// Die AppTheme-Klasse zentralisiert die Theme-Definitionen der Anwendung.
///
/// Sie enthält statische ThemeData-Objekte für den Light- und Dark-Mode.
/// Die Verwendung eines privaten Konstruktors AppTheme._() verhindert, dass
/// versehentlich Instanzen dieser Klasse erstellt werden.
class AppTheme {
  AppTheme._();

  // Die "Seed-Farbe", aus der die Farbpaletten für Light und Dark Mode
  // automatisch generiert werden. Dies sorgt für ein harmonisches
  // und konsistentes Farbschema. Ein Blau-Ton passt gut zu einer Business-App.
  static const _seedColor = Colors.blue;

  // --- LIGHT THEME ---
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    // Generiert ein komplettes Farbschema für den Light-Mode aus der Seed-Farbe.
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ),
    // Spezifische Anpassungen für einzelne Widgets im Light-Mode.
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent, // Lässt die Scaffold-Farbe durchscheinen
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
  );

  // --- DARK THEME ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    // Generiert ein komplettes Farbschema für den Dark-Mode aus derselben Seed-Farbe.
    // Flutter passt die Farben automatisch an den dunklen Hintergrund an.
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
    // Spezifische Anpassungen für einzelne Widgets im Dark-Mode.
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade800,
          width: 1,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
  );
}