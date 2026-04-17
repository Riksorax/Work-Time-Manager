import { ChangeDetectionStrategy, Component, OnInit, inject, effect } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { DomSanitizer } from '@angular/platform-browser';
import { MatIconRegistry } from '@angular/material/icon';
import { TranslateService } from '@ngx-translate/core';
import { AuthService } from './core/auth/auth.service';
import { WorkSessionService } from './features/time-tracking/services/work-session.service';

@Component({
  selector: 'wtm-root',
  standalone: true,
  imports: [RouterOutlet],
  template: `<router-outlet />`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppComponent implements OnInit {
  private translate = inject(TranslateService);
  private iconRegistry = inject(MatIconRegistry);
  private sanitizer = inject(DomSanitizer);
  private auth = inject(AuthService);
  private sessionService = inject(WorkSessionService);

  constructor() {
    // Lokale Gast-Daten automatisch in Firestore migrieren, wenn User sich einloggt
    effect(() => {
      if (this.auth.isLoggedIn()) {
        this.sessionService.migrateLocalToFirestore();
      }
    });
  }

  ngOnInit(): void {
    this.translate.setDefaultLang('de');
    this.translate.use('de');
    // SECURITY: bypassSecurityTrustResourceUrl nur für statische Bundle-Assets erlaubt.
    // Niemals für user-supplied URLs (z.B. photoURL) verwenden.
    this.iconRegistry.addSvgIcon(
      'google',
      this.sanitizer.bypassSecurityTrustResourceUrl('assets/icons/google.svg')
    );
  }
}
