import { ApplicationConfig, provideZoneChangeDetection } from '@angular/core';
import { provideRouter, withNavigationErrorHandler } from '@angular/router';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';
import { initializeApp, provideFirebaseApp } from '@angular/fire/app';
import { getAuth, provideAuth } from '@angular/fire/auth';
import { getFirestore, provideFirestore } from '@angular/fire/firestore';

import { routes } from './app.routes';
import { environment } from '../environments/environment';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes, withNavigationErrorHandler(e => console.error('Navigation error:', e))),
    provideAnimationsAsync(),
    provideFirebaseApp(() => {
      console.log('Initializing Firebase with Key:', environment.firebase.apiKey);
      console.log('Build Timestamp:', (environment as any).buildTimestamp);
      return initializeApp(environment.firebase);
    }),
    provideAuth(() => getAuth()),
    provideFirestore(() => getFirestore()),
  ]
};
