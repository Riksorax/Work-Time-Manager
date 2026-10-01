import { Pipe, PipeTransform, inject } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { localizedBreakName } from '../utils/break-name.util';

/** Zeigt Standard-Pausennamen in der App-Sprache an (siehe #346). */
@Pipe({
  name: 'breakName',
  // Wie TranslatePipe: muss bei Sprachwechsel neu auswerten.
  pure: false,
})
export class BreakNamePipe implements PipeTransform {
  private readonly translate = inject(TranslateService);

  transform(name: string): string {
    return localizedBreakName(name, (key, params) => this.translate.instant(key, params));
  }
}
