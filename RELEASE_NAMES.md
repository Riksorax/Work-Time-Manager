# Release-Namen

Jedes Release im geschlossenen Test (Play-Track `alpha`) trägt den Namen
`<Version> <Charakter>` — der Charakter stammt aus Kingdom Hearts.

## Wie ein Name vergeben wird

Der Charakter kommt aus dem Namen des Release-Branches:

```
release/v1.3.2-Roxas          ->  Release-Name "1.3.2 Roxas"
release/v1.4.0-Micky-Maus     ->  Release-Name "1.4.0 Micky Maus"
```

Alles vor dem ersten `-` ist die Version, alles danach der Charakter;
Bindestriche im Charakternamen werden zu Leerzeichen.

`version-bump.yml` prüft beim Push auf den Release-Branch, ob der Charakter
unter „Noch frei" steht, verschiebt ihn nach „Vergeben" und committet das
zusammen mit der Versionsnummer. `flutter-production.yml` liest den Namen
später aus der Tabelle unten und übergibt ihn beim Play-Upload — der
Branch-Name ist zu diesem Zeitpunkt nicht mehr verfügbar, weil der Workflow
auf `main` läuft.

Steht der Charakter nicht in der Frei-Liste, bricht der Bump mit einer
Fehlermeldung ab. Namen werden also nie doppelt vergeben.

## Vergeben

| Version | Charakter | Datum |
| --- | --- | --- |
| 1.3.1 | — | 2026-08-21 |
| 1.1.0 | Micky Maus | 2026-05-25 |
| 1.0.0 | Sora | 2026-05-13 |
| 0.24.1 | Chirithy | 2026-03-15 |
| 0.13.3 | Xion | 2025-10-26 |
| 0.11.1 | Namine | 2025-10-26 |
| 0.06.0 | Ventus | 2025-10-21 |
| 0.05.0 | Terra | 2025-10-19 |
| 0.03.0 | Aqua | 2025-10-04 |
| 0.02.3 | Kairi | 2025-09-30 |
| 0.02.2 | Riku | 2025-09-30 |

> Die Einträge vor 1.3.1 sind aus der Play Console rekonstruiert. Zwischen
> Chirithy und Xion liegt mindestens ein weiteres Release (14.03.2026), dessen
> Name nicht ablesbar war — bitte bei Gelegenheit ergänzen und den betreffenden
> Charakter unten aus der Frei-Liste entfernen.
>
> 1.3.1 ging als „alpha" heraus, weil der Workflow damals noch keinen
> Release-Namen übergab. Genau das behebt diese Änderung.

## Noch frei

- Roxas
- Axel
- Lea
- Isa
- Saix
- Xemnas
- Xigbar
- Xaldin
- Vexen
- Lexaeus
- Zexion
- Larxene
- Marluxia
- Luxord
- Demyx
- Xehanort
- Ansem
- Vanitas
- Eraqus
- Ienzo
- Even
- Aeleus
- Dilan
- Braig
- Donald
- Goofy
- Minnie Maus
- Daisy
- Pluto
- Chip
- Chap
- Jiminy
- Yen Sid
- Merlin
- Cid
- Leon
- Yuffie
- Aerith
- Tifa
- Cloud
- Sephiroth
- Strelitzia
- Ephemer
- Skuld
- Lauriam
- Elrena
- Brain
- Ava
- Invi
- Gula
- Aced
- Ira
- Luxu
