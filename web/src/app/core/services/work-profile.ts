import { Injectable, computed, effect, inject, signal } from '@angular/core';
import { toObservable } from '@angular/core/rxjs-interop';
import { AuthService } from '../auth/auth';
import { ProfileService } from './profile';
import { ApiClient } from './api-client';
import { DEFAULT_WORK_PROFILE_ID, WorkProfile } from '../../shared/models';

const ACTIVE_PROFILE_KEY_PREFIX = 'active_work_profile_';

const DEFAULT_PROFILE: WorkProfile = { id: DEFAULT_WORK_PROFILE_ID, name: 'Standard' };

/**
 * Verwaltet zusätzliche Arbeitszeit-Profile (siehe #138/#239/#244) - Web-
 * Pendant zu `WorkProfileRepository`/`activeWorkProfileIdProvider` in der
 * Mobile-App. Profile setzen ein Login voraus (Premium-Feature); ausgeloggt
 * gibt es nur das Standard-Profil.
 */
@Injectable({ providedIn: 'root' })
export class WorkProfileService {
  private readonly auth          = inject(AuthService);
  private readonly profileService = inject(ProfileService);
  private readonly api           = inject(ApiClient);

  private readonly _activeProfileId = signal<string>(DEFAULT_WORK_PROFILE_ID);
  readonly activeProfileId  = this._activeProfileId.asReadonly();
  readonly activeProfileId$ = toObservable(this._activeProfileId);

  private readonly _profiles = signal<WorkProfile[]>([DEFAULT_PROFILE]);
  readonly profiles = this._profiles.asReadonly();

  /** Kein Abo: 1 (nur Standard-Profil). Premium (aktuell einzige Stufe): 2.
   * Siehe #240 (Flutter-Pendant: `maxWorkProfileCountProvider`). */
  readonly maxProfileCount = computed(() => (this.profileService.isPremium() ? 2 : 1));

  constructor() {
    effect(() => {
      const uid = this.auth.user()?.uid ?? null;
      if (!uid) {
        this._activeProfileId.set(DEFAULT_WORK_PROFILE_ID);
        this._profiles.set([DEFAULT_PROFILE]);
        return;
      }
      this._activeProfileId.set(
        localStorage.getItem(this._storageKey(uid)) ?? DEFAULT_WORK_PROFILE_ID
      );
      void this.refreshProfiles();
    });
  }

  /** `undefined` für das Standard-Profil (Query-Parameter bleibt weg), sonst
   * die Profil-ID - direkt für `ApiClient`-Aufrufe nutzbar. */
  get activeProfileIdForApi(): string | undefined {
    const id = this._activeProfileId();
    return id === DEFAULT_WORK_PROFILE_ID ? undefined : id;
  }

  async refreshProfiles(): Promise<void> {
    if (!this.auth.uid) {
      this._profiles.set([DEFAULT_PROFILE]);
      return;
    }
    try {
      const additional = await this.api.getWorkProfiles();
      this._profiles.set([DEFAULT_PROFILE, ...additional]);
    } catch {
      this._profiles.set([DEFAULT_PROFILE]);
    }
  }

  setActiveProfile(id: string): void {
    this._activeProfileId.set(id);
    const uid = this.auth.uid;
    if (uid) localStorage.setItem(this._storageKey(uid), id);
  }

  async addProfile(name: string): Promise<WorkProfile> {
    const created = await this.api.addWorkProfile(name);
    await this.refreshProfiles();
    this.setActiveProfile(created.id);
    return created;
  }

  async deleteProfile(id: string): Promise<void> {
    await this.api.deleteWorkProfile(id);
    if (this._activeProfileId() === id) this.setActiveProfile(DEFAULT_WORK_PROFILE_ID);
    await this.refreshProfiles();
  }

  private _storageKey(uid: string): string {
    return `${ACTIVE_PROFILE_KEY_PREFIX}${uid}`;
  }
}
