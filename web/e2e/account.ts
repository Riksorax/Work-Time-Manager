import { Page, Route, expect, test as base } from '@playwright/test';
import { Lang, Theme, gotoReady, seedPreferences } from './fixtures';

/**
 * Tests mit Konto (#429): Firebase-Emulatoren (Auth + Firestore) plus ein Fake-Backend für die .NET-API.
 *
 * - Die App läuft mit `ng serve --configuration e2e` (`environment.e2e.ts`) und spricht die Emulatoren an.
 * - Der Fake-Backend-Mock (`page.route` auf `apiUrl`) schreibt in dieselben Firestore-Dokumente, die die App per
 *   `onSnapshot` liest (wie das echte Backend über `FirestoreMappings`).
 * - Jeder Test legt einen eigenen Nutzer an, daher laufen Tests parallel ohne Zurücksetzen der Emulatoren.
 * - Läuft nur mit `E2E_EMULATORS=1` (siehe `playwright.config.ts`); sonst werden die Tests übersprungen.
 */

export const EMULATORS_ENABLED = process.env['E2E_EMULATORS'] === '1';

const PROJECT = 'demo-e2e';
const AUTH = 'http://127.0.0.1:9099';
const FIRESTORE = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`;
const API = 'http://localhost:5100';

// ── Firestore-REST (Admin-Zugriff über das Emulator-Token „owner", umgeht die Rules) ─────────────────────────────

type Fs = Record<string, unknown>;

function toFs(v: unknown): Fs {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFs) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v as object).map(([k, x]) => [k, toFs(x)])) } };
}

function fromFs(v: Fs): unknown {
  if ('nullValue' in v) return null;
  if ('booleanValue' in v) return v['booleanValue'];
  if ('integerValue' in v) return Number(v['integerValue']);
  if ('doubleValue' in v) return v['doubleValue'];
  if ('stringValue' in v) return v['stringValue'];
  if ('timestampValue' in v) return new Date(v['timestampValue'] as string);
  if ('arrayValue' in v) return ((v['arrayValue'] as { values?: Fs[] }).values ?? []).map(fromFs);
  if ('mapValue' in v) return fromFields((v['mapValue'] as { fields?: Record<string, Fs> }).fields ?? {});
  return undefined;
}

function fromFields(fields: Record<string, Fs>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, x]) => [k, fromFs(x)]));
}

const ADMIN = { Authorization: 'Bearer owner', 'Content-Type': 'application/json' };

export async function fsSet(path: string, data: Record<string, unknown>): Promise<void> {
  const res = await fetch(`${FIRESTORE}/${path}`, {
    method: 'PATCH',
    headers: ADMIN,
    body: JSON.stringify({ fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, toFs(v)])) }),
  });
  if (!res.ok) throw new Error(`Firestore-Emulator ${path}: ${res.status} ${await res.text()}`);
}

export async function fsGet(path: string): Promise<Record<string, unknown> | null> {
  const res = await fetch(`${FIRESTORE}/${path}`, { headers: ADMIN });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Firestore-Emulator ${path}: ${res.status}`);
  return fromFields(((await res.json()) as { fields?: Record<string, Fs> }).fields ?? {});
}

export async function fsDelete(path: string): Promise<void> {
  await fetch(`${FIRESTORE}/${path}`, { method: 'DELETE', headers: ADMIN });
}

// ── Konto ────────────────────────────────────────────────────────────────────────────────────────────────────────

export interface TestUser { uid: string; email: string; password: string }

/** Der Firestore-Emulator meldet sich teils vor dem Auth-Emulator: kurz auf Auth warten. */
async function waitForAuthEmulator(): Promise<void> {
  for (let i = 0; i < 60; i++) {
    try { await fetch(AUTH); return; } catch { await new Promise(r => setTimeout(r, 500)); }
  }
  throw new Error('Auth-Emulator nicht erreichbar (127.0.0.1:9099)');
}

