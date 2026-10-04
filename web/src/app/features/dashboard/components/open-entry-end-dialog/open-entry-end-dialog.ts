import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { AbstractControl, FormBuilder, ReactiveFormsModule, ValidationErrors } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule, MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { TranslatePipe } from '@ngx-translate/core';
import { map } from 'rxjs';
import { LanguageService } from '../../../../core/services/language';
import {
  OPEN_ENTRY_LONG_WARNING_MS,
  closedBreakMs,
  formatEntryDay,
  formatHm,
  isValidOpenEntryEnd,
  suggestOpenEntryEnd,
} from '../../../../domain/utils/open-entry.utils';
import { WorkEntry } from '../../../../shared/models';
import { toDateKey } from '../../../../shared/utils/german-holidays.util';

export interface OpenEntryEndDialogData {
  /** Der offene Eintrag (Start, Pausen). */
  entry: WorkEntry;
  /** Soll des Eintragstags in ms (0 = kein Soll-Ende). */
  targetMs: number;
}

/** Ergebnis: das gewählte Ende als lokales `Date` (Minuten), `undefined` bei Abbruch. */
export type OpenEntryEndDialogResult = Date | undefined;

/** Lokales `Date` aus `yyyy-MM-dd` + `HH:mm`; `null`, wenn eines fehlt oder ungültig ist. */
function parseEnd(date: string, time: string): Date | null {
  const d = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  const t = /^(\d{2}):(\d{2})/.exec(time);
  if (!d || !t) return null;
  return new Date(Number(d[1]), Number(d[2]) - 1, Number(d[3]), Number(t[1]), Number(t[2]));
}

@Component({
  selector: 'app-open-entry-end-dialog',
  imports: [
    ReactiveFormsModule,
    MatButtonModule,
    MatDialogModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    TranslatePipe,
  ],
  templateUrl: './open-entry-end-dialog.html',
  styleUrl: './open-entry-end-dialog.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class OpenEntryEndDialogComponent {
  private readonly dialogRef = inject(MatDialogRef<OpenEntryEndDialogComponent, OpenEntryEndDialogResult>);
  private readonly data: OpenEntryEndDialogData = inject(MAT_DIALOG_DATA);
  private readonly language = inject(LanguageService);

  private readonly entry = this.data.entry;
  private readonly now = new Date();
  private readonly suggestion = suggestOpenEntryEnd(this.entry, this.data.targetMs, this.now);

  /** Tag des Eintrags für den Text (lokalisiert, aus der id). */
  protected readonly dayText = computed(() => formatEntryDay(this.entry.id, this.language.locale()));

  /** Datumsgrenzen des Feldes; erzwingen bei Tastatureingabe nichts, dafür gibt es den Gruppen-Validator. */
  protected readonly minDate = this.entry.id;
  protected readonly maxDate = toDateKey(this.now);

  /** Soll-Ende als Vorschlag, nur wenn es ein gültiges Ende wäre. */
  protected readonly expectedEnd = this.suggestion.expectedEnd
    && isValidOpenEntryEnd(this.entry, this.suggestion.expectedEnd, this.now)
    ? this.suggestion.expectedEnd
    : null;
  protected readonly expectedEndText = this.expectedEnd ? formatHm(this.expectedEnd) : '';
  /** „Jetzt" ist nur bei Einträgen bis 24 h Alter erlaubt. */
  protected readonly nowEnd = this.suggestion.nowAllowed ? this.now : null;

  protected readonly form = inject(FormBuilder).nonNullable.group(
    {
      date: [this._dateOf(this.suggestion.suggestedEnd ?? this.entry.workStart!)],
      time: [this.suggestion.suggestedEnd ? formatHm(this.suggestion.suggestedEnd) : ''],
    },
    { validators: (group: AbstractControl) => this._validateEnd(group) },
  );

  private readonly formErrors = toSignal(
    this.form.statusChanges.pipe(map(() => this.form.errors)),
    { initialValue: this.form.errors },
  );
  private readonly formValue = toSignal(
    this.form.valueChanges.pipe(map(() => this.form.getRawValue())),
    { initialValue: this.form.getRawValue() },
  );

  protected readonly timeMissing = computed(() => !!this.formErrors()?.['required']);
  protected readonly endInvalid = computed(() => !!this.formErrors()?.['invalidEnd']);
  protected readonly longWarning = computed(() => {
    const v = this.formValue();
    const end = parseEnd(v.date, v.time);
    if (!end || this.formErrors()) return false;
    const net = end.getTime() - this.entry.workStart!.getTime() - closedBreakMs(this.entry.breaks);
    return net > OPEN_ENTRY_LONG_WARNING_MS;
  });

  protected useExpectedEnd(): void {
    if (this.expectedEnd) this._set(this.expectedEnd);
  }

  protected useNow(): void {
    this._set(new Date());
  }

  protected confirm(): void {
    // Frische „jetzt"-Zeit: der Dialog kann lange offen gestanden haben.
    this.form.updateValueAndValidity();
    if (this.form.invalid) return;
    const { date, time } = this.form.getRawValue();
    const end = parseEnd(date, time);
    if (end) this.dialogRef.close(end);
  }

  private _set(d: Date): void {
    this.form.setValue({ date: this._dateOf(d), time: formatHm(d) });
  }

  private _dateOf(d: Date): string {
    return toDateKey(d);
  }

  private _validateEnd(group: AbstractControl): ValidationErrors | null {
    const { date, time } = group.getRawValue() as { date: string; time: string };
    const end = parseEnd(date, time);
    if (!end) return { required: true };
    return isValidOpenEntryEnd(this.entry, end, new Date()) ? null : { invalidEnd: true };
  }
}
