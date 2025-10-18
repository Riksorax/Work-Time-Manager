# Version-Check & Update-System - Dokumentation

## Übersicht

Das Update-System nutzt eine Kombination aus:
- **Android**: Google Play Core In-App-Updates (Immediate & Flexible)
- **iOS/Andere**: Firestore-basierter Version-Check mit Store-Link
- **Firestore**: Zentrale Konfiguration der minimalen erforderlichen Version

## Firestore Setup

### 1. Firestore-Dokument erstellen

Erstelle in der Firebase Console folgendes Dokument:

**Pfad:** `app_config/version`

**Felder:**
```json
{
  "min_version": "0.5.0",
  "force_update": true,
  "update_message": "Ein wichtiges Update ist verfügbar. Bitte aktualisieren Sie die App."
}
```

#### Feld-Beschreibungen:

- **`min_version`** (String, erforderlich): Die minimale Version, die Nutzer haben müssen
  - Format: Semantic Versioning (z.B. "0.5.0", "1.2.3")
  - Nutzer mit niedrigerer Version werden zum Update aufgefordert

- **`force_update`** (Boolean, optional, default: false):
  - `true`: Dialog kann nicht geschlossen werden, App nicht nutzbar bis Update
  - `false`: Dialog kann geschlossen werden, Nutzer kann App weiter nutzen

- **`update_message`** (String, optional): Benutzerdefinierte Nachricht
  - Wenn nicht gesetzt, wird eine Standard-Nachricht angezeigt

### 2. Firestore Security Rules

Füge folgende Rule hinzu, damit alle Nutzer die Version-Config lesen können:

```javascript
match /app_config/{document} {
  allow read: if true;
  allow write: if false; // Nur Admins über Console
}
```

## Funktionsweise

### Android (mit Google Play)

1. **Immediate Update** (force_update: true):
   - Vollbild-Update-Dialog
   - App wird blockiert bis Update installiert ist
   - Nutzt Google Play's native Update-Flow

2. **Flexible Update** (force_update: false):
   - Update wird im Hintergrund heruntergeladen
   - Nutzer kann App weiternutzen
   - Installation erfolgt beim nächsten App-Neustart

### iOS & andere Plattformen

- Custom Dialog mit Version-Informationen
- Button zum App Store (iOS) / Store-Link
- Bei `force_update: false` kann Dialog geschlossen werden

## Beispiel-Szenarien

### Szenario 1: Kritisches Update (Zwingend)

In Firestore setzen:
```json
{
  "min_version": "1.0.0",
  "force_update": true,
  "update_message": "Kritisches Sicherheitsupdate erforderlich. Die App muss aktualisiert werden."
}
```

**Verhalten:**
- Nutzer mit Version < 1.0.0 können die App nicht nutzen
- Android: Immediate Update Flow
- iOS: Nicht schließbarer Dialog mit Store-Link

### Szenario 2: Empfohlenes Update (Optional)

In Firestore setzen:
```json
{
  "min_version": "0.8.0",
  "force_update": false,
  "update_message": "Eine neue Version mit vielen Verbesserungen ist verfügbar!"
}
```

**Verhalten:**
- Nutzer mit Version < 0.8.0 sehen einen Dialog
- Dialog kann geschlossen werden
- Android: Flexible Update (im Hintergrund)
- iOS: Dialog mit "Später"-Button

## Version in pubspec.yaml aktualisieren

Wenn du eine neue Version veröffentlichst, aktualisiere die `pubspec.yaml`:

```yaml
version: 1.0.0
```

Die App zeigt diese Version automatisch in den Einstellungen an.

## Testing

### Lokales Testing

1. **Ändere die Version in `pubspec.yaml`** auf eine niedrigere Version (z.B. 0.3.0)
2. **Setze `min_version` in Firestore** auf eine höhere Version (z.B. 0.5.0)
3. **Starte die App** - der Update-Dialog sollte erscheinen

### Android In-App-Update Testing

⚠️ **Wichtig**: In-App-Updates funktionieren nur bei Apps, die über Google Play installiert wurden!

Für lokales Testing:
- Nutze Internal Testing Track in Google Play Console
- Lade eine Version hoch
- Installiere diese auf einem Testgerät
- Lade eine neuere Version in den Testing Track
- Die App sollte das Update erkennen

## iOS App Store ID konfigurieren

Für iOS musst du die App Store ID in `version_service.dart` eintragen:

```dart
if (Platform.isIOS) {
  storeUrl = Uri.parse('https://apps.apple.com/app/idXXXXXXXXX');
  // Ersetze XXXXXXXXX mit deiner App Store ID
}
```

## Troubleshooting

### Update-Dialog erscheint nicht

1. **Prüfe Firestore-Konfiguration**:
   - Existiert `/app_config/version`?
   - Sind die Felder korrekt gesetzt?

2. **Prüfe Firestore Security Rules**:
   - Können anonyme Nutzer lesen?

3. **Prüfe Version-Vergleich**:
   - Ist `min_version` wirklich höher als die aktuelle App-Version?

### Android In-App-Update funktioniert nicht

1. **App über Play Store installiert?**
   - In-App-Updates funktionieren nur bei Play Store Installationen

2. **Neuere Version verfügbar?**
   - Im Play Console muss eine höhere Version verfügbar sein

3. **Fallback-Verhalten:**
   - Wenn In-App-Update fehlschlägt, öffnet sich der Play Store

## Best Practices

1. **Sanfte Updates**: Nutze `force_update: false` für normale Updates
2. **Kritische Updates**: Nutze `force_update: true` nur bei Sicherheitsproblemen oder Breaking Changes
3. **Klare Nachrichten**: Erkläre im `update_message` warum das Update wichtig ist
4. **Schrittweise Rollouts**: Erhöhe `min_version` schrittweise, nicht sofort auf die neueste Version
5. **Testing**: Teste jeden Update-Flow vor dem Produktiv-Rollout

## Wartung

### Version erhöhen

1. Entwickle neue Features
2. Aktualisiere `version` in `pubspec.yaml`
3. Veröffentliche die App
4. Aktualisiere `min_version` in Firestore (optional, je nach Wichtigkeit)

### Ältere Versionen unterstützen

Wenn du möchtest, dass auch ältere Versionen weiter funktionieren:
- Lass `min_version` unverändert
- Oder setze `force_update: false` für optionale Updates
