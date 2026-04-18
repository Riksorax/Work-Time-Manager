# Agent 0 — Flutter Analysis Report

> **WICHTIGE VORGABE:** Die Angular Web-App muss 1:1 exakt dieselben Funktionen bieten wie die Flutter App. Das UI soll an das Web (Desktop/Browser) angepasst werden, aber alle Funktionen und Features müssen lückenlos vorhanden sein.

# Work-Time-Manager (Lokale Analyse)
# Version: 0.24.1 | Analysiert: 2026-04-18

---

## 1. Tech Stack (Flutter)
- **State Management:** Riverpod (via `presentation/state` und `view_models`)
- **Architektur:** Clean Architecture (Entities -> UseCases -> Repositories)
- **Datenbank:** Firebase Firestore (Hybrid: Local & Cloud)
- **Design:** Material 3 (Seed Color: `Colors.blue`)

---

## 2. Business Logik (Core)

### 2.1 Zeitberechnungen (`work_entry_extensions.dart`)
- **Brutto-Dauer:** `workEnd` - `workStart` (wenn `workEnd` null, dann `DateTime.now()`).
- **Pausen-Dauer:** Summe aller `breaks[].duration`.
- **Netto-Dauer:** `Brutto-Dauer` - `Pausen-Dauer`.
- **Überstunden (Tag):** `Netto-Dauer` - `tägliche_Sollzeit` + `manuelle_Korrektur`.
    - *Ausnahme:* Bei Urlaub, Krank oder Feiertag gilt die Sollzeit als erfüllt (Überstunden = 0 + Korrektur).

### 2.2 Pausen-Compliance (`break_calculator_service.dart`)
Die App implementiert das deutsche Arbeitszeitgesetz:
- **6-9 Stunden Netto:** 30 Min Pflichtpause.
- **> 9 Stunden Netto:** 45 Min Pflichtpause.
- **Automatische Pause:** Wenn der User weniger als die Pflichtpause macht, kann die App die fehlende Zeit automatisch abziehen (wichtig für Web-Portierung!).

---

## 3. Datenmodelle (Firestore-Schema)

### Collection: `work_entries`
| Feld | Typ | Beschreibung |
|---|---|---|
| `date` | Timestamp | Datum des Eintrags (UTC) |
| `workStart` | Timestamp? | Beginn der Arbeit |
| `workEnd` | Timestamp? | Ende der Arbeit |
| `type` | String | `work`, `vacation`, `sick`, `holiday` |
| `isManuallyEntered`| Boolean | True, wenn manuell nachgetragen |
| `manualOvertimeMinutes`| Number | Manuelle Korrektur des Saldos |
| `breaks` | List<Map> | Liste von Pausen-Objekten |

### Sub-Object: `Break`
| Feld | Typ | Beschreibung |
|---|---|---|
| `id` | String (UUID) | Eindeutige ID |
| `name` | String | Name der Pause |
| `start` | Timestamp | Beginn |
| `end` | Timestamp? | Ende |
| `isAutomatic` | Boolean | Wurde vom System generiert |

---

## 4. UI Anforderungen (für Stitch Porting)

### Farbschema (Material 3)
- **Seed Color:** `0xFF2196F3` (Standard Material Blue).
- **Cards:** Border-Radius `12px`, Elevation `1`.
- **Buttons:** Border-Radius `10px`.

### Haupt-Screens
1. **Dashboard:** Große Timer-Anzeige, Start/Stop/Pause Buttons, Heute-Statistik (Ist, Soll, +/-).
2. **History:** Liste der Arbeitstage, Filterbar nach Monat.
3. **Settings:**
    - Wochen-Sollstunden (Default: 40.0)
    - Arbeitstage pro Woche (Default: 5)
    - Benachrichtigungs-Konfiguration.

---

## 5. Bekannte Korrekturen (für Angular)
- In Flutter wird `intl` für die Formatierung genutzt -> In Angular nutzen wir `DatePipe` und `ngx-translate`.
- `Uuid().v4()` aus Dart -> `uuid` npm package.
- `Timestamp` mapping -> Firebase JS SDK `Timestamp` handling beachten.

## Übergabe
Nutzen Sie diesen Report als einzige Quelle der Wahrheit für:
- Datenmodelle -> Agent 01 (Architect)
- Business-Logik-Berechnungen -> Agent 03 (Core)
- UI Porting -> Agent 04 (Stitch UI)
