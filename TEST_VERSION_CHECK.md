# Version-Check Testing während der Entwicklung

## ✅ Was funktioniert beim Entwickeln

### 1. Firestore Version-Check (Funktioniert IMMER)

Der grundlegende Version-Check und Dialog funktionieren **vollständig** während der Entwicklung:

#### Test-Schritte:

1. **Firestore-Dokument erstellen** (in Firebase Console):
   ```
   Collection: app_config
   Document: version

   Felder:
   - min_version: "0.6.0"
   - force_update: true
   - update_message: "TEST: Update erforderlich!"
   ```

2. **Deine aktuelle App-Version senken** (in `pubspec.yaml`):
   ```yaml
   version: 0.4.0  # Niedriger als min_version
   ```

3. **App neu starten**:
   ```bash
   flutter run
   ```

4. **Ergebnis**:
   - ✅ Update-Dialog erscheint beim Start
   - ✅ Versions-Vergleich funktioniert
   - ✅ Force-Update blockiert die App
   - ✅ Optional-Update zeigt "Später"-Button
   - ✅ Dialog zeigt aktuelle vs. erforderliche Version

### 2. Store-Link Test (Funktioniert TEILWEISE)

Der "Jetzt updaten"-Button öffnet:
- **Android**: Google Play Store (funktioniert, zeigt deine App-Seite)
- **iOS**: App Store (funktioniert, zeigt Store-Hauptseite wenn keine App-ID gesetzt)

#### Wie testen:

1. Klicke auf "Jetzt updaten" Button
2. Store öffnet sich
3. ✅ Link-Funktionalität bestätigt

## ❌ Was NICHT beim Entwickeln funktioniert

### Android In-App-Update

Der Google Play Core In-App-Update Flow funktioniert **NUR** wenn:
- App über Google Play Store installiert wurde
- Eine neuere Version im Play Store verfügbar ist

#### Beim Entwickeln:
- `InAppUpdate.checkForUpdate()` gibt `UpdateAvailability.updateNotAvailable` zurück
- Immediate/Flexible Update werden nicht angezeigt
- **Automatischer Fallback**: App öffnet stattdessen den Play Store

## 🧪 Entwicklungs-Test-Szenarien

### Test 1: Force Update Dialog

**Setup:**
```yaml
# pubspec.yaml
version: 0.3.0
```

```json
// Firestore: app_config/version
{
  "min_version": "0.5.0",
  "force_update": true,
  "update_message": "Kritisches Update erforderlich!"
}
```

**Erwartetes Verhalten:**
- ✅ Dialog erscheint beim Start
- ✅ Dialog kann NICHT geschlossen werden (kein X, kein Tippen außerhalb)
- ✅ Nur "Jetzt updaten" Button sichtbar
- ✅ Button öffnet Play Store / App Store

---

### Test 2: Optional Update Dialog

**Setup:**
```json
// Firestore: app_config/version
{
  "min_version": "0.5.0",
  "force_update": false,
  "update_message": "Neue Features verfügbar!"
}
```

**Erwartetes Verhalten:**
- ✅ Dialog erscheint beim Start
- ✅ "Später" Button ist sichtbar
- ✅ Dialog kann geschlossen werden
- ✅ App ist weiterhin nutzbar

---

### Test 3: Kein Update nötig

**Setup:**
```yaml
# pubspec.yaml
version: 0.6.0  # Gleich oder höher als min_version
```

```json
// Firestore: app_config/version
{
  "min_version": "0.5.0",
  "force_update": true
}
```

**Erwartetes Verhalten:**
- ✅ KEIN Dialog erscheint
- ✅ App startet normal

---

### Test 4: Custom Message

**Setup:**
```json
// Firestore: app_config/version
{
  "min_version": "0.5.0",
  "force_update": false,
  "update_message": "🎉 Neue Version mit Dark Mode und vielen Verbesserungen!"
}
```

**Erwartetes Verhalten:**
- ✅ Dialog zeigt deine custom Message
- ✅ Emojis werden korrekt angezeigt

---

### Test 5: Fehlende Firestore Config

