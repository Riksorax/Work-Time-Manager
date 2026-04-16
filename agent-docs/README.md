# Work-Time-Manager — Angular Web Version
## Agent-Plan Master-Dokument

---

## Übersicht

Dieses Repository enthält den vollständigen Agent-Plan zum Aufbau der Angular Web-Version des Work-Time-Managers. Jeder Agent ist eine eigenständige Aufgabeneinheit die von Claude Code ausgeführt werden kann.

### Projekt-Links
- **Flutter App (Quelle):** https://github.com/Riksorax/Work-Time-Manager
- **Angular Web (Ziel):** separates Repo oder `/angular-web` Subfolder
- **Domain:** `app.work-time-manager.app`

---

## Agents im Überblick

| # | Agent | Datei | Status |
|---|---|---|---|
| 00 | Flutter Analyst | `AGENT-00-analyst.md` | ⬜ |
| 01 | Architect | `AGENT-01-architect.md` | ⬜ |
| 02 | Security | `AGENT-02-security.md` | ⬜ |
| 03 | Core / Foundation | `AGENT-03-core.md` | ⬜ |
| 04 | Auth Feature | `AGENT-04-auth.md` | ⬜ |
| 05 | Time Tracking ⭐ | `AGENT-05-time-tracking.md` | ⬜ |
| 06 | Reports | `AGENT-06-reports.md` | ⬜ |
| 07 | Premium / RevenueCat | `AGENT-07-premium.md` | ⬜ |
| 08 | Notifications | `AGENT-08-notifications.md` | ⬜ |
| 09 | Settings & Profile | `AGENT-09-settings.md` | ⬜ |
| 10 | Testing | `AGENT-10-testing.md` | ⬜ |
| 11 | CI/CD & Deployment | `AGENT-11-cicd.md` | ⬜ |

---

## Abhängigkeitsreihenfolge

```
00 (Analyst)
 └─► 01 (Architect)
       └─► 02 (Security)     ← muss vor allen Features fertig sein
       └─► 03 (Core)         ← muss vor allen Features fertig sein
             ├─► 04 (Auth)
             ├─► 05 (Time Tracking) ⭐ Kritischer Pfad
             │     └─► 06 (Reports)
             ├─► 07 (Premium)       ← vor 06 und 09 starten
             ├─► 08 (Notifications)
             └─► 09 (Settings)
                   └─► 10 (Testing)
                         └─► 11 (CI/CD)
```

**Parallel startbar nach 02 + 03:** Agents 04, 05, 07, 08

---

## Bereits implementierte Dateien (Scaffold)

Die folgenden Dateien sind bereits als Vorlage vorhanden (aus der initialen Scaffold-Erstellung) und müssen von den Agents angepasst/erweitert werden:

```
agent-docs/AGENT-00-flutter-analysis-report.md    ← Aus GitHub-Analyse erstellt
src/app/app.config.ts                  ← Vollständig
src/app/app.routes.ts                  ← Vollständig
src/app/core/auth/auth.service.ts      ← Vollständig
src/app/core/auth/auth.guard.ts        ← Vollständig
src/app/core/auth/auth.interceptor.ts  ← Vollständig
src/app/core/security/premium.guard.ts ← Vollständig
src/app/core/notifications/notification.service.ts ← Vollständig
src/app/shared/models/index.ts         ← Vollständig
src/app/features/time-tracking/utils/time-calculations.util.ts ← Vollständig
src/app/features/time-tracking/utils/time-calculations.util.spec.ts ← Vollständig
src/app/features/time-tracking/services/work-session.service.ts ← Vollständig
src/app/features/reports/services/report.service.ts ← Vollständig
src/app/features/premium/services/premium.service.ts ← Vollständig (RevenueCat Web Billing)
src/app/features/settings/services/user-profile.service.ts ← Vollständig
src/assets/i18n/de.json                ← Vollständig
src/environments/environment.ts        ← Template (Werte eintragen)
src/environments/environment.prod.template.ts ← CI/CD Template
firestore.rules                        ← Vollständig
nginx.conf                             ← Vollständig (mit CSP)
Dockerfile                             ← Vollständig
docker-compose.yml                     ← Vollständig
.github/workflows/deploy.yml           ← Vollständig
package.json                           ← Vollständig
SETUP.md                               ← Schritt-für-Schritt Setup-Guide
```

