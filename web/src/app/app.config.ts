import { ApplicationConfig, ErrorHandler, LOCALE_ID, provideZoneChangeDetection } from '@angular/core';
import { registerLocaleData } from '@angular/common';
import localeDe from '@angular/common/locales/de';
import { provideRouter, withNavigationErrorHandler } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import { initializeApp, provideFirebaseApp } from '@angular/fire/app';
import { getAuth, provideAuth } from '@angular/fire/auth';
import { getFirestore, provideFirestore } from '@angular/fire/firestore';
import { provideTranslateService } from '@ngx-translate/core';
import { provideTranslateHttpLoader } from '@ngx-translate/http-loader';
import * as Sentry from '@sentry/angular';

import { routes } from './app.routes';
import { environment } from '../environments/environment';
import { authInterceptor } from './core/http/auth.interceptor';

// Deutsche Locale-Daten registrieren, damit DatePipe & Co. auf Deutsch formatieren.
registerLocaleData(localeDe);

// Fehler-Tracking (siehe #207): nur aktiv, wenn eine DSN konfiguriert ist
// (Produktion mit gesetztem Secret `SENTRY_DSN_WEB`). Lokal/CI bleibt
// Sentry ohne DSN ein No-Op.
if (environment.sentryDsn) {
  Sentry.init({
    dsn: environment.sentryDsn,
    environment: environment.production ? 'production' : 'development',
  });
}

// Sprache der Oberfläche (ngx-translate) - geräteweit in localStorage
// gespeichert, analog zur Mobile-App (siehe #221). Muss synchron vor dem
// Bootstrap gelesen werden, damit die erste Render-Runde bereits in der
// gespeicherten Sprache erfolgt.
const initialLang = localStorage.getItem('locale') ?? 'de';

export const appConfig: ApplicationConfig = {
  providers: [
    // LOCALE_ID steuert nur Angulars eingebaute Pipes (DatePipe etc.) und
    // bleibt bewusst fest auf Deutsch - eine Laufzeit-Umschaltung würde ein
    // Neuladen der App erfordern. Für Oberflächen-Strings siehe ngx-translate
    // unten, das echte Laufzeit-Umschaltung ermöglicht (siehe #221).
    { provide: LOCALE_ID, useValue: 'de-DE' },
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes, withNavigationErrorHandler(e => {
      console.error('Navigation error:', e);
      Sentry.captureException(e);
    })),
    provideHttpClient(withInterceptors([authInterceptor])),
    provideAnimationsAsync(),
    provideFirebaseApp(() => initializeApp(environment.firebase)),
    provideAuth(() => getAuth()),
    provideFirestore(() => getFirestore()),
    // Reihenfolge wichtig: provideTranslateService() registriert selbst einen
    // TranslateNoOpLoader-Fallback für TranslateLoader - der HTTP-Loader muss
    // danach stehen, damit sein Provider für denselben Token gewinnt (Angular
    // nimmt bei mehreren Providern für ein Token den zuletzt registrierten).
    provideTranslateService({ fallbackLang: 'de', lang: initialLang }),
    provideTranslateHttpLoader({ prefix: '/i18n/', suffix: '.json' }),
    {
      provide: ErrorHandler,
      useValue: Sentry.createErrorHandler({ showDialog: false }),
    },
  ]
};
