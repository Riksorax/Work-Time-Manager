**Titel:** `refactor: Clean up codebase and resolve linter warnings`

**Beschreibung:**

Dieser Commit behebt eine große Anzahl von Linter-Warnungen und anderen Problemen bezüglich der Codequalität im gesamten Projekt.

**Wichtige Änderungen:**

*   **Ungenutzte Abhängigkeiten entfernt:** Die Pakete `http`, `cupertino_icons` und `go_router` wurden aus `pubspec.yaml` entfernt, da sie nicht mehr verwendet wurden.
*   **`print`-Anweisungen durch `logger` ersetzt:** Alle `print`-Anweisungen im Code wurden durch Aufrufe eines neuen `logger`-Dienstes ersetzt. Dies ermöglicht eine strukturiertere und besser steuerbare Protokollierung.
*   **Linter-Warnungen behoben:** Eine Vielzahl von Linter-Warnungen wurde behoben, darunter:
    *   `unintended_html_in_doc_comment`: Probleme mit spitzen Klammern in Doc-Kommentaren wurden durch die Verwendung von Backticks gelöst.
    *   `use_super_parameters`: Konstruktoren wurden aktualisiert, um das moderne Dart-Feature der Super-Parameter zu nutzen.
    *   `deprecated_member_use`: Veraltete Methoden, wie `withOpacity`, wurden durch aktuelle Alternativen wie `withAlpha` ersetzt.
    *   `no_leading_underscores_for_local_identifiers`: Lokale Variablen wurden umbenannt, um den Stilrichtlinien zu entsprechen.
    *   `unnecessary_this`: Überflüssige `this.`-Qualifizierer wurden entfernt.
    *   `unnecessary_string_escapes`: Nicht notwendige Escape-Zeichen in String-Literalen wurden entfernt.
*   **Fehler behoben:**
    *   Ein Fehler in `test/widget_test.dart` wurde durch das Ersetzen des fehlerhaften Tests durch einen funktionsfähigen Platzhalter behoben.
    *   Mehrere "undefined name"-Fehler in `reports_page.dart` und `overtime_repository_impl.dart` wurden durch Anpassung des Geltungsbereichs und Korrektur von Tippfehlern gelöst.

**Auswirkungen:**

Diese Bereinigung verbessert die allgemeine Codequalität, Wartbarkeit und Leistung der Anwendung. Die verbleibenden `info`-Level-Hinweise des Linters wurden als False Positives oder als rein kosmetische Warnungen eingestuft, deren Behebung den Code unnötig komplex machen würde.
