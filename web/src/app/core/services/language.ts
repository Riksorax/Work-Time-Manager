import { Injectable, computed, inject } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';

const LS_KEY = 'locale';

/** Sprache der App-Oberfläche (ngx-translate) - geräteweit, siehe #221. */
@Injectable({ providedIn: 'root' })
export class LanguageService {
  private readonly translate = inject(TranslateService);

  readonly locale = computed(() => this.translate.currentLang() ?? 'de');

  setLocale(locale: string): void {
    this.translate.use(locale);
    localStorage.setItem(LS_KEY, locale);
  }
}
