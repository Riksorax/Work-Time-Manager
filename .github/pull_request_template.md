## Zusammenfassung

<!-- Was ändert sich und warum? -->

Schließt #

<!-- GitHub erkennt nur englische Schlüsselwörter für das automatische Schließen beim Merge
     ("Closes"/"Fixes"/"Resolves" + #<Nummer>) — "Schließt #<Nummer>" allein reicht nicht.
     Nummer oben ausfüllen und hier identisch übernehmen, sonst bleibt das Issue offen. -->
Closes #

## Plattformen

- [ ] Mobile
- [ ] Web
- [ ] Backend
- [ ] CI / Infrastruktur

## Änderungen

-

## Tests

<!-- Neue/geänderte Tests und lokal ausgeführte Checks. -->

- [ ] `mobile/`: `flutter analyze --no-fatal-infos`, `dart run custom_lint`, `flutter test`
- [ ] `web/`: `npm test -- --watch=false`, `npm run build -- --configuration production`
- [ ] `server/`: `dotnet build` und `dotnet test`

## Checkliste

- [ ] Ziel-Branch ist `develop` (Release-PRs: `main`)
- [ ] Texte in Deutsch und Englisch (ARB bzw. `public/i18n/*.json`)
- [ ] Premium-Gate geprüft
- [ ] Arbeitszeit-Profile berücksichtigt (`profileId`)
- [ ] Rechenlogik stimmt mit dem Backend überein
- [ ] `CLAUDE.md` bzw. Plattform-Doku aktualisiert, falls nötig

## Manuelle Schritte nach dem Merge

<!-- z. B. `firebase deploy --only firestore:rules`, neue Secrets, Play-Console-Track. Sonst „keine“. -->

keine
