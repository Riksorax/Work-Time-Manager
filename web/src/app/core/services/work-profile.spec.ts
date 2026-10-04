import { TestBed } from '@angular/core/testing';
import { WritableSignal, signal } from '@angular/core';
import { AuthService } from '../auth/auth';
import { ProfileService } from './profile';
import { ApiClient } from './api-client';
import { WorkProfileService } from './work-profile';

// ─── Guard-Registry für interaktive Profilwechsel (#380, Stufe 2) ───────────────────────────────────────
// Kein Test hängt an Datum oder Zeitzone.

const A = 'default';
const B = 'B';
const STORAGE_KEY = 'active_work_profile_u1';

function deferred<T = void>(): { promise: Promise<T>; resolve: (v: T) => void; reject: (e: unknown) => void } {
  let resolve!: (v: T) => void;
  let reject!: (e: unknown) => void;
  const promise = new Promise<T>((res, rej) => { resolve = res; reject = rej; });
  return { promise, resolve, reject };
}

interface Harness {
  svc: WorkProfileService;
  user: WritableSignal<{ uid: string } | null>;
  api: {
    getWorkProfiles: ReturnType<typeof vi.fn>;
    addWorkProfile: ReturnType<typeof vi.fn>;
    deleteWorkProfile: ReturnType<typeof vi.fn>;
  };
}

function setup(opts: { stored?: string } = {}): Harness {
  localStorage.clear();
  if (opts.stored) localStorage.setItem(STORAGE_KEY, opts.stored);
  const user = signal<{ uid: string } | null>({ uid: 'u1' });
  const api = {
    getWorkProfiles: vi.fn(async () => [{ id: B, name: 'Firma B' }]),
    addWorkProfile: vi.fn(async (name: string) => ({ id: B, name })),
    deleteWorkProfile: vi.fn(async () => undefined),
  };
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      { provide: AuthService, useValue: { user, get uid() { return user()?.uid ?? null; } } },
      { provide: ProfileService, useValue: { isPremium: signal(true) } },
      { provide: ApiClient, useValue: api },
    ],
  });
  const svc = TestBed.inject(WorkProfileService);
  TestBed.tick(); // Auth-Effect: gemerktes Profil laden
  return { svc, user, api };
}

