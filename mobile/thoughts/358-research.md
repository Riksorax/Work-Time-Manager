# Mobile-Research: #358 — App-Sperre: Brute-Force-Limit für PIN- und Wiederherstellungscode-Eingabe
Datum: 2026-10-04

## Aufgabe
Folge-Issue zu #288/#357. Heute gibt es kein Limit für Fehlversuche bei der PIN-Eingabe (`AppLockScreen`) und der Wiederherstellungscode-Eingabe (`ForgotPinDialog`). Ein 4–6-stelliger PIN (10^4–10^6 Möglichkeiten) ist auf einem entsperrten Gerät beliebig oft ratbar.

Akzeptanzkriterien (aus dem Issue, Kommentare: keine, nur Label `enhancement`, Plattform Mobile):
- Nach mehreren Fehlversuchen steigende Wartezeit (Vorschlag 5 → 30 → 300 s).
- Zähler persistent im `AppLockService` (SharedPreferences, überlebt App-Neustart).
- Zähler gilt gemeinsam für PIN und Wiederherstellungscode.
- Zähler wird bei Erfolg zurückgesetzt.
- Gerätezeit-Manipulation berücksichtigen (monotone Uhr bzw. Sperre bei Rückstellung).
- Texte DE/EN über ARB.

Nicht Teil der Aufgabe: Änderung des Hash-Verfahrens (SHA-256 + Salt), Secure Storage / Keystore, serverseitige Prüfung, Änderung des PIN-Reset-Flows selbst.

## Betroffene Dateien
| Datei | Warum |
|---|---|
| `mobile/lib/core/services/app_lock_service.dart` | Zähler, Sperrzeit, Uhr-Schutz; neue Methoden. Heute nur synchrone `verifyPin`/`verifyRecoveryCode` ohne Zustand; Keys `app_lock_enabled`, `app_lock_pin_hash`, `app_lock_pin_salt` (Legacy), `app_lock_recovery_code_hash` |
| `mobile/lib/core/providers/app_lock_provider.dart` | `appLockServiceProvider` (ohne Uhr). Uhr-Injektion ergänzen (Provider `clockProvider` nutzen oder Konstruktor-Param) |
| `mobile/lib/core/providers/clock_provider.dart` (+ `.g.dart`) | Vorhandene `DateTime Function() clock(Ref)`, Default `DateTime.now`. Herkunft #279 (Feiertags-Banner), NICHT #368. Wiederverwendbar, braucht aber zusätzlich eine monotone Quelle |
| `mobile/lib/presentation/widgets/app_lock_screen.dart` | Einziger Aufrufer von `verifyPin` (`_submitPin`, synchron). Feld deaktivieren, Countdown, Fehlertext, Semantics |
| `mobile/lib/presentation/widgets/forgot_pin_dialog.dart` | Einziger Aufrufer von `verifyRecoveryCode` (`_submitCode`). Code-Feld deaktivieren, Countdown. Google-Re-Auth-Button bleibt separat |
| `mobile/lib/presentation/widgets/pin_setup_dialog.dart` | Ruft `setPinWithRecoveryCode` (Zähler dort zurücksetzen). Nutzt keine Verifikation |
| `mobile/lib/presentation/screens/settings_page.dart` (`_AppLockSection`) | Ruft `setEnabled`, Änderung der PIN über `PinSetupDialog` (nur im entsperrten Zustand erreichbar). `clearPin` hat KEINEN Aufrufer in `lib/` (nur Service + Tests) |
| `mobile/lib/main.dart` (`_MyAppState`) | Lifecycle `paused` setzt `isAppLockedProvider = true`; `AppLockScreen` liegt als Stack-Overlay im `MaterialApp.builder`. Resume-Hook für Uhr-Abgleich möglich |
| `mobile/lib/l10n/app_de.arb` / `app_en.arb` | Neue Keys (siehe unten); vorhanden: `wrongPin`, `wrongRecoveryCodeError`, `appLockedTitle`, `enterPinLabel`, `unlockAction` |
| `mobile/test/core/services/app_lock_service_test.dart`, `test/presentation/widgets/app_lock_screen_test.dart`, `forgot_pin_dialog_test.dart`, `pin_setup_dialog_test.dart` | Bestehende Tests; Erweiterung/Anpassung |

## Ist-Zustand

