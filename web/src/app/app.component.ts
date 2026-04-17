import { ChangeDetectionStrategy, Component, OnInit, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { DomSanitizer } from '@angular/platform-browser';
import { MatIconRegistry } from '@angular/material/icon';
import { TranslateService } from '@ngx-translate/core';

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

  ngOnInit(): void {
    this.translate.setDefaultLang('de');
    this.translate.use('de');
    this.iconRegistry.addSvgIcon(
      'google',
      this.sanitizer.bypassSecurityTrustResourceUrl('assets/icons/google.svg')
    );
  }
}
