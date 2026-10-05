# PR-Notizen #385 Teil 2: Fortsetzen (Web)

Commits (Branch claude/week-number-display-bug-x5xq8r): Utils, Dashboard-Service (todayIsEmpty + Pinning), OpenEntryService,
i18n, UI, Doku. Parität zu Mobile #422.

## Rot-Nachweise (Spec zuerst)
- Utils: TS2305 `canResumeOpenEntry` nicht exportiert.
- Dashboard-Service: TS2339 `todayIsEmpty` / `resumePastEntry` fehlen.
- OpenEntryService: TS2339 `canResume` / `resume` fehlen.
- Banner: TS2339 `resume` fehlt; dashboard.spec: 4 Fehlschläge (canResume-Bindung, Klick, busy, Fokus).
- i18n: Spec und JSON gleichzeitig angepasst (kein separater Rot-Lauf).

## Mutationen (alle rot, sofort zurückgesetzt)
- Schritt 1: `<=` -> `<`, todayIsEmpty ignorieren, Typfilter entfernen. (Tag aus date statt id nicht mutiert, vom id/date-Test abgedeckt.)
- Schritt 2: `_loadOk`-Prüfung entfernen -> Fehlerfall rot; Set(false) statt true am Ende -> 3 rot.
- Schritt 3: (a) Basis ohne storedBase, (b) date statt id-Tag (nur in America/Los_Angeles rot), (c) Regelprüfung im Service entfernen
  (2 rot, wird zusätzlich von der Frisch-Lesen-Validierung gehalten), (d) „heute leer" + Regel entfernen, (e) Frisch-Lesen-Validierung
  entfernen, (g) Pin-Read-Fehler in den äußeren catch, (h) Sofort-Tick weglassen: alle rot.
  **(f) überlebt:** der `_initGen`-Check direkt nach dem Pin-Read ist äquivalent, weil der nächste Check nach `getTodayEntry` denselben
  Fall fängt (er spart nur einen Read). Behalten, nicht eigens getestet.
- Schritt 4: canResume ohne todayIsEmpty, busy-Guard, epoch nach await, Neusuche, Kandidat nicht entfernen, Flash-Schutz,
  busy-Reset unbedingt (endEntry), Kontext-Reset von busy: rot. busy-Reset unbedingt in `resume` überlebte zuerst, dafür wurde ein
  eigener Test ergänzt (danach rot).
- Schritt 6: canResume-Bindung, (resume)-Bindung, [disabled] am Fortsetzen-Button, aria-label ohne Datum: rot.

## Checks
- Vollauf `npm test -- --watch=false`: Standard-TZ (UTC), Europe/Berlin, UTC, America/Los_Angeles, Pacific/Auckland: je 43 Dateien, 1043 Tests grün.
- `npm run build -- --configuration production`: grün.

## Abweichungen zum Plan
- Der Pin trägt nur die `id` (`pinned: { id }`), nicht den Eintrag; der Eintrag wird ohnehin frisch gelesen.
- `isExtraDay` ist am Service nicht öffentlich, die Tests prüfen Soll/Zusatztag über `dailyOvertime`.
- Ende-zu-Ende-Test liegt in `dashboard.resume.ui.spec.ts` (eigene Datei statt in dashboard.spec.ts); SCSS-Test per `getComputedStyle`
  (flex-wrap), Hex-Freiheit per grep geprüft (kein node:fs in den Test-Typen).
- Text-Button `mat-button` bekommt in der Banner-SCSS die Rollenfarbe (`on-secondary-container`) statt Primärfarbe.
- Bestands-i18n-Spec „keine weiteren Keys (kein Fortsetzen ...)" bewusst umgekehrt (Keys jetzt Teil der Liste).
- Manuelle Prüfliste und axe/320 px/200 % Zoom nicht lokal geprüft: in den PR-Body.