### Wo PIN und Code verifiziert werden (alle Aufrufer)
- `verifyPin`: Produktivcode nur `AppLockScreen._submitPin` (Zeile 52–68). Bei Fehler: Fehlermeldung `wrongPin`, Feld leeren, keine Begrenzung. Taste „Unlock" und `onSubmitted` rufen beide `_submitPin`.
- `verifyRecoveryCode`: Produktivcode nur `ForgotPinDialog._submitCode` (Zeile 62–72). Fehler: `wrongRecoveryCodeError`, Feld leeren, keine Begrenzung. Der Dialog ist `barrierDismissible: false`, kann aber via „Abbrechen" geschlossen und sofort neu geöffnet werden (heute ohnehin ohne Zustand).
- Weitere Wege, die entsperren, ohne `verifyPin`: Biometrie (`_tryBiometrics`, `biometricOnly: true`, kein Geräte-PIN-Fallback) und Google-Re-Auth im `ForgotPinDialog._reauth` (`reauthenticateProvider`, interaktiver Google-Account-Chooser, nur für Google-Provider, UID muss passen). Beide führen danach zwingend in `PinSetupDialog` (neue PIN + neuer Code), entsperren erst nach erfolgreichem Setzen.
- Tests rufen `verifyPin`/`verifyRecoveryCode` an ~25 Stellen synchron direkt auf dem Service auf (Hilfsprüfung nach Setups).