**Setup:**
- Lösche das Dokument `app_config/version` in Firestore

**Erwartetes Verhalten:**
- ✅ KEIN Dialog erscheint
- ✅ App startet normal
- ✅ Keine Fehler in der Konsole

## 🔧 Quick Test Commands

### Schnell zwischen Szenarien wechseln:

```bash
# Test Force Update
# 1. Ändere pubspec.yaml version auf 0.3.0
# 2. Setze Firestore min_version auf 0.5.0, force_update: true
flutter run

# Test Optional Update
# 1. Setze Firestore force_update: false
flutter run -d chrome  # Im Browser testen (schneller)

# Test "Kein Update"
# 1. Ändere pubspec.yaml version auf 0.6.0
flutter run
```

## 📱 Android In-App-Update Testen (Fortgeschritten)

Wenn du den **echten** Android In-App-Update Flow testen möchtest:

### Methode 1: Internal Testing Track

1. **Build erstellen:**
   ```bash
   flutter build appbundle
   ```

2. **Hochladen zu Google Play Console:**
   - Gehe zu "Release > Testing > Internal testing"
   - Lade die APK/AAB hoch (z.B. Version 0.5.0)

3. **Auf Testgerät installieren:**
   - Über Internal Testing Track Link

4. **Neuere Version hochladen:**
   - Lade Version 0.6.0 hoch

5. **App auf Gerät öffnen:**
   - In-App-Update Dialog erscheint! 🎉

### Methode 2: Lokales APK Update Testing (Funktioniert NICHT)

⚠️ **Achtung**: Folgendes funktioniert **NICHT** für In-App-Updates:
```bash
# ❌ Das triggert KEINEN In-App-Update Flow
flutter build apk
adb install app.apk
```

## 🎯 Empfohlener Test-Workflow während Entwicklung

1. **Haupt-Tests mit Firestore** (täglich):
   - Version-Vergleich
   - Dialog UI/UX
   - Force vs. Optional Update
   - Custom Messages

2. **Store-Link Test** (gelegentlich):
   - Stelle sicher Links funktionieren

3. **Android In-App-Update** (vor Release):
   - Teste 1x über Internal Testing Track
   - Validiere Immediate & Flexible Flow

## 💡 Entwicklungs-Tipps

### Schnelles Testen ohne App-Neustart

Erstelle einen Test-Button in den Einstellungen:

```dart
// In settings_page.dart temporär hinzufügen:
if (kDebugMode)
  ListTile(
    title: const Text('🧪 TEST: Version Check'),
    onTap: () async {
      final versionService = ref.read(versionServiceProvider);
      await UpdateRequiredDialog.checkAndShow(context, versionService);
    },
  ),
```

Dann kannst du den Dialog jederzeit manuell triggern ohne App-Neustart!

### Debug-Logs hinzufügen

Temporär in `version_service.dart` einfügen:

```dart
Future<UpdateInfo?> checkForRequiredUpdate() async {
  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;

  print('🔍 DEBUG: Current version: $currentVersion'); // ADD THIS

  final configDoc = await _firestore.collection('app_config').doc('version').get();

  print('🔍 DEBUG: Firestore doc exists: ${configDoc.exists}'); // ADD THIS

  if (configDoc.exists) {
    print('🔍 DEBUG: Firestore data: ${configDoc.data()}'); // ADD THIS
  }

  // ... rest of code
}
```

## ✅ Checkliste: Bereit für Production

Vor dem Release-Build:

- [ ] Firestore `app_config/version` Dokument existiert
- [ ] Firestore Security Rules erlauben public read
- [ ] `pubspec.yaml` version ist aktuell
- [ ] iOS App Store ID eingetragen (in `version_service.dart`)
- [ ] Alle Debug-Logs entfernt
- [ ] Test-Buttons in Settings entfernt
- [ ] Force Update mit niedrigerer Version getestet
- [ ] Optional Update mit niedrigerer Version getestet
- [ ] Kein Update bei gleicher/höherer Version getestet
- [ ] Store-Links auf echtem Gerät getestet
