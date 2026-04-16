# Agent 11 — CI/CD & Deployment

## Rolle
Du baust die vollständige Build- und Deployment-Pipeline. Nach diesem Agent läuft jeder Push auf `main` automatisch als neues Docker-Image auf dem Hetzner-Server — via Traefik unter `app.work-time-manager.app`.

## Input
- `AGENT-00-flutter-analysis-report.md` (Infrastruktur: Port 8080, Traefik, Domain)
- `nginx.conf` von Agent 02 (Security-Header, CSP)
- Alle anderen Agent-Outputs

## Bestehende Infrastruktur (nicht ändern)

Aus dem Flutter docker-compose.yml:
- **Traefik** läuft bereits auf dem Hetzner-Server
- **Network**: `traefik-proxy` (external, bereits vorhanden)
- **Let's Encrypt**: `letsencrypt` als certresolver
- **Port intern**: `8080`
- **Flutter App**: läuft unter `work-time-manager.app`
- **Angular App**: läuft unter `app.work-time-manager.app` (Subdomain)

## Deine Aufgaben

### 11.1 Dockerfile

Datei: `Dockerfile`

Multi-Stage Build:
```dockerfile
# Stage 1: Node.js Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
# environment.prod.ts wurde bereits durch CI befüllt
RUN npm run build -- --configuration production

# Stage 2: nginx
FROM nginx:1.27-alpine AS production
COPY --from=builder /app/dist/work-time-manager-web/browser /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
```

**Wichtig:** Output-Pfad `dist/work-time-manager-web/browser` muss mit `angular.json → outputPath` übereinstimmen.

### 11.2 docker-compose.yml

Datei: `docker-compose.yml`

```yaml
services:
  work-time-manager-web:
    image: ghcr.io/riksorax/work-time-manager-web:${IMAGE_TAG:-latest}
    container_name: work-time-manager-web
    restart: unless-stopped
    networks:
      - traefik-proxy
    labels:
      - "traefik.enable=true"
      # HTTPS
      - "traefik.http.routers.wtm-web.rule=Host(`app.work-time-manager.app`)"
      - "traefik.http.routers.wtm-web.entrypoints=websecure"
      - "traefik.http.routers.wtm-web.tls.certresolver=letsencrypt"
      - "traefik.http.services.wtm-web.loadbalancer.server.port=8080"
      # HTTP → HTTPS Redirect
      - "traefik.http.routers.wtm-web-http.rule=Host(`app.work-time-manager.app`)"
      - "traefik.http.routers.wtm-web-http.entrypoints=web"
      - "traefik.http.routers.wtm-web-http.middlewares=https-redirect"

networks:
  traefik-proxy:
    external: true
```

### 11.3 GitHub Actions Pipeline

Datei: `.github/workflows/deploy.yml`

**3 Jobs:**

**Job 1: `build` (alle Branches)**
```
1. Checkout
2. Node 20 setup (mit npm cache)
3. npm ci
4. npm run test:ci  (schlägt fehl → Pipeline stoppt)
5. Falls main/develop:
   a. envsubst → environment.prod.ts befüllen
   b. envsubst → firebase-messaging-sw.js befüllen
   c. npm run build -- --configuration production
   d. Build-Artefakt hochladen (upload-artifact)
```

**Job 2: `docker` (nur main/develop, nach build)**
```
1. Build-Artefakt laden (download-artifact)
2. Docker Buildx setup
3. Login ghcr.io (GHCR_TOKEN)
4. Image-Tags via docker/metadata-action:
   - sha-<commit>
   - branch-name
   - latest (nur auf main)
5. docker/build-push-action (mit GHA Cache)
6. Output: image_tag
```

**Job 3: `deploy` (nur main, nach docker)**
```
1. SSH auf Hetzner (appleboy/ssh-action)
2. docker pull neue Image
3. export IMAGE_TAG=<sha-tag>
4. docker compose up -d --no-deps work-time-manager-web
5. docker image prune -f
6. Echo: Deployed successfully
```

**Job 4: `pr-check` (nur Pull Requests)**
```
1. npm ci
2. npm run test:ci
3. npm run lint
4. ng build --configuration development  (Syntax-Check ohne Secrets)
```

### 11.4 GitHub Secrets dokumentieren

Erstelle `AGENT-11-secrets.md`:

