import { ChangeDetectionStrategy, Component, ElementRef, computed, inject, model, signal, viewChild } from '@angular/core';
import { MatAutocompleteModule, MatAutocompleteSelectedEvent, MatAutocompleteTrigger } from '@angular/material/autocomplete';
import { MatChipsModule } from '@angular/material/chips';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { TranslatePipe } from '@ngx-translate/core';
import { WorkEntryService } from '../../../core/services/work-entry';
import {
  AddWorkLocationError, MAX_WORK_LOCATIONS, MAX_WORK_LOCATION_LENGTH, addWorkLocation,
} from '../../utils/work-locations.util';

/**
 * Eingabe der Arbeitsorte eines Tages (#526): Chips + Autocomplete. Der Wert ist `locations` (zweiseitig,
 * `model`). Vorschläge kommen aus bereits geladenen Einträgen (`WorkEntryService.suggestWorkLocations`, kein
 * Lesezugriff). Hinzufügen mit Enter/Komma, per Vorschlag oder über `commitPending()`; leere, doppelte und zu lange
 * Eingaben werden nicht übernommen und erklärt, bei 5 Orten ist die Eingabe gesperrt und sagt warum.
 *
 * Die gewählten Orte stehen als `mat-chip-set` (Liste) über dem Textfeld. `mat-chip-grid` mit `matChipInput` scheitert an
 * axe (`aria-required-children`: das Eingabefeld liegt als Kind direkt im `grid`), deshalb ist die Eingabe ein normales
 * `matInput` mit `matAutocomplete`.
 */
@Component({
  selector: 'app-work-locations-input',
  imports: [MatAutocompleteModule, MatChipsModule, MatFormFieldModule, MatIconModule, MatInputModule, TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (locations().length > 0) {
      <mat-chip-set class="wl-chips" [attr.aria-label]="'shared.workLocationChipsLabel' | translate">
        @for (loc of locations(); track loc) {
          <mat-chip (removed)="remove(loc)">
            {{ loc }}
            <button matChipRemove type="button"
                    [attr.aria-label]="'shared.workLocationRemoveAria' | translate: { name: loc }">
              <mat-icon aria-hidden="true">cancel</mat-icon>
            </button>
          </mat-chip>
        }
      </mat-chip-set>
    }
    <mat-form-field appearance="outline" class="wl-field">
      <mat-label>{{ 'shared.workLocationInputLabel' | translate }}</mat-label>
      <input
        matInput
        #field
        [disabled]="atMax()"
        [matAutocomplete]="auto"
        [attr.aria-describedby]="messageId"
        [attr.aria-invalid]="error() && error() !== 'max' ? 'true' : null"
        autocomplete="off"
        (input)="query.set(field.value)"
        (keydown.enter)="onSeparator($event)"
        (keydown)="onKeydown($event)"
      />
      <mat-autocomplete #auto="matAutocomplete" (optionSelected)="onOptionSelected($event)"
                        [aria-label]="'shared.workLocationSuggestionsAria' | translate">
        @for (s of suggestions(); track s) {
          <mat-option [value]="s">{{ s }}</mat-option>
        }
      </mat-autocomplete>
    </mat-form-field>
    <p class="wl-message" [class.wl-error]="!!error() && error() !== 'max'" [id]="messageId" aria-live="polite">
      @if (atMax()) {
        {{ 'shared.workLocationMaxReached' | translate: { max: max } }}
      } @else if (error(); as e) {
        {{ 'shared.workLocationError' + (e.charAt(0).toUpperCase() + e.slice(1)) | translate: { max: max, length: maxLength } }}
      } @else {
        {{ 'shared.workLocationHint' | translate: { max: max, length: maxLength } }}
      }
    </p>
  `,
  styles: [`
    :host { display: block; }
    .wl-chips { display: block; margin-bottom: 8px; }
    .wl-field { width: 100%; }
    .wl-message {
      margin: 0 0 12px;
      font-size: 0.875rem;
      color: var(--mat-sys-on-surface-variant);
      overflow-wrap: anywhere;
    }
    .wl-message.wl-error { color: var(--mat-sys-error); }
  `],
})
export class WorkLocationsInputComponent {
  private static nextId = 0;
  private readonly workSvc = inject(WorkEntryService);

  readonly locations = model<string[]>([]);

  protected readonly messageId: string;
  protected readonly max: number;
  protected readonly maxLength: number;
  protected readonly error = signal<AddWorkLocationError | null>(null);
  protected readonly query = signal('');

  private readonly field = viewChild<ElementRef<HTMLInputElement>>('field');
  private readonly trigger = viewChild(MatAutocompleteTrigger);

  protected readonly atMax = computed(() => this.locations().length >= this.max);
  protected readonly suggestions = computed(() =>
    this.atMax() ? [] : this.workSvc.suggestWorkLocations(this.locations(), this.query()));

  constructor() {
    // Werte im Konstruktor zuweisen (Vite-SSR-Falle: keine importierte Konstante als Klassenfeld-Wert)
    this.max = MAX_WORK_LOCATIONS;
    this.maxLength = MAX_WORK_LOCATION_LENGTH;
    this.messageId = `wl-message-${WorkLocationsInputComponent.nextId++}`;
  }

  /** Übernimmt den noch nicht bestätigten Text; `false`, wenn er ungültig ist (Fehler wird angezeigt). */
  commitPending(): boolean {
    const raw = this.field()?.nativeElement.value ?? '';
    if (!raw.trim()) return true;
    return this.add(raw);
  }

  /** Enter fügt den getippten Text hinzu, außer er wählt gerade einen markierten Vorschlag. */
  protected onSeparator(event: Event): void {
    event.preventDefault(); // kein Absenden/Schließen des Dialogs durch Enter im Feld
    const trigger = this.trigger();
    if (trigger?.panelOpen && trigger.activeOption) return;
    this.commitFromField();
  }

  /** Komma wirkt wie Enter. */
  protected onKeydown(event: KeyboardEvent): void {
    if (event.key !== ',') return;
    event.preventDefault();
    this.commitFromField();
  }

  protected onOptionSelected(event: MatAutocompleteSelectedEvent): void {
    this.add(String(event.option.value));
  }

  protected remove(loc: string): void {
    this.locations.update(list => list.filter(l => l !== loc));
    this.error.set(null);
  }

  private commitFromField(): void {
    const raw = this.field()?.nativeElement.value ?? '';
    if (!raw.trim()) { this.error.set(null); return; }
    this.add(raw);
  }

  private add(raw: string): boolean {
    const result = addWorkLocation(this.locations(), raw);
    this.error.set(result.error ?? null);
    if (result.error) return false;
    this.locations.set(result.locations);
    const input = this.field()?.nativeElement;
    if (input) input.value = '';
    this.query.set('');
    return true;
  }
}
