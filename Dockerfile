# Stage 1: Build Flutter Web App
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Arbeitsverzeichnis setzen
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

# Kopiere pubspec-Dateien zuerst für besseres Caching
COPY pubspec.* ./

# Installiere Dependencies
RUN flutter pub get

# Kopiere den Rest des Projekts
COPY . .

# Argument für ReCaptcha Site Key (wird via --build-arg übergeben)
ARG RECAPTCHA_SITE_KEY
ARG RC_WEB_KEY

# Baue die Web-App im Release-Modus mit dem injizierten Key
RUN flutter build web --release --dart-define=RECAPTCHA_SITE_KEY=$RECAPTCHA_SITE_KEY --dart-define=RC_WEB_KEY=$RC_WEB_KEY

# Stage 2: Nginx Server für die Web-App
FROM nginx:alpine

# Kopiere die gebaute Web-App von der Build-Stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Kopiere nginx-Konfiguration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Starte nginx
CMD ["nginx", "-g", "daemon off;"]
