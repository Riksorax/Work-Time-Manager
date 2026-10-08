import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ReactiveFormsModule, FormBuilder } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatRadioModule } from '@angular/material/radio';
import { TranslatePipe } from '@ngx-translate/core';
import { BUNDESLAND_VALUES, Bundesland } from '../../../../shared/models/index';

export interface EditBundeslandDialogData   { current: Bundesland | null; }
export interface EditBundeslandDialogResult { bundesland: Bundesland | null; }

@Component({
  selector: 'app-edit-bundesland-dialog',
  imports: [ReactiveFormsModule, MatDialogModule, MatButtonModule, MatRadioModule, TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>{{ 'settings.bundesland.dialogTitle' | translate }}</h2>
    <mat-dialog-content>
      <mat-radio-group class="options" [formControl]="control"
                       [attr.aria-label]="'settings.bundesland.groupAria' | translate">
        <mat-radio-button [value]="null" [attr.cdkFocusInitial]="data.current === null ? '' : null">{{ 'settings.bundesland.notSelected' | translate }}</mat-radio-button>
        @for (b of values; track b) {
          <mat-radio-button [value]="b" [attr.cdkFocusInitial]="b === data.current ? '' : null">{{ 'settings.bundesland.state.' + b | translate }}</mat-radio-button>
        }
      </mat-radio-group>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>{{ 'common.cancel' | translate }}</button>
      <button mat-flat-button (click)="submit()">{{ 'common.save' | translate }}</button>
    </mat-dialog-actions>
  `,
  styles: [`
    .options { display: flex; flex-direction: column; min-width: min(260px, calc(95vw - 48px)); }
    mat-dialog-content { padding-top: 8px; }
  `],
})
export class EditBundeslandDialogComponent {
  protected readonly data     = inject<EditBundeslandDialogData>(MAT_DIALOG_DATA);
  private  readonly dialogRef = inject(MatDialogRef<EditBundeslandDialogComponent>);
  private  readonly fb        = inject(FormBuilder);

  // Kopie statt nackter Referenz (`= BUNDESLAND_VALUES`): Vites SSR-Transform macht daraus im gebündelten Testlauf einen Schnappschuss vor der Klasse, der teils `undefined` ist (web/CLAUDE.md, „Test-Falle“).
  protected readonly values = [...BUNDESLAND_VALUES];
  protected readonly control = this.fb.control<Bundesland | null>(this.data.current);

  submit(): void {
    this.dialogRef.close({ bundesland: this.control.value } satisfies EditBundeslandDialogResult);
  }
}