describe('WorkProfileService Guard-Registry (#380)', () => {
  afterEach(() => {
    TestBed.resetTestingModule();
    localStorage.clear();
  });

  it('requestSwitch auf das aktive Profil: true, Guards werden nicht gefragt', async () => {
    const h = setup();
    const guard = vi.fn(() => false);
    h.svc.registerSwitchGuard(guard);
    expect(await h.svc.requestSwitch(A)).toBe(true);
    expect(guard).not.toHaveBeenCalled();
  });

  it('ohne Guards wechselt requestSwitch und merkt das Profil', async () => {
    const h = setup();
    expect(await h.svc.requestSwitch(B)).toBe(true);
    expect(h.svc.activeProfileId()).toBe(B);
    expect(localStorage.getItem(STORAGE_KEY)).toBe(B);
  });

  it('ein ablehnender Guard verhindert den Wechsel vollständig', async () => {
    const h = setup();
    const emitted: string[] = [];
    h.svc.activeProfileId$.subscribe(id => emitted.push(id));
    TestBed.tick();
    const before = [...emitted];
    h.svc.registerSwitchGuard(() => false);

    expect(await h.svc.requestSwitch(B)).toBe(false);
    TestBed.tick();
    expect(h.svc.activeProfileId()).toBe(A);
    expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
    expect(emitted).toEqual(before);
  });

  it('der Guard bekommt Herkunfts- und Zielprofil', async () => {
    const h = setup();
    const guard = vi.fn(() => true);
    h.svc.registerSwitchGuard(guard);
    await h.svc.requestSwitch(B);
    expect(guard).toHaveBeenCalledTimes(1);
    expect(guard).toHaveBeenCalledWith({ from: A, to: B });
  });

  it('ein asynchroner Guard: der Wechsel erfolgt erst nach der Auflösung', async () => {
    const h = setup();
    const gate = deferred<boolean>();
    h.svc.registerSwitchGuard(() => gate.promise);

    const p = h.svc.requestSwitch(B);
    await Promise.resolve();
    expect(h.svc.activeProfileId()).toBe(A);

    gate.resolve(true);
    expect(await p).toBe(true);
    expect(h.svc.activeProfileId()).toBe(B);
  });

  it('mehrere Guards laufen sequenziell in Registrierungsreihenfolge, der erste Ablehner stoppt', async () => {
    const h = setup();
    const calls: string[] = [];
    h.svc.registerSwitchGuard(() => { calls.push('g1'); return true; });
    h.svc.registerSwitchGuard(() => { calls.push('g2'); return false; });
    h.svc.registerSwitchGuard(() => { calls.push('g3'); return true; });

    expect(await h.svc.requestSwitch(B)).toBe(false);
    expect(calls).toEqual(['g1', 'g2']);
    expect(h.svc.activeProfileId()).toBe(A);
  });

  it('wirft ein Guard (sync oder rejected), bleibt der Wechsel aus, ohne zu werfen', async () => {
    const h = setup();
    const off = h.svc.registerSwitchGuard(() => { throw new Error('boom'); });
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
    expect(await h.svc.requestSwitch(B)).toBe(false);
    off();
    h.svc.registerSwitchGuard(() => Promise.reject(new Error('boom2')));
    expect(await h.svc.requestSwitch(B)).toBe(false);
    expect(h.svc.activeProfileId()).toBe(A);
  });

  it('die Abmelde-Funktion entfernt den Guard; doppelte Abmeldung ist harmlos', async () => {
    const h = setup();
    const guard = vi.fn(() => false);
    const off = h.svc.registerSwitchGuard(guard);
    off();
    off();
    expect(await h.svc.requestSwitch(B)).toBe(true);
    expect(guard).not.toHaveBeenCalled();
  });

  it('parallele Anfragen: die zweite liefert false, der Guard läuft nur einmal; danach ist wieder ein Wechsel möglich', async () => {
    const h = setup();
    const gate = deferred<boolean>();
    const guard = vi.fn(() => gate.promise);
    h.svc.registerSwitchGuard(guard);

    const first = h.svc.requestSwitch(B);
    expect(await h.svc.requestSwitch('C')).toBe(false);
    expect(guard).toHaveBeenCalledTimes(1);

    gate.resolve(false); // Ablehnung gibt die Sperre wieder frei
    expect(await first).toBe(false);

    guard.mockImplementation(() => Promise.resolve(true));
    expect(await h.svc.requestSwitch(B)).toBe(true);
    expect(h.svc.activeProfileId()).toBe(B);
  });

  it('die Sperre wird auch nach einer Guard-Ausnahme freigegeben', async () => {
    const h = setup();
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
    const guard = vi.fn((): boolean => { throw new Error('boom'); });
    h.svc.registerSwitchGuard(guard);
    expect(await h.svc.requestSwitch(B)).toBe(false);
    guard.mockImplementation(() => true);
    expect(await h.svc.requestSwitch(B)).toBe(true);
  });

  describe('addProfile', () => {
    it('der Guard läuft VOR dem API-Aufruf; bei true: Profil angelegt und aktiv', async () => {
      const h = setup();
      const order: string[] = [];
      h.svc.registerSwitchGuard(req => { order.push(`guard:${req.from}->${req.toName}`); return true; });
      h.api.addWorkProfile.mockImplementation(async (name: string) => { order.push('api'); return { id: B, name }; });

      const created = await h.svc.addProfile('Neu');
      expect(created).toEqual({ id: B, name: 'Neu' });
      expect(order).toEqual([`guard:${A}->Neu`, 'api']);
      expect(h.svc.activeProfileId()).toBe(B);
    });

    it('bei Ablehnung wird kein Profil angelegt, aktiv bleibt das alte, Rückgabe null', async () => {
      const h = setup();
      h.svc.registerSwitchGuard(() => false);
      expect(await h.svc.addProfile('Neu')).toBeNull();
      expect(h.api.addWorkProfile).not.toHaveBeenCalled();
      expect(h.svc.activeProfileId()).toBe(A);
    });

    it('parallel zu einer laufenden Prüfung: addProfile liefert null, ohne Guard und API; umgekehrt wird requestSwitch abgelehnt', async () => {
      const h = setup();
      const gate = deferred<boolean>();
      const guard = vi.fn(() => gate.promise);
      h.svc.registerSwitchGuard(guard);

      const pending = h.svc.requestSwitch(B);
      expect(await h.svc.addProfile('Neu')).toBeNull();
      expect(guard).toHaveBeenCalledTimes(1);
      expect(h.api.addWorkProfile).not.toHaveBeenCalled();
      gate.resolve(true);
      expect(await pending).toBe(true);

      const gate2 = deferred<boolean>();
      guard.mockImplementation(() => gate2.promise);
      h.api.addWorkProfile.mockImplementation(async (name: string) => ({ id: 'C', name }));
      const adding = h.svc.addProfile('Neu');
      expect(await h.svc.requestSwitch(A)).toBe(false);
      expect(guard).toHaveBeenCalledTimes(2);
      gate2.resolve(true);
      expect(await adding).toEqual({ id: 'C', name: 'Neu' });
    });

    it('schlägt die API fehl, wird der Fehler weitergereicht und die Sperre freigegeben', async () => {
      const h = setup();
      h.api.addWorkProfile.mockRejectedValueOnce(new Error('api down'));
      await expect(h.svc.addProfile('Neu')).rejects.toThrow('api down');
      expect(await h.svc.requestSwitch(B)).toBe(true);
    });
  });

  it('deleteProfile(aktiv) läuft ohne Guard, wechselt auf default, bei API-Fehler zurück', async () => {
    const h = setup({ stored: B });
    expect(h.svc.activeProfileId()).toBe(B);
    const guard = vi.fn(() => false);
    h.svc.registerSwitchGuard(guard);

    await h.svc.deleteProfile(B);
    expect(h.svc.activeProfileId()).toBe(A);

    h.svc.setActiveProfile(B);
    h.api.deleteWorkProfile.mockRejectedValueOnce(new Error('boom'));
    await expect(h.svc.deleteProfile(B)).rejects.toThrow('boom');
    expect(h.svc.activeProfileId()).toBe(B);
    expect(guard).not.toHaveBeenCalled();
  });

  it('der Auth-Effect (Reload mit gemerktem Profil, Logout) fragt keine Guards', () => {
    const h = setup();
    const guard = vi.fn(() => false);
    h.svc.registerSwitchGuard(guard);

    h.user.set(null); // Logout
    TestBed.tick();
    expect(h.svc.activeProfileId()).toBe(A);
    expect(guard).not.toHaveBeenCalled();

    localStorage.setItem(STORAGE_KEY, B); // Login mit gemerktem Profil
    h.user.set({ uid: 'u1' });
    TestBed.tick();
    expect(h.svc.activeProfileId()).toBe(B);
    expect(guard).not.toHaveBeenCalled();
  });

  it('setActiveProfile ist der bewusst unbedingte Wechsel und ruft keine Guards', () => {
    const h = setup();
    const guard = vi.fn(() => false);
    h.svc.registerSwitchGuard(guard);
    h.svc.setActiveProfile(B);
    expect(h.svc.activeProfileId()).toBe(B);
    expect(guard).not.toHaveBeenCalled();
  });
});
