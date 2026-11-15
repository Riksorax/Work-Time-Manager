// Tests für sync-store-metadata.mjs (#559), ohne Netz und ohne Abhängigkeiten:
//   node --test .github/scripts/sync-store-metadata.test.mjs
import { test, describe, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import {
  buildPlan,
  findScreenshots,
  getAccessToken,
  readImageInfo,
  run,
  syncListings,
  validateScreenshots,
} from './sync-store-metadata.mjs';

const EDITS = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/app.work_time_manager/edits';
const UPLOADS = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/app.work_time_manager/edits';

// --- Bild-Fixtures (nur Header, das reicht für die Prüfung) ---

function png(width, height, padTo = 0) {
  const ihdr = Buffer.alloc(25);
  ihdr.writeUInt32BE(13, 0);
  ihdr.write('IHDR', 4, 'latin1');
  ihdr.writeUInt32BE(width, 8);
  ihdr.writeUInt32BE(height, 12);
  ihdr[16] = 8; // Bit-Tiefe
  ihdr[17] = 6; // RGBA
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const buf = Buffer.concat([sig, ihdr]);
  return padTo > buf.length ? Buffer.concat([buf, Buffer.alloc(padTo - buf.length)]) : buf;
}

function jpeg(width, height) {
  const app0 = Buffer.from([0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 1, 1, 0, 0, 1, 0, 1, 0, 0]);
  const dqt = Buffer.concat([Buffer.from([0xff, 0xdb, 0x00, 0x43, 0x00]), Buffer.alloc(64, 1)]);
  const sof = Buffer.alloc(19);
  sof.writeUInt16BE(0xffc0, 0);
  sof.writeUInt16BE(17, 2);
  sof[4] = 8;
  sof.writeUInt16BE(height, 5);
  sof.writeUInt16BE(width, 7);
  sof[9] = 3;
  const sos = Buffer.from([0xff, 0xda, 0x00, 0x02]);
  return Buffer.concat([Buffer.from([0xff, 0xd8]), app0, dqt, sof, sos, Buffer.from([0xff, 0xd9])]);
}

// --- Metadaten-Ordner ---

let root;

function writeLang(lang, { title = `Titel ${lang}`, images = {} } = {}) {
  const dir = path.join(root, lang);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'title.txt'), `${title}\n`);
  fs.writeFileSync(path.join(dir, 'short_description.txt'), `Kurz ${lang}\n`);
  fs.writeFileSync(path.join(dir, 'full_description.txt'), `Lang ${lang}\n\nZeile 2\n`);
  const names = Object.keys(images);
  if (names.length > 0) {
    const imgDir = path.join(dir, 'images', 'phoneScreenshots');
    fs.mkdirSync(imgDir, { recursive: true });
    for (const name of names) fs.writeFileSync(path.join(imgDir, name), images[name]);
  }
  return dir;
}

beforeEach(() => {
  root = fs.mkdtempSync(path.join(os.tmpdir(), 'store-meta-'));
});

afterEach(() => {
  fs.rmSync(root, { recursive: true, force: true });
});

// --- Fake-fetch ---

function fakeFetch({ fail = () => null } = {}) {
  const calls = [];
  const impl = async (url, init = {}) => {
    const call = {
      method: init.method || 'GET',
      url: String(url),
      contentType: init.headers?.['Content-Type'],
      authorization: init.headers?.Authorization,
      body: init.body,
    };
    calls.push(call);
    const failure = fail(call);
    if (failure) {
      return { ok: false, status: failure.status, text: async () => failure.body ?? '', json: async () => ({}) };
    }
    if (call.url.endsWith('/token')) {
      return { ok: true, status: 200, json: async () => ({ access_token: 'test-token' }), text: async () => '' };
    }
    if (call.method === 'POST' && call.url === EDITS) {
      return { ok: true, status: 200, json: async () => ({ id: 'edit-1' }), text: async () => '' };
    }
    return { ok: true, status: 200, json: async () => ({}), text: async () => '{}' };
  };
  return { impl, calls };
}

const short = (calls) => calls.map((c) => `${c.method} ${c.url.replace(EDITS, 'E').replace(UPLOADS, 'U')}`);

const SA = JSON.stringify({ client_email: 'sa@example.iam.gserviceaccount.com', private_key: 'unused' });
const quiet = { log: () => {}, warn: () => {}, error: () => {} };

async function runWith(fetch, extra = {}) {
  return run({ serviceAccountJson: SA, metadataRoot: root, fetchImpl: fetch.impl, getToken: async () => 'test-token', ...quiet, ...extra });
}

// --- Tests ---

