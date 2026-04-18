# Agent 02 — Security

## Mission
Stelle sicher, dass die Web-App maximale Sicherheit bietet. Du bist verantwortlich für die Firebase-Regeln und die Absicherung der Angular-App.

## Aufgaben

### 1. Firestore Security Rules
- Schreibe die `firestore.rules`, sodass Nutzer nur ihre eigenen Daten lesen/schreiben können.
- Validierung der Datenfelder (z.B. Zeitstempel dürfen nicht in der Zukunft liegen).

### 2. Authentication Layer
- Implementierung von `AuthService` mit Firebase Auth (Google Sign-In + Email/Password).
- `AuthInterceptor` zum Anhängen von Tokens (falls Backend-APIs genutzt werden).

### 3. App Check
- Integration von Google reCAPTCHA v3 in die Web-App via Firebase App Check.

### 4. Input-Validierung
- Zentrale Validierungslogik für alle Zeiteingaben (Schutz vor Inkonsistenzen).

## Fokus UI & Security
- Sicherstellen, dass sensitive Daten (wie E-Mails oder Profil-Details) im Template korrekt maskiert oder geschützt behandelt werden.
