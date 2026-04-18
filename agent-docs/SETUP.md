# Setup-Anleitung: Work-Time-Manager Angular Web

## Voraussetzungen
- Node.js (v20+)
- Angular CLI (`npm install -g @angular/cli`)
- Firebase Account

## Ordnerstruktur
```bash
work-time-manager/
├── mobile/                  # Bestehende Flutter App
├── web/                     # Neue Angular Web App (Agent-Ziel)
└── agent-docs/              # Dokumentation & Agent-Pläne
```

## Start der Entwicklung
1. **Agent 00** ausführen: `mobile/` analysieren.
2. `web/` Ordner initialisieren: `ng new work-time-manager-web`.
3. Firebase-Projekt in der Google Console anlegen.
4. `firestore.rules` aus Flutter-Projekt übernehmen und für Web anpassen.

---

## Roadmap
- [ ] Agent 00: Analyse abgeschlossen.
- [ ] Agent 01: Architektur steht.
- [ ] Agent 02-05: Features implementiert.
- [ ] Finaler UI Review.