describe('readImageInfo', () => {
  test('liest PNG-Maße aus IHDR', () => {
    assert.deepEqual(readImageInfo(png(1080, 1920)), { format: 'png', mimeType: 'image/png', width: 1080, height: 1920 });
  });

  test('liest JPEG-Maße aus dem SOF-Segment hinter APP0/DQT', () => {
    assert.deepEqual(readImageInfo(jpeg(1242, 2208)), { format: 'jpeg', mimeType: 'image/jpeg', width: 1242, height: 2208 });
  });

  test('erkennt progressive JPEGs (SOF2)', () => {
    const buf = jpeg(800, 1200);
    buf[buf.indexOf(Buffer.from([0xff, 0xc0])) + 1] = 0xc2;
    assert.equal(readImageInfo(buf).width, 800);
  });

  test('null bei anderem Format oder kaputtem Header', () => {
    assert.equal(readImageInfo(Buffer.from('GIF89a........................')), null);
    assert.equal(readImageInfo(Buffer.from([0xff, 0xd8, 0xff, 0xda, 0, 2])), null);
    assert.equal(readImageInfo(png(10, 10).subarray(0, 20)), null);
  });
});

describe('findScreenshots', () => {
  test('fehlender Ordner ergibt keine Bilder', () => {
    const dir = writeLang('de-DE');
    assert.deepEqual(findScreenshots(dir), { files: [], errors: [] });
  });

  test('sortiert numerisch statt lexikalisch und ignoriert versteckte Dateien', () => {
    const dir = writeLang('de-DE', { images: { '10.png': png(1080, 1920), '2.png': png(1080, 1920), '1.png': png(1080, 1920), '.gitkeep': '' } });
    assert.deepEqual(findScreenshots(dir).files.map((f) => f.name), ['1.png', '2.png', '10.png']);
  });

  test('meldet Dateinamen ohne Nummer und doppelte Nummern', () => {
    const dir = writeLang('de-DE', { images: { 'start.png': png(1080, 1920), '1.png': png(1080, 1920), '01.jpg': jpeg(1080, 1920) } });
    const { errors } = findScreenshots(dir);
    assert.equal(errors.length, 2);
    assert.match(errors.map((e) => e.rule).join('|'), /<Zahl>\.<Endung>/);
    assert.match(errors.map((e) => e.rule).join('|'), /gleiche Nummer/);
  });
});

describe('validateScreenshots', () => {
  function check(images) {
    const dir = writeLang('xx', { images });
    return validateScreenshots(findScreenshots(dir).files);
  }

  test('gültige PNG und JPEG passieren, mit passendem MIME-Typ', () => {
    const { errors, images } = check({ '1.png': png(1080, 1920), '2.jpg': jpeg(1920, 1080), '3.jpeg': jpeg(320, 640) });
    assert.deepEqual(errors, []);
    assert.deepEqual(images.map((i) => i.mimeType), ['image/png', 'image/jpeg', 'image/jpeg']);
  });

  test('zu wenige und zu viele Bilder', () => {
    assert.match(check({ '1.png': png(1080, 1920) }).errors[0].rule, /1 Bilder, erlaubt sind 2 bis 8/);
    const nine = Object.fromEntries(Array.from({ length: 9 }, (_, k) => [`${k + 1}.png`, png(1080, 1920)]));
    assert.match(check(nine).errors[0].rule, /9 Bilder/);
  });

  test('falsches Format, falsche Endung, Kantenlänge, Seitenverhältnis, Dateigröße', () => {
    const cases = [
      [{ '1.gif': Buffer.from('GIF89a'), '2.png': png(1080, 1920) }, /nur PNG oder JPEG/],
      [{ '1.png': jpeg(1080, 1920), '2.png': png(1080, 1920) }, /passt nicht zum Inhalt/],
      [{ '1.png': Buffer.from('kein Bild'), '2.png': png(1080, 1920) }, /kein gültiges PNG oder JPEG/],
      [{ '1.png': png(319, 600), '2.png': png(1080, 1920) }, /320 bis 3840/],
      [{ '1.png': png(1920, 3841), '2.png': png(1080, 1920) }, /320 bis 3840/],
      [{ '1.png': png(1000, 2001), '2.png': png(1080, 1920) }, /doppelt so lang/],
      [{ '1.png': png(1080, 1920, 8 * 1024 * 1024 + 1), '2.png': png(1080, 1920) }, /höchstens 8388608/],
    ];
    for (const [images, rule] of cases) {
      const { errors } = check(images);
      assert.equal(errors.length, 1, `erwartet genau einen Fehler für ${rule}`);
      assert.match(errors[0].rule, rule);
      assert.match(errors[0].file, /1\.(gif|png)$/);
      fs.rmSync(path.join(root, 'xx'), { recursive: true, force: true });
    }
  });

  test('Grenzwerte sind erlaubt (genau 2:1, 320 und 3840 px, genau 8 MB)', () => {
    const { errors } = check({ '1.png': png(1920, 3840, 8 * 1024 * 1024), '2.png': png(320, 640) });
    assert.deepEqual(errors, []);
  });
});

