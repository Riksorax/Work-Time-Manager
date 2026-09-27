/// Domain-Pendant zu Flutters `ThemeMode` (siehe #293). Die Domain-Schicht
/// bleibt dadurch frei von Flutter-Abhängigkeiten. Die Namen sind bewusst
/// identisch zu `ThemeMode` (`system`, `light`, `dark`), damit das
/// Speicherformat in SharedPreferences unverändert bleibt (`mode.name`,
/// siehe `SettingsRepositoryImpl`) — bestehende gespeicherte Werte lesen
/// sich weiterhin korrekt ein.
///
/// Die Umwandlung zu/von Flutters `ThemeMode` passiert ausschließlich in
/// `ThemeViewModel` (Presentation-Layer).
enum AppThemeMode { system, light, dark }
