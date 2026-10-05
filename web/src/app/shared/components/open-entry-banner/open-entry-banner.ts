import { ChangeDetectionStrategy, Component, ElementRef, inject, input, output } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { TranslatePipe } from '@ngx-translate/core';

let nextBannerId = 0;

/**
 * Nicht-modaler Hinweis auf einen nicht beendeten Eintrag vor heute (#385) mit „Beenden", „Später" und optional „Fortsetzen".
 * Rein darstellend: Datum und Startzeit kommen fertig formatiert, die Logik liegt im Dashboard/`OpenEntryService`.
 */
@Component({
  selector: 'app-open-entry-banner',
  imports: [MatButtonModule, MatIconModule, TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './open-entry-banner.html',
  styleUrl: './open-entry-banner.scss',
})
export class OpenEntryBannerComponent {
  private readonly host = inject<ElementRef<HTMLElement>>(ElementRef);

  /** Lokalisierter Tag des Eintrags (z. B. „Fr., 2.10."). */
  readonly dateText = input.required<string>();
  /** Startzeit des Eintrags als `HH:mm`. */
  readonly time = input.required<string>();
  /** Anzahl weiterer offener Einträge (0 = Zeile entfällt). */
  readonly moreCount = input.required<number>();
  /** Beenden/Fortsetzen läuft: alle Buttons deaktiviert. */
  readonly busy = input.required<boolean>();
  /** „Fortsetzen" anbieten (Regel liegt im `OpenEntryService`); ohne bleibt es bei „Später" und „Beenden". */
  readonly canResume = input(false);

  readonly end = output<void>();
  readonly later = output<void>();
  readonly resume = output<void>();

  protected readonly titleId = `open-entry-banner-title-${nextBannerId++}`;

  /** Fokus auf die erste Aktion (z. B. nachdem der vorige Banner entfallen ist). */
  focus(): void {
    this.host.nativeElement.querySelector('button')?.focus();
  }
}
