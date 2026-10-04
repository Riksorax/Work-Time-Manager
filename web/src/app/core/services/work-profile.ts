import { Injectable, computed, effect, inject, signal } from '@angular/core';
import { toObservable } from '@angular/core/rxjs-interop';
import { AuthService } from '../auth/auth';
import { ProfileService } from './profile';
import { ApiClient } from './api-client';
import { DEFAULT_WORK_PROFILE_ID, WorkProfile } from '../../shared/models';

const ACTIVE_PROFILE_KEY_PREFIX = 'active_work_profile_';

const DEFAULT_PROFILE: WorkProfile = { id: DEFAULT_WORK_PROFILE_ID, name: 'Standard' };

/**
 * Anfrage eines interaktiven Profilwechsels (#380, Stufe 2). `to` ist `null`, wenn das Zielprofil erst angelegt wird
 * (`addProfile`); dann steht der geplante Name in `toName`.
 */
export interface ProfileSwitchRequest { from: string; to: string | null; toName?: string }

/** Guard für interaktive Profilwechsel: `false` lehnt den Wechsel ab. */
export type ProfileSwitchGuard = (req: ProfileSwitchRequest) => boolean | Promise<boolean>;

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

  /** Guards für interaktive Wechsel (Registry statt Import, der Core kennt keine Features). */
  private readonly _guards = new Set<ProfileSwitchGuard>();
  /** Läuft gerade eine Guard-Prüfung bzw. ein Anlegen? Parallele Anfragen werden abgelehnt. */
  private _switchPending = false;

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

  /**
   * Meldet einen Guard für interaktive Profilwechsel an (`requestSwitch`, `addProfile`). Liefert die Abmelde-Funktion
   * (passt zu `DestroyRef.onDestroy`).
   */
  registerSwitchGuard(guard: ProfileSwitchGuard): () => void {
    this._guards.add(guard);
    return () => { this._guards.delete(guard); };
  }

  /**
   * Interaktiver Wechsel (Header-Wechsler): fragt die Guards der Reihe nach, erst danach wird gewechselt. `false` =
   * abgelehnt (Guard sagt nein, wirft, oder es läuft schon eine Anfrage); das aktive Profil bleibt dann unverändert.
   */
  async requestSwitch(id: string): Promise<boolean> {
    const from = this._activeProfileId();
    if (id === from) return true;
    if (this._switchPending) return false;
    this._switchPending = true;
    try {
      if (!(await this._guardsAllow({ from, to: id }))) return false;
      this.setActiveProfile(id);
      return true;
    } finally {
      this._switchPending = false;
    }
  }

  /**
   * Der unbedingte Wechsel, bewusst OHNE Guards: Reload mit gemerktem Profil, Logout, `deleteProfile`. Interaktive
   * Wechsel laufen über `requestSwitch`.
   */
  setActiveProfile(id: string): void {
    this._activeProfileId.set(id);
    const uid = this.auth.uid;
    if (uid) localStorage.setItem(this._storageKey(uid), id);
  }

  /**
   * Legt ein Profil an und wechselt hinein. Die Guards laufen VOR dem API-Aufruf: lehnt einer ab, wird kein Profil
   * angelegt und `null` geliefert.
   */
  async addProfile(name: string): Promise<WorkProfile | null> {
    if (this._switchPending) return null;
    this._switchPending = true;
    try {
      if (!(await this._guardsAllow({ from: this._activeProfileId(), to: null, toName: name }))) return null;
      const created = await this.api.addWorkProfile(name);
      await this.refreshProfiles();
      this.setActiveProfile(created.id);
      return created;
    } finally {
      this._switchPending = false;
    }
  }

  async deleteProfile(id: string): Promise<void> {
    // Ein aktives Profil wird VOR dem API-Aufruf verlassen (#380): so läuft währenddessen kein Autosave mehr in das
    // gerade zu löschende Profil (das Backend würde dort verwaiste Dokumente neu anlegen). Schlägt das Löschen fehl,
    // geht es zurück ins unveränderte Profil.
    const wasActive = this._activeProfileId() === id;
    if (wasActive) this.setActiveProfile(DEFAULT_WORK_PROFILE_ID);
    try {
      await this.api.deleteWorkProfile(id);
    } catch (e) {
      if (wasActive && this._activeProfileId() === DEFAULT_WORK_PROFILE_ID) this.setActiveProfile(id);
      throw e;
    }
    await this.refreshProfiles();
  }

  /** Guards sequenziell; erstes `false` oder eine Ausnahme lehnt ab (im Zweifel nicht wechseln). */
  private async _guardsAllow(req: ProfileSwitchRequest): Promise<boolean> {
    for (const guard of [...this._guards]) {
      try {
        if (!(await guard(req))) return false;
      } catch (e) {
        console.error('Profilwechsel-Guard fehlgeschlagen', e);
        return false;
      }
    }
    return true;
  }

  private _storageKey(uid: string): string {
    return `${ACTIVE_PROFILE_KEY_PREFIX}${uid}`;
  }
}
