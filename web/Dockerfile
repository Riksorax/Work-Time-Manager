FROM nginx:1.27-alpine

# Gebaute Angular-App (vom CI-Artifact) in nginx-Root kopieren
COPY dist/work-time-manager-web/browser /usr/share/nginx/html

# SPA-Konfiguration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
    CMD curl -f http://localhost:8080/ || exit 1
