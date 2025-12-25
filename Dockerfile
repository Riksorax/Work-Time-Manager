# Stage 1: Build Flutter Web App
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Arbeitsverzeichnis setzen
WORKDIR /app

# Kopiere pubspec-Dateien zuerst für besseres Caching
COPY pubspec.* ./

# Installiere Dependencies
RUN flutter pub get

# Kopiere den Rest des Projekts
COPY . .

# Baue die Web-App im Release-Modus
RUN flutter build web --release

# Stage 2: Nginx Server für die Web-App
FROM nginx:alpine

# Kopiere die gebaute Web-App von der Build-Stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Kopiere nginx-Konfiguration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exponiere Port 80
EXPOSE 80

# Starte nginx
CMD ["nginx", "-g", "daemon off;"]
