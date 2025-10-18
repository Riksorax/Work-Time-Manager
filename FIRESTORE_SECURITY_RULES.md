# Firestore Security Rules Setup

## Problem: Permission Denied

Wenn du diesen Fehler siehst:
```
[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
```

Dann müssen die Firestore Security Rules angepasst werden.

## Lösung: Security Rules anpassen

### Schritt 1: Firebase Console öffnen

1. Gehe zu [Firebase Console](https://console.firebase.google.com/)
2. Wähle dein Projekt aus
3. Klicke im Menü auf **"Firestore Database"**
4. Wähle den Tab **"Regeln"** (Rules)

### Schritt 2: Rules für app_config hinzufügen

Füge folgende Rule **VOR** dem letzten `}` ein:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Bestehende Rules für users (NICHT ÄNDERN)
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      match /work_entries/{entryId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // NEU: App-Konfiguration (für Version-Check)
    // Alle können lesen, aber nur über Firebase Console schreiben
    match /app_config/{document} {
      allow read: if true;  // Öffentlich lesbar
      allow write: if false; // Nur Admins über Console
    }
  }
}
```

### Schritt 3: Veröffentlichen

1. Klicke auf **"Veröffentlichen"** (Publish)
2. Bestätige die Änderungen

## Vollständige Security Rules (Beispiel)

Falls du von Null starten möchtest, hier sind komplette Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // User-Daten: Nur eigene Daten lesbar/schreibbar
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // Arbeitseinträge: Nur eigene lesbar/schreibbar
      match /work_entries/{entryId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // App-Konfiguration: Öffentlich lesbar, nicht schreibbar
    match /app_config/{document} {
      allow read: if true;
      allow write: if false;
    }

    // Alles andere: Blockiert
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Sicherheit

### ✅ Sicher

- `allow read: if true;` für `app_config` ist **sicher**, weil:
  - Dort nur App-Konfiguration steht (Version, etc.)
  - Keine persönlichen/sensiblen Daten
  - Nur Admins können schreiben (`allow write: if false`)

### ⚠️ Zu beachten

- **NIEMALS** `allow read, write: if true;` für User-Daten!
- User-Daten immer mit `request.auth.uid == userId` schützen

## Testing

Nach der Anpassung:

1. **App neu starten**: `flutter run`
2. **Console checken**: Du solltest jetzt sehen:
   ```
   ✅ Version-Check: Aktuelle Version: 0.5.0, Min Version: 0.6.0
   ⚠️ Update erforderlich: 0.5.0 < 0.6.0
   ```
3. **Update-Dialog** sollte erscheinen

## Troubleshooting

### Rules wurden angepasst, aber Fehler bleibt

1. **Warte 1-2 Minuten** - Rules brauchen Zeit zum Propagieren
2. **App komplett neu starten** (nicht nur Hot Reload)
3. **Cache leeren**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### Dokument existiert nicht

Falls das Dokument `app_config/version` noch nicht existiert:

1. Gehe in Firebase Console zu **Firestore Database**
2. Klicke auf **"Sammlung starten"** (Start collection)
3. **Sammlungs-ID**: `app_config`
4. **Dokument-ID**: `version`
5. **Felder hinzufügen**:
   - Feld: `min_version`, Typ: string, Wert: `0.6.0`
   - Feld: `force_update`, Typ: boolean, Wert: `false`
   - Feld: `update_message`, Typ: string, Wert: `Update verfügbar!`
6. **Speichern**

### Ich sehe immer noch permission-denied

Prüfe in der Console die **aktuellen Rules**:

1. Firestore Database → Regeln
2. Stelle sicher, dass die Rules **veröffentlicht** wurden (grüner Haken)
3. Prüfe, ob `match /app_config/{document}` wirklich drin steht

## Beispiel: Debug-Output

Nach erfolgreicher Konfiguration siehst du in der Flutter-Console:

```
ℹ️ Version-Check: Kein app_config/version Dokument in Firestore gefunden
```
**oder**
```
✅ Version-Check: Aktuelle Version: 0.5.0, Min Version: 0.6.0
⚠️ Update erforderlich: 0.5.0 < 0.6.0
```
**oder**
```
✅ Version-Check: Aktuelle Version: 0.7.0, Min Version: 0.6.0
✅ Version-Check: Keine Aktualisierung erforderlich
```

Falls du siehst:
```
⚠️ Version-Check: Firestore Permission Denied
   Bitte Firestore Security Rules anpassen:
   match /app_config/{document} { allow read: if true; }
```

→ Security Rules noch nicht korrekt angepasst!
