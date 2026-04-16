# Agent 11 — CI/CD & Deployment
# Dockerfile

# ─── Stage 1: Build ──────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

# Dependencies zuerst (Layer-Caching)
COPY package.json package-lock.json ./
RUN npm ci

# Source kopieren
COPY . .

# Production Build
# environment.prod.ts wurde bereits durch CI/CD (envsubst) befüllt
RUN npm run build -- --configuration production

# ─── Stage 2: Production (nginx) ─────────────────────────────────────────────
FROM nginx:1.27-alpine AS production

# Angular Build-Artefakte
COPY --from=builder /app/dist/work-time-manager-web/browser /usr/share/nginx/html

# nginx Konfiguration (SPA-Routing + Security-Header)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Firebase Messaging Service Worker (Platzhalter bereits durch CI ersetzt)
# Liegt bereits in dist/browser/firebase-messaging-sw.js (aus public/)

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