export async function createUser(): Promise<TestUser> {
  await waitForAuthEmulator();
  const email = `e2e-${Date.now()}-${Math.random().toString(36).slice(2, 8)}@example.test`;
  const password = 'e2e-Passwort-1';
  const res = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=e2e-dummy`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  if (!res.ok) throw new Error(`Auth-Emulator signUp: ${res.status} ${await res.text()}`);
  return { uid: ((await res.json()) as { localId: string }).localId, email, password };
}

/** Pfad der Profil-Daten: das Standard-Profil bleibt unter `users/{uid}/...` (siehe Root-CLAUDE.md). */
export function scoped(uid: string, collection: string, profileId: string): string {
  return profileId === 'default' ? `users/${uid}/${collection}` : `users/${uid}/profiles/${profileId}/${collection}`;
}

export interface EntryInput {
  /** Beginn; der Kalendertag des Eintrags ergibt sich daraus. */
  start: Date;
  end?: Date;
}

/** Schreibt einen Arbeitseintrag im Flutter-/Backend-Format (`days`-Map ohne führende Null, Zeiten als Timestamp). */
export async function seedEntry(uid: string, profileId: string, e: EntryInput): Promise<void> {
  const monthId = `${e.start.getFullYear()}-${String(e.start.getMonth() + 1).padStart(2, '0')}`;
  const path = `${scoped(uid, 'work_entries', profileId)}/${monthId}`;
  const existing = ((await fsGet(path))?.['days'] as Record<string, unknown> | undefined) ?? {};
  const day = new Date(e.start.getFullYear(), e.start.getMonth(), e.start.getDate());
  existing[String(day.getDate())] = {
    date: day, workStart: e.start, workEnd: e.end ?? null, type: 'work', isManuallyEntered: false,
    manualOvertimeMinutes: null, description: null, breaks: [],
  };
  await fsSet(path, { days: existing });
}

// ── Fake-Backend ─────────────────────────────────────────────────────────────────────────────────────────────────

export interface FakeBackend {
  /** Alle bisher eingegangenen Schreibaufrufe (`METHOD /pfad`), z. B. zur Prüfung, dass nichts verloren ging. */
  calls: string[];
  /** Zusätzliche Arbeitszeit-Profile (ohne Standard). */
  profiles: { id: string; name: string }[];
}

function uidFromToken(header: string | undefined): string | null {
  const token = header?.replace(/^Bearer /, '');
  if (!token) return null;
  try {
    const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8')) as Record<string, string>;
    return payload['user_id'] ?? payload['sub'] ?? null;
  } catch { return null; }
}

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': '*',
  'access-control-allow-methods': 'GET,POST,PUT,DELETE,OPTIONS',
};

interface EntryDto {
  id: string; date: string; workStart: string | null; workEnd: string | null; type: string;
  isManuallyEntered: boolean; manualOvertimeMinutes: number | null; description: string | null;
  breaks: { id: string; name: string; isAutomatic: boolean; start: string; end: string | null }[];
}

async function installFakeBackend(page: Page, user: TestUser, state: FakeBackend): Promise<void> {
  await page.route(`${API}/**`, async (route: Route) => {
    const req = route.request();
    const url = new URL(req.url());
    const json = (body: unknown, status = 200) =>
      route.fulfill({ status, headers: { ...CORS, 'content-type': 'application/json' }, body: JSON.stringify(body) });

    if (req.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: CORS });
    if (uidFromToken(await req.headerValue('authorization') ?? undefined) !== user.uid) return json({}, 401);

    const pid = url.searchParams.get('profileId') ?? 'default';
    const path = url.pathname.replace(/^\/api/, '');
    state.calls.push(`${req.method()} ${path}${pid === 'default' ? '' : `?profileId=${pid}`}`);

    if (path === '/profile') return json({ uid: user.uid, isPremium: false });

    if (path === '/work-profiles') {
      if (req.method() === 'POST') {
        const { name } = req.postDataJSON() as { name: string };
        const created = { id: `p${state.profiles.length + 1}-${Math.random().toString(36).slice(2, 6)}`, name };
        state.profiles.push(created);
        await fsSet(`users/${user.uid}/profiles/${created.id}`, { name, createdAt: new Date() });
        return json(created, 201);
      }
      return json(state.profiles);
    }
    const profileDelete = path.match(/^\/work-profiles\/(.+)$/);
    if (profileDelete && req.method() === 'DELETE') {
      state.profiles = state.profiles.filter(p => p.id !== profileDelete[1]);
      await fsDelete(`users/${user.uid}/profiles/${profileDelete[1]}`);
      return route.fulfill({ status: 204, headers: CORS });
    }

    if (path === '/work-entries' && req.method() === 'PUT') {
      const dto = req.postDataJSON() as EntryDto;
      const date = new Date(dto.date);
      await seedEntryRaw(user.uid, pid, date, dto);
      return json(dto);
    }
    const month = path.match(/^\/work-entries\/(\d+)\/(\d+)(?:\/(\d+))?$/);
    if (month) {
      const monthId = `${month[1]}-${String(month[2]).padStart(2, '0')}`;
      const doc = await fsGet(`${scoped(user.uid, 'work_entries', pid)}/${monthId}`);
      const days = (doc?.['days'] as Record<string, Record<string, unknown>> | undefined) ?? {};
      if (month[3] && req.method() === 'DELETE') {
        delete days[String(Number(month[3]))];
        await fsSet(`${scoped(user.uid, 'work_entries', pid)}/${monthId}`, { days });
        return route.fulfill({ status: 204, headers: CORS });
      }
      return json(Object.entries(days).map(([d, v]) => toEntryDto(monthId, d, v)));
    }

    if (path === '/overtime') {
      const doc = `${scoped(user.uid, 'overtime', pid)}/balance`;
      if (req.method() === 'PUT') {
        const body = req.postDataJSON() as { minutes: number };
        await fsSet(doc, { minutes: body.minutes, lastUpdated: new Date() });
        return json({ minutes: body.minutes, lastUpdated: new Date().toISOString() });
      }
      const current = await fsGet(doc);
      return json({ minutes: (current?.['minutes'] as number) ?? 0, lastUpdated: null });
    }
    if (path === '/settings') {
      const doc = `${scoped(user.uid, 'settings', pid)}/current`;
      if (req.method() === 'PUT') {
        const body = req.postDataJSON() as Record<string, unknown>;
        await fsSet(doc, body);
        return json(body);
      }
      return json((await fsGet(doc)) ?? {});
    }

    const report = path.match(/^\/reports\/(daily|weekly|monthly|yearly)\/(\d+)(?:\/(\d+))?(?:\/(\d+))?$/);
    if (report) return json(await buildReport(user.uid, pid, report[1], Number(report[2]), Number(report[3]), Number(report[4])));

    return json({ message: `E2E-Fake-Backend kennt ${req.method()} ${path} nicht` }, 501);
  });
}

// ── Berichte (vereinfachte Rechnung, nur für die Darstellung; die kanonische Rechenlogik testet das Backend) ──────

const HOUR = 3_600_000;
const pad = (n: number) => String(n).padStart(2, '0');

/** Montag der ISO-Woche, in der `d` liegt (lokal). */
function mondayOf(d: Date): Date {
  const m = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  m.setDate(m.getDate() - ((m.getDay() + 6) % 7));
  return m;
}

/** ISO-8601-Wochennummer. */
function isoWeek(d: Date): number {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
  const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  return Math.ceil(((t.getTime() - y0.getTime()) / 86_400_000 + 1) / 7);
}

async function workedMsOn(uid: string, pid: string, day: Date): Promise<number> {
  const doc = await fsGet(`${scoped(uid, 'work_entries', pid)}/${day.getFullYear()}-${pad(day.getMonth() + 1)}`);
  const e = (doc?.['days'] as Record<string, Record<string, unknown>> | undefined)?.[String(day.getDate())];
  const start = e?.['workStart'], end = e?.['workEnd'];
  return start instanceof Date && end instanceof Date ? end.getTime() - start.getTime() : 0;
}

async function buildReport(uid: string, pid: string, kind: string, y: number, m: number, d: number): Promise<unknown> {
  if (kind === 'daily') {
    const worked = await workedMsOn(uid, pid, new Date(y, m - 1, d));
    return { targetMs: 8 * HOUR, workedMs: worked, overtimeMs: worked - 8 * HOUR };
  }
  if (kind === 'weekly') {
    const monday = mondayOf(new Date(y, m - 1, d));
    const days = await Promise.all([0, 1, 2, 3, 4, 5, 6].map(async i => {
      const day = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i);
      return { date: day.toISOString(), workedMs: await workedMsOn(uid, pid, day) };
    }));
    const total = days.reduce((a, x) => a + x.workedMs, 0);
    const workDays = days.filter(x => x.workedMs > 0).length;
    return {
      weekNumber: isoWeek(monday), start: monday.toISOString(),
      end: new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + 6).toISOString(),
      totalWorkedMs: total, totalBreaksMs: 0, workDays, avgPerDayMs: workDays ? total / workDays : 0,
      overtimeMs: total - workDays * 8 * HOUR, days,
    };
  }
  if (kind === 'monthly') {
    const count = new Date(y, m, 0).getDate();
    const days = await Promise.all(Array.from({ length: count }, async (_, i) => {
      const day = new Date(y, m - 1, i + 1);
      return { date: day.toISOString(), workedMs: await workedMsOn(uid, pid, day) };
    }));
    const weeks = new Map<number, number>();
    for (const x of days) weeks.set(isoWeek(new Date(x.date)), (weeks.get(isoWeek(new Date(x.date))) ?? 0) + x.workedMs);
    const total = days.reduce((a, x) => a + x.workedMs, 0);
    const workDays = days.filter(x => x.workedMs > 0).length;
    return {
      month: new Date(y, m - 1, 1).toISOString(), totalWorkedMs: total, totalBreaksMs: 0, workDays,
      avgPerDayMs: workDays ? total / workDays : 0, avgPerWeekMs: weeks.size ? total / weeks.size : 0,
      monthlyOvertimeMs: total - workDays * 8 * HOUR, totalOvertimeMs: 0,
      weeks: [...weeks].map(([weekNumber, totalWorkedMs]) => ({ weekNumber, totalWorkedMs })), days,
    };
  }
  return { year: y, vacationDaysPerYear: 30, vacationDaysTaken: 0, vacationDaysRemaining: 30, sickDays: 0 };
}

