import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';

export interface AddWorkProfileDialogResult { name: string; }

/** Dialog zum Anlegen eines weiteren Arbeitszeit-Profils (siehe #138/#244). */
@Component({
  selector: 'app-add-work-profile-dialog',
  imports: [ReactiveFormsModule, MatDialogModule, MatButtonModule, MatFormFieldModule, MatInputModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>Neues Profil</h2>
    <mat-dialog-content>
      <form [formGroup]="form">
        <mat-form-field appearance="outline" class="full-width">
          <mat-label>Name (z.B. Arbeitgeber)</mat-label>
          <input matInput formControlName="name" maxlength="40" autocomplete="off"
                 aria-label="Profilname" />
        </mat-form-field>
      </form>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button mat-dialog-close>Abbrechen</button>
      <button mat-flat-button [disabled]="form.invalid" (click)="submit()">
        Anlegen
      </button>
    </mat-dialog-actions>
  `,
  styles: [`.full-width { width: 100%; min-width: 260px; } mat-dialog-content { padding-top: 8px; }`],
})
export class AddWorkProfileDialogComponent {
  private readonly dialogRef = inject(MatDialogRef<AddWorkProfileDialogComponent>);
  private readonly fb        = inject(FormBuilder);

  protected readonly form = this.fb.group({
    name: ['', [Validators.required, Validators.maxLength(40)]],
  });

  submit(): void {
    if (this.form.invalid) return;
    const name = this.form.getRawValue().name!.trim();
    if (!name) return;
    this.dialogRef.close({ name } satisfies AddWorkProfileDialogResult);
  }
}
