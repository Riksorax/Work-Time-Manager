import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
} from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { toSignal } from '@angular/core/rxjs-interop';
import {
  Firestore,
  collection,
  collectionData,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  Timestamp,
} from '@angular/fire/firestore';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatDividerModule } from '@angular/material/divider';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { TranslateModule } from '@ngx-translate/core';
import { Observable, of, switchMap } from 'rxjs';
import { AuthService } from '../../../../core/auth/auth.service';
import { UserProfileService } from '../../services/user-profile.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';
import { ConfirmDialogComponent } from '../../../../shared/components/confirm-dialog/confirm-dialog.component';
import { WorkProfile } from '../../../../shared/models';

@Component({
  selector: 'wtm-profiles',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    MatCardModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatDividerModule,
    MatDialogModule,
    TranslateModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; padding: 16px; max-width: 600px; margin: 0 auto; }

    h1 { margin: 0 0 4px; font-size: 1.5rem; font-weight: 700; }
    .subtitle { color: var(--mat-sys-on-surface-variant); font-size: 0.875rem; margin: 0 0 20px; }

    .profile-item {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px 0;

      .color-dot {
        width: 16px;
        height: 16px;
        border-radius: 50%;
        flex-shrink: 0;
      }

      .profile-info {
        flex: 1;
        .profile-name { font-weight: 600; }
        .profile-meta { font-size: 0.8rem; color: var(--mat-sys-on-surface-variant); }
      }
    }

    .add-form {
      margin-top: 16px;
      display: flex;
      flex-direction: column;
      gap: 8px;

      .form-row { display: flex; gap: 8px; align-items: flex-start; }
      mat-form-field { flex: 1; }
    }

    .empty-state {
      text-align: center;
      padding: 24px;
      color: var(--mat-sys-on-surface-variant);
      font-size: 0.875rem;
    }
  `],
  template: `
    <h1>Profile</h1>
    <p class="subtitle">Verwalte mehrere Arbeitgeber oder Projekte (Premium)</p>

    <mat-card appearance="outlined">
      <mat-card-content>
        @if (profiles().length === 0) {
          <div class="empty-state">Noch keine Profile angelegt.</div>
        } @else {
          @for (profile of profiles(); track profile.id; let last = $last) {
            <div class="profile-item">
              <div class="color-dot" [style.background]="profile.color"></div>
              <div class="profile-info">
                <div class="profile-name">
                  {{ profile.name }}
                  @if (profile.isDefault) { <span style="color:var(--mat-sys-primary);font-size:0.75rem"> ★ Standard</span> }
                </div>
                <div class="profile-meta">{{ profile.weeklyTargetHours }}h/Woche</div>
              </div>
              <button mat-icon-button (click)="setDefault(profile)" [disabled]="profile.isDefault">
                <mat-icon>{{ profile.isDefault ? 'star' : 'star_outline' }}</mat-icon>
              </button>
              <button mat-icon-button (click)="confirmDelete(profile)">
                <mat-icon color="warn">delete</mat-icon>
              </button>
            </div>
            @if (!last) { <mat-divider /> }
          }
        }

        @if (!showForm()) {
          <div style="margin-top:12px">
            <button mat-stroked-button (click)="showForm.set(true)">
              <mat-icon>add</mat-icon>
              Profil hinzufügen
            </button>
          </div>
        } @else {
          <div class="add-form">
            <mat-divider style="margin:12px 0" />
            <form [formGroup]="form" (ngSubmit)="addProfile()">
              <div class="form-row">
                <mat-form-field appearance="outline" subscriptSizing="dynamic">
                  <mat-label>Name</mat-label>
                  <input matInput formControlName="name" />
                </mat-form-field>
                <input type="color" formControlName="color" style="height:56px;width:56px;border:none;border-radius:8px;cursor:pointer" />
              </div>
              <mat-form-field appearance="outline" subscriptSizing="dynamic">
                <mat-label>Wöchentliche Sollstunden</mat-label>
                <input matInput type="number" formControlName="weeklyTargetHours" />
                <span matSuffix>h</span>
              </mat-form-field>
              <div style="display:flex;gap:8px;justify-content:flex-end">
                <button mat-button type="button" (click)="showForm.set(false)">{{ 'common.cancel' | translate }}</button>
                <button mat-flat-button type="submit" [disabled]="form.invalid || saving()">
                  @if (saving()) { <mat-spinner diameter="18" /> }
                  @else { {{ 'common.save' | translate }} }
                </button>
              </div>
            </form>
          </div>
        }
      </mat-card-content>
    </mat-card>
  `,
})
export class ProfilesComponent {
  private firestore = inject(Firestore);
  private auth = inject(AuthService);
  private profileService = inject(UserProfileService);
  private toast = inject(ToastService);
  private dialog = inject(MatDialog);
  private fb = inject(FormBuilder);

  readonly saving = signal(false);
  readonly showForm = signal(false);

  readonly profiles = toSignal(
    this.auth.currentUser$.pipe(
      switchMap(user => {
        if (!user) return of([]);
        return collectionData(
          collection(this.firestore, `users/${user.uid}/workProfiles`),
          { idField: 'id' }
        ) as Observable<WorkProfile[]>;
      })
    ),
    { initialValue: [] as WorkProfile[] }
  );

  readonly form = this.fb.nonNullable.group({
    name: ['', Validators.required],
    color: ['#4285F4'],
    weeklyTargetHours: [40, [Validators.required, Validators.min(1)]],
  });

  async addProfile(): Promise<void> {
    if (this.form.invalid) return;
    const uid = this.auth.uid();
    if (!uid) return;
    this.saving.set(true);
    try {
      const { name, color, weeklyTargetHours } = this.form.getRawValue();
      const isFirst = this.profiles().length === 0;
      await addDoc(collection(this.firestore, `users/${uid}/workProfiles`), {
        name,
        color,
        weeklyTargetHours,
        dailyTargetHours: Math.round(weeklyTargetHours / 5),
        isDefault: isFirst,
        createdAt: Timestamp.now(),
      });
      this.form.reset({ name: '', color: '#4285F4', weeklyTargetHours: 40 });
      this.showForm.set(false);
    } catch {
      this.toast.error('common.error');
    } finally {
      this.saving.set(false);
    }
  }

  async setDefault(profile: WorkProfile): Promise<void> {
    const uid = this.auth.uid();
    if (!uid) return;
    try {
      for (const p of this.profiles()) {
        await updateDoc(doc(this.firestore, `users/${uid}/workProfiles/${p.id}`), {
          isDefault: p.id === profile.id,
        });
      }
      await this.profileService.updateProfile({ activeProfileId: profile.id });
    } catch {
      this.toast.error('common.error');
    }
  }

  confirmDelete(profile: WorkProfile): void {
    const ref = this.dialog.open(ConfirmDialogComponent, {
      data: {
        title: 'Profil löschen',
        message: `"${profile.name}" wirklich löschen?`,
        confirmLabel: 'common.delete',
        cancelLabel: 'common.cancel',
      },
    });
    ref.afterClosed().subscribe(async confirmed => {
      if (!confirmed) return;
      const uid = this.auth.uid();
      if (!uid) return;
      try {
        await deleteDoc(doc(this.firestore, `users/${uid}/workProfiles/${profile.id}`));
      } catch {
        this.toast.error('common.error');
      }
    });
  }
}
