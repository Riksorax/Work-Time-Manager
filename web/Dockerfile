# Stage 1: Node.js Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --legacy-peer-deps
COPY . .
# Wir bauen für Production. Das environment.prod.ts wird im CI-Prozess erstellt
RUN npx ng build --configuration production

# Stage 2: nginx
FROM nginx:1.27-alpine AS production
COPY --from=builder /app/dist/work-time-manager-web/browser /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
# Wir nutzen Port 80 im Container, Traefik mappt diesen auf 8080 oder nutzt ihn direkt im Proxy-Netzwerk
CMD ["nginx", "-g", "daemon off;"]