### Persistenz / Schlüsselkonzept
- Alle Keys sind global (kein `uid`, kein `profileId`): `app_lock_*`. Die App-Sperre ist gerätebezogen, nicht an Login/Arbeitszeit-Profil (#138) gebunden. Es gibt kein `prefs.clear()` und keinen Logout-Cleanup dieser Keys. Neue Keys folgen dem Muster: `app_lock_failed_attempts` (int), `app_lock_locked_until_ms` (int, Wanduhr UTC-Epoch), `app_lock_last_seen_ms` (int, höchste je beobachtete Wanduhr). Kein User/Profil im Key.
- `SharedPreferences` kommt nur über `sharedPreferencesProvider` (Override in `main.dart`); bleibt so.
- Schreibverhalten: `setInt` aktualisiert den In-Memory-Cache synchron, die Datei asynchron (`Future`).

## Entwurf-Eckpunkte (keine Umsetzung, Grundlage für /mobile-plan)

### Zähler und Stufen
- Ein gemeinsamer Zähler `failedAttempts` für PIN und Code (Issue-Vorschlag, zugestimmt: sonst verdoppelt ein Angreifer seine Versuche).
- Stufen (Empfehlung): Fehlversuch 1–2 ohne Sperre (Vertipper), 3–4 → 5 s, 5–6 → 30 s, ab 7 → 300 s, bei jedem weiteren Fehlversuch wieder 300 s (Deckel). Rechnung: 10^4 PINs × 300 s ≈ 35 Tage; für einen 4-stelligen PIN ist das ausreichend, ohne Dauer-Aussperrung des Besitzers.
- Zähler wird NICHT nach Ablauf der Wartezeit zurückgesetzt, nur bei Erfolg (und bei neuem PIN, s. u.).
- Wiederherstellungscode hat 80 Bit (nicht ratbar); gemeinsamer Zähler dient vor allem dazu, dass der Code-Pfad kein Schlupfloch für Wartezeit-Umgehung ist.

### Persist-before-verify (wichtig)
Wenn man den Zähler erst nach einem Fehlschlag schreibt, kann ein Angreifer die App nach jedem Versuch hart beenden und den Schreibvorgang verlieren. Empfehlung: Versuch zuerst zählen und `await`en, dann prüfen, bei Erfolg zurücksetzen. Das verlangt eine neue asynchrone API, z. B. `Future<AttemptResult> attemptPin(String)` / `attemptRecoveryCode(String)` (Ergebnis: success / wrong / locked(remaining)); `verifyPin`/`verifyRecoveryCode` bleiben als reine, ungezählte Prüfung bestehen (die ~25 Testaufrufe bleiben unverändert).

### Uhr / Manipulationsschutz
- Dart hat keine boot-übergreifende monotone Uhr. `Stopwatch` ist monoton, aber prozessgebunden (nach Neustart/Kill weg, auf Android pausiert sie je nach Plattform nicht im Doze zuverlässig). `elapsedRealtime`/`uptime` bräuchte einen Plattform-Channel oder ein neues Plugin (nicht in `pubspec.yaml`) — Aufwand/Risiko hoch, und `elapsedRealtime` ist ohnehin nach Reboot zurückgesetzt.
- Empfehlung (Hybrid):
  1. Persistiert wird `lockedUntil` (Wanduhr) und `lastSeen` (größte je beobachtete Wanduhr, bei jedem Versuch, bei Lock-Start und bei Resume geschrieben).
  2. Im laufenden Prozess zählt der Countdown über eine `Stopwatch` ab Lock-Start (immun gegen Zurückstellen der Uhr während der Sitzung).
  3. Nach Neustart/Resume: ist `now < lastSeen - Toleranz` (Toleranz z. B. 2 min für NTP/Zeitzonenkorrektur), gilt die Uhr als zurückgestellt → Restsperre wird auf die volle aktuelle Stufendauer neu gesetzt (nicht auf 0 und nicht unbegrenzt). Sonst `remaining = lockedUntil - now`.
  4. Zeit VORwärts zu stellen (Sperre läuft früher ab) ist offline nicht erkennbar; akzeptiertes Restrisiko, dokumentieren. Zeitzonenwechsel ist unkritisch, wenn UTC-Millis gespeichert werden.
- Reboot: Stopwatch weg, Abgleich über Wanduhr wie oben. Alle drei Werte liegen in SharedPreferences, also überlebt der Zustand den Neustart. Der Angreifer kann Wanduhr zurückstellen und neu starten; das wird durch `lastSeen` erkannt.
- Uhr-Injektion: `clockProvider` (`DateTime Function()`) wiederverwenden (bereits Test-Override-Muster). Die Stopwatch/monotone Quelle sollte ebenfalls injizierbar sein (z. B. `Duration Function() monotonic`), damit Tests keine echte Zeit brauchen (CLAUDE.md: Tests dürfen nicht von Datum/Zeitzone abhängen). Wenn nur `clockProvider` genutzt wird, ist eine fake-barer Test der Rückstellung möglich, ein Stopwatch-Pfad aber nicht ohne zweite Injektion.

### Rücksetzen
- Erfolgreiche PIN-Eingabe → Zähler, `lockedUntil` löschen.
- Erfolgreicher Wiederherstellungscode → Zähler zurücksetzen (Nutzer setzt danach ohnehin neue PIN).
- Erfolgreiches `setPinWithRecoveryCode` (neue PIN, aus Settings oder PIN-Vergessen) und `clearPin`/Deaktivieren → Zähler zurücksetzen (der Akteur ist bereits entsperrt bzw. hat Identität bewiesen). `setPin` allein ebenfalls (Legacy/Tests), Konsistenz im Plan festlegen.
- Biometrie: Fehlschlag zählt NICHT (das Betriebssystem hat eigenes Lockout, `biometricOnly: true`). Erfolgreiche Biometrie entsperrt und setzt den Zähler zurück (Besitznachweis).

### Google-Re-Auth
- Re-Auth ist ein eigener, vom Konto geschützter Identitätsnachweis und kein PIN-Raten; sie zählt nicht und bleibt auch während der Sperre benutzbar (sonst Aussperrung eines legitimen Nutzers ohne Code). Das ist keine Umgehung des Zählers, weil Google-Zugangsdaten (nicht die PIN) nötig sind; nach Erfolg muss ohnehin eine neue PIN samt neuem Code gesetzt werden (Zähler dort zurückgesetzt).
- Restrisiko: Auf einem entsperrten Gerät mit bereits angemeldetem Google-Konto kann der Chooser ohne Passwort durchlaufen (Geräteabhängigkeit, Google-Verhalten). Das war bereits in #288 so entschieden; nicht Teil von #358, aber hier festzuhalten.

### UI
- `AppLockScreen`: bei aktiver Sperre `TextField` und „Entsperren" deaktiviert (`enabled: false`/`onPressed: null`), Countdown-Text „Zu viele Fehlversuche. Versuche es in {mm:ss} erneut." als `errorText` bzw. eigener Text; `Timer.periodic(1s)` basierend auf Service-`remaining`, nicht auf eigener Subtraktion; Timer in `dispose` abbrechen. Nach Ablauf Feld wieder aktivieren und Fokus setzen.
- Beim Öffnen des Screens (App-Neustart während Sperre) wird der Zustand aus dem Service gelesen und der Countdown läuft weiter; sofortiger Biometrie-Versuch bleibt (zählt nicht).
- `ForgotPinDialog`: Code-Feld + „PIN zurücksetzen" deaktiviert mit gleichem Countdown, Re-Auth-Button unabhängig. Wegen Dialog-Neuöffnen ist der persistente Zähler entscheidend.
- Screenreader: Countdown in `Semantics(liveRegion: true)`, aber nicht jede Sekunde ansagen (Throttle: z. B. nur beim Start und bei 10-s-Schritten/Ablauf); deaktiviertes Feld mit erklärendem Label.
- Neue ARB-Keys (DE duzen, mit `@key`-Beschreibung, EN spiegelbildlich), z. B. `appLockTooManyAttempts` mit Platzhalter `{time}`, `appLockTryAgainSemantics`. Zeitformat über Platzhalter/`DateFormat` locale-sicher (`mm:ss`). `AppLockService` bleibt textfrei (CLAUDE.md): liefert nur `Duration`.
- Flutter-Teststabilität: Countdown-Timer in Widget-Tests mit `tester.pump(Duration)`; kein `pumpAndSettle` bei laufendem periodischen Timer (hängt/Timeout).

### Mehrfach-Instanzen / Race
- Dart ist single-threaded pro Isolate, die App läuft in einem Prozess; keine zwei parallelen `AppLockScreen`-Instanzen (ein Overlay im `builder`). Doppeltipp auf „Entsperren" während des `await` auf den Schreibvorgang: Eingabe/Button während einer laufenden Prüfung sperren (`_busy`), sonst können zwei Versuche mit demselben Zählerstand starten.
- Kein Mehrprozess-Zugriff (Android-Services/Widgets nutzen `app_lock_*` nicht). Prüfen, dass kein App-Widget/Isolate (Benachrichtigungen, Hintergrund) `AppLockService` instanziiert: Grep zeigt nur `appLockServiceProvider`. Mehrere `AppLockService`-Instanzen auf derselben `SharedPreferences` sind unkritisch (Cache geteilt).

## Datenfluss
`AppLockScreen._submitPin` → `AppLockService.attemptPin` (Zähler erhöhen + persistieren, Sperre prüfen, `verifyPin`, bei Erfolg zurücksetzen) → SharedPreferences. Analog `ForgotPinDialog._submitCode` → `attemptRecoveryCode`. Uhr: `clockProvider` + monotone Quelle injiziert in `appLockServiceProvider`. Kein Repository/UseCase/Backend beteiligt.

## Plattformübergreifend
Nur Mobile. Web hat die App-Sperre nicht (`kIsWeb` → nie gesperrt). Keine Firestore-Pfade, keine Security Rules, kein Backend. Kein `build_runner` nötig, falls kein neuer `@riverpod`-Provider entsteht (Uhr-Provider existiert, `appLockServiceProvider` ist ein manueller `Provider`). `flutter gen-l10n` nach ARB-Änderung.

## Bestehende Tests / nötige Anpassungen
- `app_lock_service_test.dart`: reine Service-Tests auf `AppLockService(prefs:, localAuth:)`. Konstruktor muss abwärtskompatibel bleiben (optionale Uhr-Params mit Default `DateTime.now`/echte Stopwatch), sonst brechen alle 4 Testdateien. Neue Tests: Stufen, Persistenz nach „Neustart" (neuer Service auf gleichen prefs), Rückstellung der Uhr, gemeinsamer Zähler, Reset bei Erfolg/neuer PIN, Persist-before-verify.
- `app_lock_screen_test.dart`: `createSubject` baut `AppLockService` ohne Uhr; `'zeigt bei falscher PIN einen Fehler und behält den Fokus'` erwartet `Falsche PIN` — mit Stufe „1–2 frei" bleibt das gültig. Neue Tests: ab dem 3. Fehlversuch Feld deaktiviert + Countdown, Wiederaktivierung nach `pump(5s)`, Start mit gespeicherter Sperre.
- `forgot_pin_dialog_test.dart`: Falsche-Code-Tests bleiben; neue: Code-Feld deaktiviert bei Sperre, Re-Auth-Button bleibt aktiv, gemeinsamer Zähler mit PIN.
- `pin_setup_dialog_test.dart`: Zähler-Reset nach `setPinWithRecoveryCode`.
- Tests verwenden den echten `LocalAuthentication` (wirft `MissingPluginException`, wird abgefangen) — unverändert nutzbar.

## Offene Fragen (mit Empfehlung)
1. Stufen/Anzahl freier Versuche: Empfehlung 2 frei, dann 3–4 → 5 s, 5–6 → 30 s, ab 7 → 300 s (Deckel, kein weiteres Wachsen). Alternative näher am Issue: ab dem 1. Fehlversuch 5 s. Bitte bestätigen.
2. Verhalten bei erkannter Uhr-Rückstellung: Empfehlung: Sperre auf volle aktuelle Stufendauer neu setzen (kein dauerhaftes Aussperren). Alternative: Zähler eine Stufe höher. Toleranz 2 min?
3. Google-Re-Auth während Sperre erlaubt lassen (zählt nicht, Zähler wird erst durch neues PIN-Setzen zurückgesetzt)? Empfehlung: ja.
4. Biometrie-Erfolg setzt den Zähler zurück, Fehlschläge zählen nicht? Empfehlung: ja.
5. Neue asynchrone API `attemptPin`/`attemptRecoveryCode` (Persist-before-verify) statt `verifyPin` zu erweitern; `verify*` bleiben ungezählt. Einverstanden? Empfehlung: ja.
6. Uhr-Injektion: `clockProvider` aus #279 (Issue nennt #368 irrtümlich) wiederverwenden + zweite Injektion `monotonic` (Stopwatch) im Service-Konstruktor? Empfehlung: ja; kein Plattform-Channel/Plugin für `elapsedRealtime`.
7. Zähler-Reset beim Deaktivieren der Sperre (`setEnabled(false)`) und bei `clearPin`? Empfehlung: ja bei `setPinWithRecoveryCode`/`clearPin`; bei `setEnabled` nicht nötig (nur im entsperrten Zustand erreichbar).
8. Ob der Countdown für Screenreader nur beim Start/Ablauf angesagt wird (Empfehlung) oder regelmäßig (alle 10 s).
9. Soll nach App-Neustart während der Sperre Biometrie sofort wieder angeboten werden? Empfehlung: ja (zählt nicht, OS hat eigenes Lockout).

## Risiken
- Zurückstellen der Uhr: nur teilweise abdeckbar; Vorstellen der Uhr (Sperre läuft früher ab) nicht erkennbar offline. Restrisiko dokumentieren.
- Aussperrung des legitimen Nutzers durch erkannte „Rückstellung" nach Zeitzonen-/NTP-Korrektur oder Dual-Boot/Emulator → Toleranz + volle Stufendauer (nicht dauerhaft) abfedert das.
- Hartes Beenden zwischen Versuch und Schreibvorgang → Persist-before-verify löst das, kostet eine `await`-Verzögerung (SharedPreferences-Schreiben, im ms-Bereich).
- Bestehende Tests: ~25 synchrone Aufrufe von `verifyPin`/`verifyRecoveryCode` bleiben nur kompatibel, wenn diese Methoden ungezählt bestehen bleiben.
- Periodischer Timer in Widget-Tests (`pumpAndSettle` hängt) — Timer nur bei aktiver Sperre starten.
- Android-Backup/App-Daten löschen setzt den Zähler (und die PIN) zurück: OS-Ebene, außerhalb des Scopes (`allowBackup` im Manifest nicht geprüft; ggf. separat klären, ob prefs im Auto-Backup landen — würde Zähler-Restore ermöglichen).
- Datenmigration: keine nötig; fehlende Keys = 0 Fehlversuche.

## Entscheidungen zu den offenen Fragen (Hauptsession)

Alle Empfehlungen übernommen: (1) 2 Fehlversuche frei, 3–4 → 5 s, 5–6 → 30 s, ab 7 → 300 s (Deckel); (2) Uhr zurückgestellt (`now < lastSeen - 2 min`) → volle aktuelle Stufendauer neu setzen, Vorstellen der Uhr bleibt dokumentiertes Restrisiko; (3) Google-Re-Auth bleibt während der Sperre nutzbar und zählt nicht (führt zwingend zu `PinSetupDialog`, d. h. nur der Kontoinhaber kommt so durch); (4) Biometrie-Erfolg setzt den Zähler zurück, Fehlschläge zählen nicht; (5) neue asynchrone `attemptPin`/`attemptRecoveryCode` mit Persist-before-verify, `verifyPin`/`verifyRecoveryCode` bleiben ungezählt, Service-Konstruktor abwärtskompatibel; (6) `clockProvider` (aus #279) plus zweite Injektion für die monotone Quelle (`Stopwatch`), kein Plattform-Channel/Plugin; (7) Reset bei `setPinWithRecoveryCode` und `clearPin`, nicht bei `setEnabled`; (8) Screenreader: Countdown nur bei Start und Ablauf ansagen; (9) Biometrie nach App-Neustart während der Sperre sofort wieder anbieten. Zusätzlich im Plan prüfen: Android `allowBackup`/Auto-Backup (`mobile/android/app/src/main/AndroidManifest.xml`, ggf. `fullBackupContent`/`dataExtractionRules`) — falls SharedPreferences im Backup landen, kann ein Restore den Zähler zurücksetzen; Ergebnis dokumentieren, Änderung nur vorschlagen, wenn klein und sicher (sonst Folge-Issue). Korrektur: `clockProvider` stammt aus #279/#368-Umfeld, das Issue nennt #368 irrtümlich.
