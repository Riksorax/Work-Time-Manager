**Titel:** `fix: Kompilierungsfehler behoben und Benachrichtigungs-Setup verbessert`

**Beschreibung:**

Dieser Pull Request behebt kritische Kompilierungsfehler, die das Bauen der App verhinderten, und führt kleinere Bereinigungen im `NotificationService` durch. Zusätzlich wurde die korrekte Funktionsweise der Benachrichtigungseinstellungen verifiziert.

**Änderungen:**

*   **`lib/main.dart`:**
    *   Typfehler bei der Initialisierung der Zeitzone behoben. Der Rückgabewert von `FlutterTimezone.getLocalTimezone()` wird nun explizit in einen String konvertiert, um Typkonflikte mit `tz.getLocation()` zu vermeiden.
*   **`lib/presentation/view_models/settings_view_model.dart`:**
    *   Fehlender Import für `NotificationService` hinzugefügt. Dies behebt den Fehler, dass die Klasse nicht gefunden wurde.
*   **`lib/core/services/notification_service.dart`:**
    *   Ungenutzter Import (`package:timezone/data/latest_all.dart`) entfernt, um den Code zu bereinigen.

**Verifikation:**

*   `flutter analyze` wurde ausgeführt und zeigt nun keine Fehler mehr an (0 errors).
*   Die Logik der Benachrichtigungsplanung (`scheduleDailyReminder`) und die Integration in den `SettingsViewModel` (`_rescheduleNotifications`) wurden überprüft und als korrekt bestätigt.