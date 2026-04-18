import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { AppComponent } from './app/app';
import { NotificationService } from './app/core/notifications/notification.service';
import { TranslateService } from '@ngx-translate/core';

bootstrapApplication(AppComponent, appConfig)
  .then(appRef => {
    // i18n Initialisierung
    const translate = appRef.injector.get(TranslateService);
    translate.setDefaultLang('de');
    translate.use('de');

    // Notifications Listener starten
    const notificationService = appRef.injector.get(NotificationService);
    notificationService.listenForMessages();
  })
  .catch((err) => console.error(err));