describe('Synchronisierung', () => {
  test('ohne Bilder-Ordner: nur Texte, keine Bild-Aufrufe, Texte wie bisher', async () => {
    writeLang('en-US', { title: 'Work Time Manager' });
    writeLang('de-DE', { title: 'Arbeitszeit Manager' });
    const fetch = fakeFetch();
    assert.equal(await runWith(fetch), 0);
    assert.deepEqual(short(fetch.calls), [
      'POST E',
      'PUT E/edit-1/listings/de-DE',
      'PUT E/edit-1/listings/en-US',
      'POST E/edit-1:commit',
    ]);
    const put = fetch.calls[1];
    assert.equal(put.contentType, 'application/json');
    assert.equal(put.authorization, 'Bearer test-token');
    assert.deepEqual(JSON.parse(put.body), {
      language: 'de-DE',
      title: 'Arbeitszeit Manager',
      shortDescription: 'Kurz de-DE',
      fullDescription: 'Lang de-DE\n\nZeile 2',
    });
  });

  test('leerer Bilder-Ordner (nur .gitkeep) löscht nichts', async () => {
    writeLang('de-DE', { images: { '.gitkeep': '' } });
    const fetch = fakeFetch();
    assert.equal(await runWith(fetch), 0);
    assert.ok(!fetch.calls.some((c) => c.url.includes('phoneScreenshots')));
  });

  test('gültige Bilder: deleteall, Uploads in Reihenfolge 1, 2, 10, dann Commit', async () => {
    const one = png(1080, 1920);
    writeLang('de-DE', { images: { '10.png': png(1080, 2160), '2.jpg': jpeg(1080, 1920), '1.png': one } });
    writeLang('en-US');
    const fetch = fakeFetch();
    const logs = [];
    assert.equal(await runWith(fetch, { log: (m) => logs.push(m) }), 0);
    const shots = 'edit-1/listings/de-DE/phoneScreenshots';
    assert.deepEqual(short(fetch.calls), [
      'POST E',
      'PUT E/edit-1/listings/de-DE',
      `DELETE E/${shots}`,
      `POST U/${shots}?uploadType=media`,
      `POST U/${shots}?uploadType=media`,
      `POST U/${shots}?uploadType=media`,
      'PUT E/edit-1/listings/en-US',
      'POST E/edit-1:commit',
    ]);
    const uploads = fetch.calls.filter((c) => c.url.startsWith(UPLOADS));
    assert.deepEqual(uploads.map((c) => c.contentType), ['image/png', 'image/jpeg', 'image/png']);
    assert.ok(uploads[0].body.equals(one), 'Rohdaten von 1.png');
    assert.equal(uploads[1].body.readUInt16BE(0), 0xffd8);
    assert.equal(uploads[2].body.readUInt32BE(16), 1080);
    assert.equal(fetch.calls[2].body, undefined, 'deleteall ohne Body');
    assert.ok(logs.includes('Replaced phoneScreenshots for de-DE: 3 Bilder (1.png, 2.jpg, 10.png)'));
    assert.ok(logs.some((l) => l.startsWith('Keine Phone-Screenshots für en-US')));
    assert.ok(!logs.some((l) => l.includes('test-token')), 'Token nie im Log');
  });

  test('ungültiges Bild: Abbruch mit Datei und Regel, kein einziger API-Aufruf', async () => {
    writeLang('de-DE', { images: { '1.png': png(1080, 1920), '2.png': png(1080, 1920) } });
    writeLang('en-US', { images: { '1.png': png(1080, 1920), '2.png': png(100, 1920) } });
    const fetch = fakeFetch();
    let tokenRequested = false;
    await assert.rejects(
      runWith(fetch, { getToken: async () => { tokenRequested = true; return 'test-token'; } }),
      (err) => {
        assert.match(err.message, /en-US[\\/]images[\\/]phoneScreenshots[\\/]2\.png: 100x1920 px/);
        assert.equal(err.validation.length, 1);
        return true;
      },
    );
    assert.deepEqual(fetch.calls, []);
    assert.equal(tokenRequested, false);
  });

  test('Upload-Fehler: kein Commit, Lauf schlägt fehl', async () => {
    writeLang('de-DE', { images: { '1.png': png(1080, 1920), '2.png': png(1080, 1920) } });
    let uploads = 0;
    const fetch = fakeFetch({
      fail: (c) => (c.url.startsWith(UPLOADS) && ++uploads === 2 ? { status: 500, body: 'backend error' } : null),
    });
    await assert.rejects(runWith(fetch), /Upload phoneScreenshot de-DE\/2\.png failed \(500\): backend error/);
    assert.ok(!fetch.calls.some((c) => c.url.includes(':commit')));
  });

  test('deleteall-Fehler: keine Uploads, kein Commit', async () => {
    writeLang('de-DE', { images: { '1.png': png(1080, 1920), '2.png': png(1080, 1920) } });
    const fetch = fakeFetch({ fail: (c) => (c.method === 'DELETE' ? { status: 409, body: 'conflict' } : null) });
    await assert.rejects(runWith(fetch), /Delete phoneScreenshots de-DE failed \(409\)/);
    assert.ok(!fetch.calls.some((c) => c.url.startsWith(UPLOADS) || c.url.includes(':commit')));
  });

  test('Commit verlangt changesNotSentForReview: neuer Edit mit allen Schritten und Parameter', async () => {
    writeLang('de-DE', { images: { '1.png': png(1080, 1920), '2.png': png(1080, 1920) } });
    let commits = 0;
    const fetch = fakeFetch({
      fail: (c) => (c.url.endsWith(':commit') && ++commits === 1 ? { status: 400, body: 'please set changesNotSentForReview' } : null),
    });
    assert.equal(await runWith(fetch), 0);
    const s = short(fetch.calls);
    assert.equal(s.filter((x) => x === 'POST E').length, 2);
    assert.equal(s.filter((x) => x.startsWith('DELETE')).length, 2);
    assert.equal(s.at(-1), 'POST E/edit-1:commit?changesNotSentForReview=true');
  });

  test('403 beim Commit: Hinweis auf die Berechtigung, Exit-Code 1', async () => {
    writeLang('de-DE');
    const errors = [];
    const fetch = fakeFetch({ fail: (c) => (c.url.endsWith(':commit') ? { status: 403, body: 'PERMISSION_DENIED' } : null) });
    assert.equal(await runWith(fetch, { error: (m) => errors.push(m) }), 1);
    assert.match(errors[0], /Präsenz im Play Store verwalten/);
  });

  test('Text-Fehler bricht ab wie bisher', async () => {
    writeLang('de-DE');
    const fetch = fakeFetch({ fail: (c) => (c.method === 'PUT' ? { status: 400, body: 'bad title' } : null) });
    await assert.rejects(runWith(fetch), /Update listing de-DE failed \(400\): bad title/);
    assert.ok(!fetch.calls.some((c) => c.url.includes(':commit')));
  });

  test('syncListings ohne Sprachen legt Edit an und committet', async () => {
    const fetch = fakeFetch();
    await syncListings({ token: 't', plan: [], fetchImpl: fetch.impl, log: () => {} });
    assert.deepEqual(short(fetch.calls), ['POST E', 'POST E/edit-1:commit']);
  });

  test('buildPlan liest Texte getrimmt ein', () => {
    writeLang('de-DE', { title: '  Arbeitszeit  ' });
    assert.equal(buildPlan(root)[0].title, 'Arbeitszeit');
  });
});

describe('getAccessToken', () => {
  test('signiert das JWT mit dem Service-Account-Schlüssel und liefert das Token', async () => {
    const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
    const sa = {
      client_email: 'sa@example.iam.gserviceaccount.com',
      private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }),
      token_uri: 'https://oauth2.example.test/token',
    };
    const fetch = fakeFetch();
    const token = await getAccessToken(sa, fetch.impl, () => 1_000_000_000_000);
    assert.equal(token, 'test-token');
    assert.equal(fetch.calls.length, 1);
    assert.equal(fetch.calls[0].url, sa.token_uri);
    const params = new URLSearchParams(fetch.calls[0].body);
    assert.equal(params.get('grant_type'), 'urn:ietf:params:oauth:grant-type:jwt-bearer');
    const [h, c, sig] = params.get('assertion').split('.');
    const claim = JSON.parse(Buffer.from(c, 'base64url'));
    assert.deepEqual(claim, {
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: sa.token_uri,
      iat: 1_000_000_000,
      exp: 1_000_003_600,
    });
    assert.ok(crypto.verify('RSA-SHA256', Buffer.from(`${h}.${c}`), publicKey, Buffer.from(sig, 'base64url')));
  });
});
