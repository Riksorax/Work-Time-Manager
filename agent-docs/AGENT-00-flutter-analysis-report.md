# Agent 0 — Flutter Analysis Report (Aktualisiert)

> **WICHTIGE VORGABE:** Die Angular Web-App muss 1:1 exakt dieselben Funktionen bieten wie die Flutter App. Das UI soll an das Web (Desktop/Browser) angepasst werden, aber alle Funktionen und Features müssen lückenlos vorhanden sein.

# Work-Time-Manager (Lokale Analyse)
# Version: 0.24.1 | Analysiert: 2026-04-18

---

## 1. Tech Stack (Flutter)

| Bereich | Package | Version | Angular-Äquivalent |
|---|---|---|---|
| State | flutter_riverpod | ^3.0.3 | Angular Signals |
| Auth | firebase_auth | ^6.1.3 | Firebase JS SDK v10 Auth |
| DB | cloud_firestore | ^6.1.1 | Firebase JS SDK v10 Firestore |
| Google Auth | google_sign_in | ^7.2.0 | GoogleAuthProvider (Firebase JS) |
| Premium | purchases_flutter | ^9.10.2 | @revenuecat/purchases-js |
| Notifications | flutter_local_notifications | ^19.5.0 | Firebase Cloud Messaging (Web) |

---

## 2. Features & Premium-Gates

### Kostenlose Features (Free Tier)
- **Arbeitszeiterfassung**: Start / Stop des Timers (ein Haupteintrag pro Tag).
- **Pausenmanagement**: Beliebig viele manuelle Pausen; Unterstützung für automatische Pausen (BreakCalculatorService).
- **Überstunden-Saldo**: Manuelle Anpassung der Überstunden/Gleitzeit-Bilanz.
- **Tages-Dashboard**: Echtzeit-Timer (Netto/Brutto), Heutige Überstunden, Voraussichtlicher Feierabend (±0 und inkl. Bilanz).
- **Historie**: Monatsübersicht der Arbeitstage.
- **Typen**: Unterscheidung zwischen Arbeit, Urlaub, Krankheit, Feiertag.
- **Google Sign-In + Email/Password Auth**.

### Premium Features (hinter RevenueCat-Gate)
- **Multi-Profile / Mehrere Arbeitgeber**: Mehrere Arbeitszeit-Profile gleichzeitig verwalten.
- **Berichte & Exports**: PDF/CSV Export (geplant/in Arbeit).
- **Jahresberichte**: Auswertung über das ganze Jahr.

---

## 3. Datenmodelle (Firestore-Schema - Tatsächliche Implementierung)

### Collection: `users/{uid}`
```typescript
UserProfile {
  uid: string;
  email: string;
  displayName?: string;
  photoURL?: string;
  isPremium: boolean;
  settings: {
    language: 'de' | 'en';
    theme: 'light' | 'dark' | 'system';
    weeklyTargetHours: number;
    dailyTargetHours: number;
  }
}
```

### Collection: `users/{uid}/work_entries/{year-month}`
Dies ist ein Dokument pro Monat (z.B. `2024-04`), das alle Tage enthält.
```typescript
WorkMonth {
  days: {
    [day: string]: { // z.B. "18"
      date: Timestamp;
      workStart?: Timestamp;
      workEnd?: Timestamp;
      type: 'work' | 'vacation' | 'sick' | 'holiday';
      description?: string;
      isManuallyEntered: bool;
      manualOvertimeMinutes?: number;
      breaks: Array<{
        id: string;
        name: string;
        start: Timestamp;
        end?: Timestamp;
        isAutomatic: boolean;
      }>;
    }
  }
}
```

### Collection: `users/{uid}/overtime/balance`
```typescript
OvertimeBalance {
  minutes: number;
  lastUpdated: Timestamp;
}
```

---

## 4. Business-Logik

### 4.1 Nettoarbeitszeit
`Netto = (Ende - Start) - SUMME(Pausen)`
- Wenn Ende fehlt: `Ende = Jetzt`
- Wenn Pause noch läuft: `Pausen-Ende = Jetzt`

### 4.2 Überstunden (Tag)
`Tag_Überstunden = Netto - Sollarbeitszeit_Tag`
- Sollarbeitszeit kommt aus den User-Settings.

### 4.3 Voraussichtlicher Feierabend
- `±0`: `Startzeit + Sollarbeitszeit + Pausendauer`
- `Mit Bilanz`: `Startzeit + (Sollarbeitszeit - Aktuelle_Bilanz) + Pausendauer`

---

## 5. UI Anforderungen (Web-Anpassung)

- **Dashboard**: Große Timer-Anzeige, interaktive Zeitauswahl (Material TimePicker), übersichtliche Pausen-Liste.
- **Responsive Layout**: Auf Desktop 2-spaltig (Links: Timer/Stats, Rechts: Controls/Pausen), auf Mobile 1-spaltig.
- **Navigation**: Sidebar für schnellen Wechsel zwischen Dashboard, Historie und Einstellungen.

---

## 6. Bekannte Korrekturen (vs. ursprünglichem Plan)

- **KEINE `workSessions` Collection**: Die Daten liegen in `work_entries` Dokumenten (monatsbasiert).
- **Pausen sind Teil des WorkEntry**: Keine separate Collection.
- **Überstunden-Bilanz ist ein expliziter Wert**: Muss bei jedem Tagesschluss oder manuell aktualisiert werden können.
