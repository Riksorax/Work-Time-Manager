import { ApplicationConfig, provideZoneChangeDetection, importProvidersFrom, isDevMode } from '@angular/core';
import { provideRouter, withComponentInputBinding } from '@angular/router';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import { provideHttpClient, withInterceptors, HttpClient } from '@angular/common/http';

import { initializeApp, provideFirebaseApp } from '@angular/fire/app';
import { getAuth, provideAuth } from '@angular/fire/auth';
import { getFirestore, provideFirestore } from '@angular/fire/firestore';
import { getMessaging, provideMessaging } from '@angular/fire/messaging';
import { ReCaptchaV3Provider, initializeAppCheck, provideAppCheck } from '@angular/fire/app-check';

import { TranslateModule, TranslateLoader } from '@ngx-translate/core';
import { TranslateHttpLoader } from '@ngx-translate/http-loader';

import { routes } from './app.routes';
import { environment } from '../environments/environment';
import { authInterceptor } from './core/auth/auth.interceptor';

export function HttpLoaderFactory(http: HttpClient) {
  return new TranslateHttpLoader();
}

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes, withComponentInputBinding()),
    provideAnimationsAsync(),
    provideHttpClient(withInterceptors([authInterceptor])),
    
    // Firebase
    provideFirebaseApp(() => initializeApp(environment.firebase)),
    provideAuth(() => getAuth()),
    provideFirestore(() => getFirestore()),
    provideMessaging(() => getMessaging()),
    
    // App Check
    provideAppCheck(() => {
      if (isDevMode()) {
        (self as any).FIREBASE_APPCHECK_DEBUG_TOKEN = true;
      }
      return initializeAppCheck(undefined, {
        provider: new ReCaptchaV3Provider(environment.recaptchaSiteKey),
        isTokenAutoRefreshEnabled: true,
      });
    }),

    // i18n
    importProvidersFrom(
      TranslateModule.forRoot({
        loader: {
          provide: TranslateLoader,
          useFactory: HttpLoaderFactory,
          deps: [HttpClient]
        },
        defaultLanguage: 'de'
      })
    )
  ]
};