---

## Noch zu implementieren (Komponenten)

Diese Dateien müssen noch von den Agents erstellt werden:

**Agent 01:**
- `angular.json`, `tsconfig.json`, `src/main.ts`, `src/app/app.component.ts`
- `src/styles/theme.scss`

**Agent 03:**
- `src/app/shared/pipes/duration.pipe.ts`
- `src/app/shared/pipes/overtime.pipe.ts`
- `src/app/shared/components/loading-spinner/`
- `src/app/shared/components/confirm-dialog/`
- `src/app/shared/components/premium-gate/`
- `src/app/shared/components/toast/toast.service.ts`
- `src/app/layout/shell/`
- `src/app/layout/sidebar/`
- `src/assets/i18n/en.json`

**Agent 04:**
- `src/app/features/auth/components/auth-layout/`
- `src/app/features/auth/components/login/`
- `src/app/features/auth/components/register/`
- `src/app/features/auth/components/forgot-password/`

**Agent 05:**
- `src/app/features/time-tracking/components/dashboard/`
- `src/app/features/time-tracking/components/live-timer/`
- `src/app/features/time-tracking/components/session-list/`
- `src/app/features/time-tracking/components/session-detail/`

**Agent 06:**
- `src/app/features/reports/components/reports-overview/`
- `src/app/features/reports/components/monthly-report/`
- `src/app/features/reports/components/yearly-report/`
- `src/styles/print.scss`

**Agent 07:**
- `src/app/features/premium/components/paywall/`

**Agent 08:**
- `public/firebase-messaging-sw.js` ← Template vorhanden
- `src/app/features/notifications/components/notification-settings/`

**Agent 09:**
- `src/app/features/settings/services/work-profile.service.ts`
- `src/app/features/settings/components/profile/`
- `src/app/features/settings/components/app-settings/`
- `src/app/features/settings/components/profiles/`

**Agent 10:**
- Alle fehlenden `.spec.ts` Dateien
- `src/testing/test-helpers.ts`

---

## Wie man einen Agent ausführt (mit Claude Code)

```bash
# Beispiel: Agent 05 ausführen
claude "Lies AGENT-05-time-tracking.md und implementiere alle beschriebenen Dateien.
        Nutze dabei die bereits vorhandenen Dateien als Referenz (models, utils).
        Fange mit time-calculations.util.ts an und schreibe dann den WorkSessionService."
```

Oder im Claude Code Interactive Mode:
```
> /read AGENT-05-time-tracking.md
> Implementiere jetzt alle Aufgaben aus diesem Agent-Dokument.
```

---

## RevenueCat Web Billing — Wichtige Hinweise

- **Separater API Key:** Web Billing nutzt einen anderen API Key als die Flutter-App
- **Gleiche User-ID:** Firebase UID als `appUserId` → Cross-Platform Entitlements
- **Stripe erforderlich:** RevenueCat Web Billing benötigt einen verbundenen Stripe Account
- **Test-Karten:** Im Sandbox-Modus: `4242 4242 4242 4242`, beliebiges Datum, beliebiger CVC
- **Apple Pay / Google Pay:** Können in RevenueCat Dashboard aktiviert werden (optionale Erweiterung)
- **Keine Gebühren von RevenueCat:** Nur Stripe-Transaktionsgebühren (~1.5% EU, ~2.9% US)

---

## Bekannte Bugs (aus Flutter-Issues, in Angular von Anfang an korrekt lösen)

| Issue | Bug | Lösung |
|---|---|---|
| #108 | Fehler beim Löschen der Arbeitszeiten | `try/catch` in `deleteSession()` mit sprechender Fehlermeldung |
| #107 | Einstellungen-Trennung unklar | Separate Routen: `/settings/profile` vs `/settings/app` |
| #113 | Accessibility im Kalender | `aria-label` und `role` korrekt setzen beim DateRangePicker |