async function seedEntryRaw(uid: string, pid: string, date: Date, dto: EntryDto): Promise<void> {
  const monthId = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
  const path = `${scoped(uid, 'work_entries', pid)}/${monthId}`;
  const days = ((await fsGet(path))?.['days'] as Record<string, unknown> | undefined) ?? {};
  days[String(date.getDate())] = {
    date: new Date(dto.date),
    workStart: dto.workStart ? new Date(dto.workStart) : null,
    workEnd: dto.workEnd ? new Date(dto.workEnd) : null,
    type: dto.type, isManuallyEntered: dto.isManuallyEntered,
    manualOvertimeMinutes: dto.manualOvertimeMinutes, description: dto.description,
    breaks: dto.breaks.map(b => ({
      id: b.id, name: b.name, isAutomatic: b.isAutomatic, start: new Date(b.start), end: b.end ? new Date(b.end) : null,
    })),
  };
  await fsSet(path, { days });
}

function toEntryDto(monthId: string, day: string, v: Record<string, unknown>): EntryDto {
  const iso = (x: unknown) => (x instanceof Date ? x.toISOString() : null);
  return {
    id: `${monthId}-${String(Number(day)).padStart(2, '0')}`, date: iso(v['date'])!, workStart: iso(v['workStart']),
    workEnd: iso(v['workEnd']), type: (v['type'] as string) ?? 'work',
    isManuallyEntered: (v['isManuallyEntered'] as boolean) ?? false,
    manualOvertimeMinutes: (v['manualOvertimeMinutes'] as number | null) ?? null,
    description: (v['description'] as string | null) ?? null,
    breaks: ((v['breaks'] as Record<string, unknown>[]) ?? []).map(b => ({
      id: b['id'] as string, name: b['name'] as string, isAutomatic: (b['isAutomatic'] as boolean) ?? false,
      start: iso(b['start'])!, end: iso(b['end']),
    })),
  };
}