| Secret | Woher | Wo genutzt |
|---|---|---|
| `FIREBASE_API_KEY` | Firebase Console → Projekteinstellungen | environment.prod.ts, firebase-messaging-sw.js |
| `FIREBASE_AUTH_DOMAIN` | Firebase Console | environment.prod.ts |
| `FIREBASE_PROJECT_ID` | Firebase Console | environment.prod.ts |
| `FIREBASE_STORAGE_BUCKET` | Firebase Console | environment.prod.ts |
| `FIREBASE_MESSAGING_SENDER_ID` | Firebase Console | environment.prod.ts, firebase-messaging-sw.js |
| `FIREBASE_APP_ID` | Firebase Console | environment.prod.ts |
| `RECAPTCHA_SITE_KEY` | Google reCAPTCHA Console | environment.prod.ts |
| `REVENUECAT_WEB_BILLING_KEY` | RevenueCat Dashboard → Web Billing App | environment.prod.ts |
| `FCM_VAPID_KEY` | Firebase Console → Cloud Messaging → Web Push | environment.prod.ts |
| `GHCR_TOKEN` | GitHub → Settings → Developer Settings → PAT | Docker Login |
| `HETZNER_HOST` | IP oder Domain des Servers | SSH Deploy |
| `HETZNER_USER` | SSH-Benutzername (z.B. `deploy`) | SSH Deploy |
| `HETZNER_SSH_KEY` | Privater SSH-Key (ohne Passphrase) | SSH Deploy |

### 11.5 angular.json (wichtige Felder)

```json
{
  "projects": {
    "work-time-manager-web": {
      "architect": {
        "build": {
          "options": {
            "outputPath": "dist/work-time-manager-web",
            "index": "src/index.html",
            "browser": "src/main.ts",
            "polyfills": ["zone.js"],
            "assets": [
              "src/favicon.ico",
              "src/assets",
              { "glob": "firebase-messaging-sw.js", "input": "public/", "output": "/" }
            ],
            "styles": ["src/styles/theme.scss", "src/styles/print.scss"]
          },
          "configurations": {
            "production": {
              "fileReplacements": [
                {
                  "replace": "src/environments/environment.ts",
                  "with": "src/environments/environment.prod.ts"
                }
              ],
              "budgets": [
                { "type": "initial", "maximumWarning": "500kb", "maximumError": "1mb" }
              ]
            }
          }
        }
      }
    }
  }
}
```

### 11.6 Server-Vorbereitung (Einmalig)

Dokumentiere in `AGENT-11-server-setup.md`:

```bash
# Auf dem Hetzner-Server (einmalig):
mkdir -p /opt/work-time-manager-web
cd /opt/work-time-manager-web

# docker-compose.yml kopieren:
scp docker-compose.yml deploy@<server>:/opt/work-time-manager-web/

# Traefik-Netzwerk (falls noch nicht vorhanden):
docker network create traefik-proxy

# Deploy-User für GitHub Actions anlegen:
adduser --disabled-password deploy
usermod -aG docker deploy
mkdir -p /home/deploy/.ssh
# Öffentlichen Key in authorized_keys eintragen

# Erstes manuelles Deployment:
IMAGE_TAG=latest docker compose up -d
```

### 11.7 .gitignore

```gitignore
# Angular
dist/
.angular/

# Environment (niemals committen!)
src/environments/environment.prod.ts

# Node
node_modules/

# IDE
.idea/
.vscode/
*.iml

# Docker
.dockerignore

# Coverage
coverage/

# OS
.DS_Store
```

## Output
- `Dockerfile`
- `docker-compose.yml`
- `.github/workflows/deploy.yml`
- `nginx.conf` (bereits von Agent 02, hier nur validieren)
- `angular.json` (vollständig)
- `.gitignore`
- `AGENT-11-secrets.md`
- `AGENT-11-server-setup.md`

## Checkliste vor erstem Deployment

- [ ] Alle GitHub Secrets hinterlegt
- [ ] `traefik-proxy` Network auf Server vorhanden
- [ ] `deploy` User mit SSH-Key auf Server eingerichtet
- [ ] `docker-compose.yml` auf Server kopiert
- [ ] Firebase App Check: reCAPTCHA v3 für `app.work-time-manager.app` registriert
- [ ] Firebase Auth: `app.work-time-manager.app` als autorisierte Domain hinzugefügt
- [ ] RevenueCat Web Billing: `app.work-time-manager.app` als erlaubte Origin
- [ ] Stripe: Live-Modus aktiviert (nach Test-Phase)
