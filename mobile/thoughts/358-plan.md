# Mobile-Plan: #358 — App-Sperre: Brute-Force-Limit für PIN- und Wiederherstellungscode-Eingabe
Research: mobile/thoughts/358-research.md (inkl. Abschnitt „Entscheidungen zu den offenen Fragen")

## Ziel
Fehlversuche bei PIN (`AppLockScreen`) und Wiederherstellungscode (`ForgotPinDialog`) werden über einen gemeinsamen, persistenten Zähler begrenzt: 2 Versuche frei, dann 5 s / 30 s / 300 s (Deckel) Wartezeit. Der Schutz hält Neustart, Hard-Kill und zurückgestellte Uhr stand, UI zeigt Countdown, Texte DE/EN.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | Keine Entity. Neue reine Dart-Datei `domain/utils/app_lock_lockout.dart` mit Stufenfunktion `lockoutDurationFor(int failedAttempts)`, Konstanten (`freeAttempts = 2`, Toleranz 2 min), Ergebnistyp `AttemptResult` (`AttemptSuccess` / `AttemptWrong(remaining)` / `AttemptLocked(remaining)`) und Formatter `formatLockoutCountdown(Duration)` (`mm:ss`) | Stufenlogik als reine Funktion ist ohne Prefs/Uhr testbar; Service bleibt textfrei (nur `Duration`) |
| Stufen | Zähler nach Inkrement: 1–2 → 0 s, 3–4 → 5 s, 5–6 → 30 s, ab 7 → 300 s (Deckel, jeder weitere Fehlversuch wieder 300 s). Kein Reset durch Zeitablauf | Entscheidung (1) |
| Repository-Interface ändern? | Nein. Kein Repository/UseCase/Backend. Nur `AppLockService` (`core/services`) | Datenfluss nur Prefs |
| Service-API | Neu: `Future<AttemptResult> attemptPin(String)`, `attemptRecoveryCode(String)`, `Duration get remainingLockout` (synchron, rein lesend), `Future<Duration> syncLockout()` (Uhr-Abgleich beim Screen-Öffnen, schreibt ggf.), `Future<void> resetAttempts()`. `verifyPin`/`verifyRecoveryCode` bleiben unverändert und ungezählt (~25 Testaufrufe bleiben gültig) | Entscheidung (5) |
| Persist-before-verify | `attempt*`: (1) Sperre prüfen, falls aktiv → `AttemptLocked`, kein Zählen; (2) Zähler+1, `lockedUntil`, `lastSeen` per `await Future.wait` schreiben; (3) erst dann `verify*`; Erfolg → `resetAttempts()`, Fehler → `AttemptWrong(remaining)` | Hard-Kill nach dem Tippen darf den Versuch nicht verlieren |
| Persistenz-Keys | `app_lock_failed_attempts` (int), `app_lock_locked_until_ms` (int, UTC-Epoch ms), `app_lock_last_seen_ms` (int, höchste je beobachtete UTC-Wanduhr). Global, ohne uid/profileId (App-Sperre ist gerätebezogen). Fehlende Keys = 0 Versuche, keine Migration. `resetAttempts` entfernt Zähler und `lockedUntil`, behält `lastSeen` | Konsistent zu `app_lock_*`; `lastSeen` darf nach Reset nicht fallen |
| Uhr-Injektion | Konstruktor-Parameter `DateTime Function() now` (Default `DateTime.now`) und `Duration Function() monotonic` (Default: `Stopwatch`, im Service gestartet), beide optional → abwärtskompatibel. `appLockServiceProvider` reicht `ref.watch(clockProvider)` als `now` durch. Intern immer `now().toUtc().millisecondsSinceEpoch` | Entscheidung (6). Zeitzonenwechsel unkritisch. Kein Plugin/Channel |
| Monotone Quelle | Im laufenden Prozess zählt `remainingLockout` ab Lock-Start über `monotonic()` (Session-Felder `_sessionLockStart/_sessionLockDuration`); ohne Session-Lock (Neustart) über Wanduhr `lockedUntil - now` | Immun gegen Uhr-Umstellen während der Sitzung |
| Uhr-Rückstellung | In `syncLockout()`/`attempt*` bei Wanduhrpfad: `now < lastSeen - 2 min` → `lockedUntil = now + lockoutDurationFor(failedAttempts)` (volle aktuelle Stufendauer, nicht 0, nicht dauerhaft), danach `lastSeen = now` (neue Basis, sonst Dauer-Re-Lock). Das begrenzt zugleich einen versehentlich in die Zukunft geschriebenen `lockedUntil` (falsch vorgestellte Uhr, später korrigiert) auf eine Stufendauer. Vorstellen der Uhr bleibt dokumentiertes Restrisiko | Entscheidung (2) |
| Re-Auth | Unverändert, zählt nicht, bleibt in der Sperre nutzbar; führt nur zu `PinSetupDialog` → `setPinWithRecoveryCode` → Reset | Entscheidung (3) |
| Biometrie | Fehlschlag zählt nicht; Erfolg in `AppLockScreen._tryBiometrics` ruft `resetAttempts()` vor `_unlock()`. Nach Neustart während Sperre wird Biometrie weiter sofort angeboten (bestehender `postFrameCallback`) | Entscheidungen (4), (9) |
| Reset-Punkte | `attempt*`-Erfolg, Biometrie-Erfolg, `setPin` (und damit `setPinWithRecoveryCode`), `clearPin`. Nicht `setEnabled` | Entscheidung (7); `setPin` im Service zu resetten deckt Legacy/Tests ab |
| Neuer Provider? | Nein. `appLockServiceProvider` ist ein manueller `Provider`, `clockProvider` existiert → **kein `build_runner` nötig** | Kein neues `@riverpod` |
| UI-Gemeinsamkeit | Neue Datei `presentation/widgets/lockout_countdown.dart`: Mixin `LockoutCountdownMixin<T extends ConsumerStatefulWidget>` (Timer.periodic 1 s nur bei aktiver Sperre, liest `service.remainingLockout`, Cancel in `dispose`) und Widget `LockoutNotice` (sichtbarer Text + Semantics) | Vermeidet Duplikat in Screen und Dialog |
| Screenreader | Sichtbarer Countdown in `ExcludeSemantics`; separater `Semantics(liveRegion: true, label: …)`, dessen Label sich nur bei Sperrstart (`appLockTryAgainSemanticsSeconds/Minutes`) und Ablauf (`appLockRetryNow`) ändert, sonst leer | Entscheidung (8), keine Sekundenansage, keine Announce-API nötig |
| Doppeltipp | `_busy` in Screen und Dialog (Code-Absenden getrennt vom `_busy` der Re-Auth: neues `_submitting`); Feld/Button währenddessen deaktiviert | Zwei Versuche mit gleichem Zählerstand verhindern |
| Premium-Gate? | Nein | Sicherheitsfunktion, kein Premium-Feature |
| Pro Arbeitszeit-Profil? | Nein, gerätebezogen | Keys ohne profileId |
| Backend-Änderung nötig? | Nein. Keine Firestore-Pfade, keine Rules, Web hat keine App-Sperre | |
| Neue Texte? | ARB de (duzen) + en, siehe Schritt 5 (wird aus Compile-Gründen vor den Widget-Implementierungen in Schritt 4 erledigt) | |
| Android-Backup | Geprüft: `AndroidManifest.xml` hat weder `allowBackup`, `fullBackupContent` noch `dataExtractionRules` (Grep über `mobile/android` ohne Treffer) → Android-Default `allowBackup=true`, `FlutterSharedPreferences.xml` (PIN-Hash, Zähler) landet im Auto-Backup. Ein Restore kann den Zähler auf einen alten Stand setzen. **Keine Änderung in #358**: Ausschluss der Prefs-Datei würde auch Einstellungen/lokale Einträge aus dem Backup nehmen (Regression), eine eigene Prefs-Datei verstößt gegen die „nur Provider-Override"-Regel. Ergebnis im PR dokumentieren, Folge-Issue vorschlagen (z. B. Sperr-Keys per `dataExtractionRules` selektiv ausschließen oder Secure Storage, vgl. Nicht-Ziele) | Entscheidung der Hauptsession: nur vorschlagen, wenn klein und sicher |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `mobile/lib/domain/utils/app_lock_lockout.dart` | neu | `lockoutDurationFor`, Konstanten, `AttemptResult`, `formatLockoutCountdown` |
| `mobile/lib/core/services/app_lock_service.dart` | geändert | Keys, Uhr-/Monotonic-Injektion, `attemptPin`/`attemptRecoveryCode`, `remainingLockout`, `syncLockout`, `resetAttempts`; Reset in `setPin`/`clearPin` |
| `mobile/lib/core/providers/app_lock_provider.dart` | geändert | `now: ref.watch(clockProvider)` in `appLockServiceProvider` (Import `clock_provider.dart`) |
| `mobile/lib/presentation/widgets/lockout_countdown.dart` | neu | Mixin + `LockoutNotice` (Countdown, Semantics) |
| `mobile/lib/presentation/widgets/app_lock_screen.dart` | geändert | `attemptPin`, `_busy`, deaktiviertes Feld/Button, `FocusNode`, Countdown, Biometrie-Reset |
| `mobile/lib/presentation/widgets/forgot_pin_dialog.dart` | geändert | `attemptRecoveryCode`, `_submitting`, Code-Feld/Button deaktiviert in Sperre, Re-Auth unabhängig |
| `mobile/lib/l10n/app_de.arb`, `app_en.arb` | geändert | Neue Keys (+ `@key` in DE), generierte `app_localizations*.dart` per `flutter gen-l10n` (nicht editieren) |
| `mobile/test/domain/utils/app_lock_lockout_test.dart` | neu | Stufenfunktion, Formatter |
| `mobile/test/core/services/app_lock_service_test.dart` | geändert | Neue Gruppen (Fake-Uhr, Recording-Prefs) |
| `mobile/test/core/providers/app_lock_provider_test.dart` | neu oder erweitert (vorhandene Datei zuerst prüfen) | Provider nutzt `clockProvider` |
| `mobile/test/presentation/widgets/app_lock_screen_test.dart` | geändert | Countdown-/Sperr-Tests |
| `mobile/test/presentation/widgets/forgot_pin_dialog_test.dart` | geändert | Sperre, gemeinsamer Zähler, Re-Auth |
| `mobile/test/presentation/widgets/pin_setup_dialog_test.dart` | geändert | Zähler-Reset |
| `mobile/test/presentation/widgets/lockout_countdown_test.dart` | neu | `LockoutNotice` Semantics (falls nicht über Screen-Tests abgedeckt) |
| Keine Änderung | — | `pin_setup_dialog.dart`, `settings_page.dart`, `main.dart`, `AndroidManifest.xml` |

Test-Hilfen (in den Testdateien, keine Generierung): `FakeClock` (veränderbare `DateTime.utc(2026, 1, 15, 12)`-Basis, `advance(Duration)`, `set(DateTime)`), `FakeMonotonic` (veränderbare `Duration`), `RecordingSharedPreferences` (implementiert `SharedPreferences` per Delegation an echte Mock-Prefs, protokolliert Aufrufreihenfolge, optional wirft `getString('app_lock_pin_hash')` als simulierter Hard-Kill). Alle Zeiten fest oder relativ zur Fake-Uhr, nie `DateTime.now()`.

## Schritte (TDD — jeder Schritt beginnt mit dem Test, erst rot, dann Impl)

### Schritt 1: Domain (`lib/domain/utils/app_lock_lockout.dart`)
- [x] Test `test/domain/utils/app_lock_lockout_test.dart` (rot, Datei fehlt):
  - `lockoutDurationFor`: 0,1,2 → `Duration.zero`; 3,4 → 5 s; 5,6 → 30 s; 7,8,50 → 300 s (Deckel, wächst nicht); negative Werte → zero.
  - `formatLockoutCountdown`: 5 s → `00:05`, 65 s → `01:05`, 300 s → `05:00`, 0 → `00:00`, 4,2 s wird aufgerundet auf `00:05` (Sekunden aufrunden, damit nie `00:00` bei aktiver Sperre).
  - `AttemptResult`-Varianten tragen `remaining`.
- [x] Impl: reine Funktionen/Typen, keine Flutter-Imports.

### Schritt 2: Service (`core/services`, Ebene „Data" dieses Features)
- [x] Tests in `app_lock_service_test.dart`, neue Gruppe `Brute-Force-Limit` (alle rot, bestehende Tests müssen unverändert grün bleiben):
  - Stufen: Fehlversuch 1 und 2 → `AttemptWrong` mit `remaining == zero`; 3 → `remaining 5 s`; Fake-Uhr +5 s → 4. Versuch erlaubt → 5 s; 5. → 30 s; 7. → 300 s; 8. → 300 s (Deckel).
  - Während Sperre: `attemptPin` mit richtiger PIN → `AttemptLocked`, Zähler unverändert, kein Entsperren (auch korrekte PIN abgelehnt).
  - Nach Ablauf (`clock.advance`) richtige PIN → `AttemptSuccess`, Zähler 0, `app_lock_locked_until_ms` entfernt.
  - Zähler wird durch Zeitablauf allein nicht zurückgesetzt (nach 5 s Wartezeit bleibt `failed_attempts == 3`).
  - Persist-before-verify: `RecordingSharedPreferences`-Protokoll zeigt `setInt(app_lock_failed_attempts, 1)` vor dem ersten `getString(app_lock_pin_hash)`; zusätzlich Hard-Kill-Test: `getString(pin_hash)` wirft → `attemptPin` wirft, neuer Service auf denselben Prefs sieht Zähler 1 (und bei Versuch 3 die 5-s-Sperre).
  - Gemeinsamer Zähler: 2× `attemptPin` falsch + 1× `attemptRecoveryCode` falsch → 5-s-Sperre; umgekehrt ebenso; Sperre blockiert beide Methoden.
  - `attemptRecoveryCode` Erfolg setzt Zähler zurück; `attemptPin` mit nicht gesetzter PIN zählt trotzdem (kein Orakel „keine PIN").
  - Reset: `setPinWithRecoveryCode`, `setPin`, `clearPin` setzen Zähler und `lockedUntil` zurück (vorher auf Zähler 7 gesetzt); `setEnabled` ändert nichts; `resetAttempts()` (Biometrie-Pfad) → Zähler 0, `remainingLockout == zero`, `lastSeen` bleibt erhalten.
  - Neustart während Sperre: neuer `AppLockService` auf denselben Prefs, `FakeMonotonic` bei 0 → `syncLockout()` liefert Restdauer `lockedUntil - now`; nach `clock.advance` entsprechend weniger; nach Ablauf `zero`.
  - Session-Monotonic: Uhr wird während laufender Sperre per `clock.set` zurückgestellt (−1 h) → `remainingLockout` richtet sich weiter nach `monotonic` (fällt nur mit `FakeMonotonic.advance`, nicht mit Wanduhr).
  - Uhr-Rückstellung nach Neustart: Zähler 5 (30 s), `lastSeen` = T, neuer Service, `clock.set(T − 10 min)` → `syncLockout()` = volle 30 s (nicht 0, nicht 10 min); `lastSeen` danach neu gesetzt, ein zweiter `syncLockout()` triggert nicht erneut (kein Dauer-Re-Lock).
  - Toleranz: `clock.set(T − 90 s)` (< 2 min) gilt nicht als Rückstellung → normale Restdauer.
  - Zukunfts-`lockedUntil` (Uhr war weit vorgestellt, jetzt korrigiert) wird per Rückstellungs-Erkennung auf die Stufendauer begrenzt.
  - Uhr vorwärts: Sperre läuft früher ab (dokumentiertes Restrisiko, Test fixiert das Verhalten als Absicht, Kommentar im Test).
  - UTC/Zeitzone: gleiche Zeit als `DateTime.utc` und als `.toLocal()` geliefert → identische gespeicherte ms; Test läuft unter `TZ=Europe/Berlin` und `TZ=UTC` identisch.
  - Fehlende Keys → `remainingLockout == zero`, kein Fehler (keine Migration).
  - Konstruktor ohne `now`/`monotonic` kompiliert weiterhin (bestehende Tests als Beweis).
- [x] Impl in `app_lock_service.dart` (siehe Entscheidungen). `remainingLockout` rein lesend; Schreibzugriffe nur in `attempt*`, `syncLockout`, `resetAttempts`, `setPin`, `clearPin`. Keine Texte, kein `logger`-Output mit PIN/Code.

### Schritt 3: Provider (`lib/core/providers/app_lock_provider.dart`)
- [x] Test: `ProviderContainer` mit `sharedPreferencesProvider`-Override und `clockProvider`-Override auf Fake-Uhr; 3 falsche `attemptPin` → `remainingLockout == 5 s`, nach `clock.advance` Zeit entsprechend (Wanduhrpfad via zweiten Container = „Neustart"). Rot, solange `appLockServiceProvider` die Uhr nicht nutzt.
- [x] Verdrahtung `now: ref.watch(clockProvider)`; `monotonic` bleibt Default. Kein `build_runner` (kein neuer `@riverpod`, `clock_provider.g.dart` unverändert).

### Schritt 4: Presentation
(4.0 vorab: ARB-Keys aus Schritt 5 + `flutter gen-l10n`, damit die Widgets kompilieren; der Test-Zyklus für die Texte selbst folgt unten.)
- [x] 4a Test `lockout_countdown_test.dart`: `LockoutNotice` zeigt `Zu viele Fehlversuche. Versuche es in 00:05 erneut.`; Sichtbarer Text hat keine Semantics-Ansage (`ExcludeSemantics`); Live-Region-Label erscheint nur bei Start, wechselt zu „Du kannst es jetzt erneut versuchen." bei Ablauf, ist dazwischen leer (Ticks ändern das Label nicht; `tester.getSemantics` vor/nach `pump(Duration(seconds: 1))`). Impl `lockout_countdown.dart`.
- [x] 4b `app_lock_screen_test.dart` (rot): Subject baut `AppLockService` mit `FakeClock`/`FakeMonotonic`; MaterialApp mit `AppLocalizations`-Delegates, `locale: Locale('de')`. Alle Wartezeiten per `tester.pump(Duration)`, **nie `pumpAndSettle`, solange der periodische Timer läuft** (Kommentar im Test).
  - Fehlversuch 1 und 2: `Falsche PIN`, Feld aktiv, kein Countdown, kein Timer (bestehender Test bleibt grün).
  - 3. Fehlversuch: `TextField.enabled == false`, „Entsperren" `onPressed == null`, Text mit `00:05`; „PIN vergessen" und Biometrie-Button bleiben aktiv.
  - Ticks: Fake-Uhr/-Monotonic `+1 s` + `pump(1 s)` → `00:04`; nach Ablauf (`+5 s`, `pump`) Feld wieder aktiv, Fokus liegt im Feld, Countdown weg, Timer beendet (`tester.pump` danach hängt nicht; `pumpAndSettle` ist dort wieder erlaubt).
  - Start mit gespeicherter Sperre (Prefs vorbefüllt, `lastSeen` gesetzt): Screen zeigt sofort Countdown mit Restzeit, Felder deaktiviert.
  - Uhr-Rückstellung bei Start: volle Stufendauer wird angezeigt.
  - Richtige PIN nach Ablauf entsperrt (`isAppLockedProvider == false`) und setzt Zähler zurück; während Sperre ist Eingabe nicht möglich (Enter im Feld ändert nichts).
  - Persist-before-verify im UI: Recording-Prefs-Protokoll, Zähler vor Hash-Lesen.
  - Doppeltipp: zweimal „Entsperren" in einem Frame (Prefs-Schreiben verzögert per `Completer`) → nur 1 Versuch gezählt (`failed_attempts == 1`), Button während `_busy` deaktiviert.
  - Biometrie-Erfolg (Fake `LocalAuthentication`/Service-Stub) → Zähler 0 + entsperrt; Biometrie-Fehlschlag zählt nicht.
  - Semantics: Ansage-Label nur bei Start/Ablauf (siehe 4a, hier integriert für den Screen).
  - Timer wird in `dispose` abgebrochen (Screen entfernen, `pump` mit Timer-Zeit wirft nicht, keine „Timer still pending"-Fehler am Testende).
- [x] Impl `app_lock_screen.dart`: Mixin einbinden, `FocusNode` (dispose), `_busy`, `_submitPin` async über `attemptPin`; `AttemptSuccess` → wie bisher `unfocus` + `_unlock` (Kommentar zu #337 behalten); `AttemptWrong` → `wrongPin`, Feld leeren, bei `remaining > 0` Countdown starten; `AttemptLocked` → Countdown aktualisieren; `mounted`-Checks nach jedem `await`; initState ruft `syncLockout()` und startet ggf. den Timer; `_tryBiometrics` ruft bei Erfolg `await resetAttempts()` vor `_unlock()`.
- [x] 4c `forgot_pin_dialog_test.dart` (rot): Falsche-Code-Tests bleiben; neu: Code-Feld und „PIN zurücksetzen" deaktiviert bei Sperre aus der PIN-Eingabe (gemeinsamer Zähler: Prefs mit Zähler 4 vorbefüllt, ein falscher Code → 5 → 30-s-Sperre? bzw. Zähler 2 + 1 falscher Code → 5 s), Countdown sichtbar; Dialog schließen und neu öffnen → Sperre besteht weiter (Persistenz); Re-Auth-Button bleibt aktiv, Tap liefert `true`, Zähler unverändert (Re-Auth zählt nicht); richtiger Code nach Ablauf → `pop(true)` und Zähler 0; `_submitting` verhindert Doppeltipp (1 Versuch gezählt); Abbrechen während Countdown räumt Timer auf; kein `pumpAndSettle` bei laufendem Timer.
- [x] Impl `forgot_pin_dialog.dart` analog.
- [x] 4d `pin_setup_dialog_test.dart`: Prefs mit Zähler 7 + `lockedUntil` vorbefüllt, erfolgreiches Setzen von PIN+Code → `failed_attempts`/`locked_until_ms` entfernt, `remainingLockout == zero`. (Service-Impl aus Schritt 2 genügt; Test grün ohne weitere Impl, daher gegen Schritt 2 vorab rot-prüfen, indem Impl-Zeile dort zuletzt hinzukommt.)

### Schritt 5: Texte (`app_de.arb` Template + `app_en.arb`)
- [x] Neue Keys (DE duzen, `@key`-Beschreibung nur in DE; EN gespiegelt):
  - `appLockTooManyAttempts`: „Zu viele Fehlversuche. Versuche es in {time} erneut." / „Too many failed attempts. Try again in {time}." (`time`: String, `mm:ss`)
  - `appLockTryAgainSemanticsSeconds`: ICU-Plural `{seconds, plural, one{Zu viele Fehlversuche. Versuche es in einer Sekunde erneut.} other{Zu viele Fehlversuche. Versuche es in {seconds} Sekunden erneut.}}` / EN `one{… in one second.} other{… in {seconds} seconds.}` (`seconds`: int)
  - `appLockTryAgainSemanticsMinutes`: analog mit `{minutes}` (für volle Minuten, z. B. 300 s → 5 Minuten)
  - `appLockRetryNow`: „Du kannst es jetzt erneut versuchen." / „You can try again now."
  - Vorhandene `wrongPin`, `wrongRecoveryCodeError` unverändert.
- [x] `flutter gen-l10n`. Test (in 4a/4b enthalten): DE und EN Locale rendern den Text, Plural 1 s / 5 s / 5 min korrekt (Auswahl Sekunden vs. Minuten über kleine Hilfsfunktion im Widget, getestet in 4a).

## Validierung
- `dart format --set-exit-if-changed lib test`
- `flutter analyze --no-fatal-infos`, `dart run custom_lint`
- `flutter test` (gesamt) und gezielt `TZ=Europe/Berlin flutter test test/domain/utils/app_lock_lockout_test.dart test/core test/presentation/widgets` sowie einmal mit `TZ=UTC` — Ergebnis muss identisch sein.
- Manuell (nur Hinweis für /mobile-validate): 3 Fehlversuche, App hart beenden, neu starten → Sperre läuft weiter; Uhr zurückstellen → Sperre ≥ Stufendauer; TalkBack: keine Sekundenansage.
- PR-Beschreibung: Restrisiken dokumentieren (Uhr vorstellen offline nicht erkennbar; Auto-Backup-Restore kann Zähler zurücksetzen, Folge-Issue vorschlagen; Google-Re-Auth-Chooser ohne Passwort auf entsperrtem Gerät, bereits in #288 entschieden).

## Offene Fragen
Keine blockierenden. Hinweis zur Freigabe: `setPin` setzt den Zähler ebenfalls zurück (Konsistenz-Entscheidung aus Research Punkt „im Plan festlegen"); Plan setzt „ja".
