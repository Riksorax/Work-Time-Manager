/**
 * Nur für die Playwright-UI-Tests (#429, `ng serve --configuration e2e`): Firebase-Emulatoren statt echtem Backend.
 * Die `demo-`-Projekt-ID verhindert jeden Zugriff auf echte Firebase-Projekte, es stehen keine Zugangsdaten darin.
 */
export const environment = {
  production: false,
  apiUrl: 'http://localhost:5100',
  rcWebApiKey: '',
  sentryDsn: '',
  useEmulators: true,
  firebase: {
    apiKey: 'e2e-dummy',
    authDomain: 'demo-e2e.firebaseapp.com',
    projectId: 'demo-e2e',
    storageBucket: 'demo-e2e.appspot.com',
    messagingSenderId: '000000000000',
    appId: '1:000000000000:web:0000000000000000',
  },
};