// ── Fixture ──────────────────────────────────────────────────────────────────────────────────────────────────────

export interface Account {
  user: TestUser;
  backend: FakeBackend;
  /** Setzt das Premium-Flag (`users/{uid}.isPremium`), von dem `maxProfileCount` abhängt. */
  setPremium(isPremium: boolean): Promise<void>;
  /** Legt ein zusätzliches Arbeitszeit-Profil an (Backend-Liste + Firestore-Dokument). */
  addProfile(name: string): Promise<string>;
  /** Öffnet die App und meldet den Nutzer im Auth-Emulator an. */
  signIn(opts?: { lang?: Lang; theme?: Theme; path?: string }): Promise<void>;
}

export const test = base.extend<{ account: Account }>({
  account: async ({ page }, use) => {
    const user = await createUser();
    const backend: FakeBackend = { calls: [], profiles: [] };
    await fsSet(`users/${user.uid}`, { isPremium: false });
    await installFakeBackend(page, user, backend);

    await use({
      user,
      backend,
      setPremium: isPremium => fsSet(`users/${user.uid}`, { isPremium }),
      addProfile: async name => {
        const id = `seed-${backend.profiles.length + 1}`;
        backend.profiles.push({ id, name });
        await fsSet(`users/${user.uid}/profiles/${id}`, { name, createdAt: new Date() });
        return id;
      },
      signIn: async ({ lang = 'de', theme = 'light', path = '/dashboard' } = {}) => {
        await seedPreferences(page, lang, theme);
        await gotoReady(page, path);
        await page.waitForFunction(() => '__e2eSignIn' in window);
        await page.evaluate(([e, p]) => (window as unknown as { __e2eSignIn: (e: string, p: string) => Promise<void> })
          .__e2eSignIn(e, p), [user.email, user.password]);
      },
    });
  },
});

export { expect };
