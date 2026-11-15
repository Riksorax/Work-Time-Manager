// Synchronisiert die Store-Präsenz (Texte und Phone-Screenshots) aus
// fastlane/metadata/android nach Google Play (Android Publisher API v3, #559).
//
// Aufruf im Workflow `flutter-production.yml`, Job `sync-metadata`:
//   PLAY_STORE_JSON_KEY=... node .github/scripts/sync-store-metadata.mjs
//
// Ablauf: alle Sprachen einlesen und die Bilder prüfen (ohne Netz), erst dann
// Token holen, Edit anlegen, je Sprache Texte setzen und (falls Bilder da sind)
// die Phone-Screenshots ersetzen, zuletzt den Edit committen. Schlägt ein
// Schritt fehl, wird nicht committet; der Store bleibt dann unverändert.
//
// Die reine Logik ist exportiert und mit `node --test` ohne Netz testbar
// (`fetch` ist injizierbar), siehe sync-store-metadata.test.mjs.

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const PACKAGE_NAME = 'app.work_time_manager';
export const METADATA_ROOT = 'fastlane/metadata/android';
export const SCREENSHOT_DIR = path.join('images', 'phoneScreenshots');

/** Regeln von Google Play für Phone-Screenshots. */
export const SCREENSHOT_RULES = Object.freeze({
  minCount: 2,
  maxCount: 8,
  maxBytes: 8 * 1024 * 1024,
  minEdge: 320,
  maxEdge: 3840,
  maxAspect: 2,
});

const API_BASE = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
const UPLOAD_BASE = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications';

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

/**
 * Liest Format und Maße aus dem Datei-Header (PNG: IHDR, JPEG: SOF-Segment).
 * Gibt `null` zurück, wenn die Daten weder PNG noch JPEG sind oder der Header
 * keine Maße enthält.
 */
export function readImageInfo(buf) {
  if (buf.length >= 24 && buf.subarray(0, 8).equals(PNG_SIGNATURE)) {
    if (buf.toString('latin1', 12, 16) !== 'IHDR') return null;
    return { format: 'png', mimeType: 'image/png', width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
  }
  if (buf.length >= 4 && buf[0] === 0xff && buf[1] === 0xd8) {
    let i = 2;
    while (i < buf.length) {
      if (buf[i] !== 0xff) return null;
      while (i < buf.length && buf[i] === 0xff) i++; // Füllbytes
      if (i >= buf.length) return null;
      const marker = buf[i++];
      // Marker ohne Längenfeld: TEM, RST0–7, SOI
      if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd8)) continue;
      if (marker === 0xd9 || marker === 0xda) return null; // EOI/SOS vor einem SOF
      if (i + 2 > buf.length) return null;
      const len = buf.readUInt16BE(i);
      if (len < 2) return null;
      const isSof = marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
      if (isSof) {
        if (i + 7 > buf.length) return null;
        return { format: 'jpeg', mimeType: 'image/jpeg', width: buf.readUInt16BE(i + 5), height: buf.readUInt16BE(i + 3) };
      }
      i += len;
    }
  }
  return null;
}

/**
 * Findet die Phone-Screenshots einer Sprache, numerisch nach Dateiname sortiert
 * (1, 2, 10). Fehlt der Ordner, ist die Liste leer. Versteckte Dateien
 * (z. B. `.gitkeep`) zählen nicht. Dateinamen, die nicht dem Muster `<Zahl>.<Endung>`
 * folgen, landen in `errors`.
 */
export function findScreenshots(langDir) {
  const dir = path.join(langDir, SCREENSHOT_DIR);
  if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) return { files: [], errors: [] };
  const files = [];
  const errors = [];
  for (const name of fs.readdirSync(dir)) {
    if (name.startsWith('.')) continue;
    const full = path.join(dir, name);
    if (!fs.statSync(full).isFile()) continue;
    const match = /^(\d+)\.[^.]+$/.exec(name);
    if (!match) {
      errors.push({ file: full, rule: 'Dateiname muss <Zahl>.<Endung> sein (z. B. 1.png), damit die Reihenfolge feststeht' });
      continue;
    }
    files.push({ name, path: full, index: Number(match[1]) });
  }
  files.sort((a, b) => a.index - b.index || a.name.localeCompare(b.name));
  for (let k = 1; k < files.length; k++) {
    if (files[k].index === files[k - 1].index) {
      errors.push({ file: files[k].path, rule: `gleiche Nummer wie ${files[k - 1].name}` });
    }
  }
  return { files, errors };
}

/**
 * Prüft die Screenshots einer Sprache gegen SCREENSHOT_RULES. Liest jede Datei
 * ein und gibt die Fehler sowie die geprüften Bilder (mit Inhalt und MIME-Typ) zurück.
 */
export function validateScreenshots(files, rules = SCREENSHOT_RULES) {
  const errors = [];
  const images = [];
  if (files.length === 0) return { errors, images };
  if (files.length < rules.minCount || files.length > rules.maxCount) {
    const dir = path.dirname(files[0].path);
    errors.push({ file: dir, rule: `${files.length} Bilder, erlaubt sind ${rules.minCount} bis ${rules.maxCount}` });
  }
  for (const f of files) {
    const ext = path.extname(f.name).toLowerCase();
    if (!['.png', '.jpg', '.jpeg'].includes(ext)) {
      errors.push({ file: f.path, rule: 'nur PNG oder JPEG erlaubt (.png, .jpg, .jpeg)' });
      continue;
    }
    const size = fs.statSync(f.path).size;
    if (size > rules.maxBytes) {
      errors.push({ file: f.path, rule: `${size} Bytes, höchstens ${rules.maxBytes} (8 MB) erlaubt` });
      continue;
    }
    const data = fs.readFileSync(f.path);
    const info = readImageInfo(data);
    if (!info) {
      errors.push({ file: f.path, rule: 'kein gültiges PNG oder JPEG (Header ohne Maße)' });
      continue;
    }
    if ((info.format === 'png') !== (ext === '.png')) {
      errors.push({ file: f.path, rule: `Endung ${ext} passt nicht zum Inhalt (${info.format.toUpperCase()})` });
      continue;
    }
    const { width, height } = info;
    const shorter = Math.min(width, height);
    const longer = Math.max(width, height);
    if (shorter < rules.minEdge || longer > rules.maxEdge) {
      errors.push({ file: f.path, rule: `${width}x${height} px, jede Kante muss ${rules.minEdge} bis ${rules.maxEdge} px lang sein` });
      continue;
    }
    if (longer > rules.maxAspect * shorter) {
      errors.push({ file: f.path, rule: `${width}x${height} px, die längere Kante darf höchstens doppelt so lang sein wie die kürzere` });
      continue;
    }
    images.push({ name: f.name, data, mimeType: info.mimeType, width, height });
  }
  return { errors, images };
}

/**
 * Liest Texte und Screenshots aller Sprachen ein und prüft die Bilder.
 * Wirft bei einem Verstoß, bevor irgendein API-Aufruf passiert.
 */
export function buildPlan(metadataRoot = METADATA_ROOT) {
  const langs = fs
    .readdirSync(metadataRoot)
    .filter((d) => fs.statSync(path.join(metadataRoot, d)).isDirectory())
    .sort();
  const plan = [];
  const errors = [];
  for (const lang of langs) {
    const dir = path.join(metadataRoot, lang);
    const read = (file) => fs.readFileSync(path.join(dir, file), 'utf8').trim();
    const found = findScreenshots(dir);
    const checked = validateScreenshots(found.files);
    errors.push(...found.errors, ...checked.errors);
    plan.push({
      lang,
      title: read('title.txt'),
      shortDescription: read('short_description.txt'),
      fullDescription: read('full_description.txt'),
      screenshots: checked.images,
    });
  }
  if (errors.length > 0) {
    const lines = errors.map((e) => `  - ${e.file}: ${e.rule}`).join('\n');
    const err = new Error(`Store-Screenshots verletzen die Regeln von Google Play, es wurde nichts geändert:\n${lines}`);
    err.validation = errors;
    throw err;
  }
  return plan;
}

/** Holt ein OAuth-Token für den Service-Account (JWT-Bearer-Flow). */
export async function getAccessToken(sa, fetchImpl = fetch, now = () => Date.now()) {
  const b64url = (input) => Buffer.from(input).toString('base64url');
  const iat = Math.floor(now() / 1000);
  const tokenUri = sa.token_uri || 'https://oauth2.googleapis.com/token';
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: tokenUri,
      iat,
      exp: iat + 3600,
    }),
  );
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(`${header}.${claim}`);
  const jwt = `${header}.${claim}.${sign.sign(sa.private_key, 'base64url')}`;

  const res = await fetchImpl(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`OAuth token error (${res.status}): ${await res.text()}`);
  }
  const data = await res.json();
  return data.access_token;
}

/** Ein Edit: Texte und Screenshots je Sprache setzen, danach committen. */
export async function syncListings({
  token,
  plan,
  changesNotSentForReview = false,
  fetchImpl = fetch,
  log = console.log,
  packageName = PACKAGE_NAME,
}) {
  const baseUrl = `${API_BASE}/${packageName}/edits`;
  const uploadBase = `${UPLOAD_BASE}/${packageName}/edits`;
  const auth = { Authorization: `Bearer ${token}` };
  const headers = { ...auth, 'Content-Type': 'application/json' };

  const createRes = await fetchImpl(baseUrl, { method: 'POST', headers, body: '{}' });
  if (!createRes.ok) {
    throw new Error(`Create edit failed (${createRes.status}): ${await createRes.text()}`);
  }
  const { id: editId } = await createRes.json();
  log(`Created Google Play edit: ${editId}`);

  for (const entry of plan) {
    const { lang, title, shortDescription, fullDescription } = entry;
    const putRes = await fetchImpl(`${baseUrl}/${editId}/listings/${lang}`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({ language: lang, title, shortDescription, fullDescription }),
    });
    if (!putRes.ok) {
      throw new Error(`Update listing ${lang} failed (${putRes.status}): ${await putRes.text()}`);
    }
    log(`Updated store listing for ${lang} ("${title}")`);

    if (entry.screenshots.length === 0) {
      log(`Keine Phone-Screenshots für ${lang} im Repo, Screenshots im Store bleiben unverändert`);
      continue;
    }

    const imagesPath = `${editId}/listings/${lang}/phoneScreenshots`;
    const delRes = await fetchImpl(`${baseUrl}/${imagesPath}`, { method: 'DELETE', headers: auth });
    if (!delRes.ok) {
      throw new Error(`Delete phoneScreenshots ${lang} failed (${delRes.status}): ${await delRes.text()}`);
    }
    for (const img of entry.screenshots) {
      const upRes = await fetchImpl(`${uploadBase}/${imagesPath}?uploadType=media`, {
        method: 'POST',
        headers: { ...auth, 'Content-Type': img.mimeType },
        body: img.data,
      });
      if (!upRes.ok) {
        throw new Error(`Upload phoneScreenshot ${lang}/${img.name} failed (${upRes.status}): ${await upRes.text()}`);
      }
    }
    const names = entry.screenshots.map((img) => img.name).join(', ');
    log(`Replaced phoneScreenshots for ${lang}: ${entry.screenshots.length} Bilder (${names})`);
  }

  const commitUrl = `${baseUrl}/${editId}:commit${changesNotSentForReview ? '?changesNotSentForReview=true' : ''}`;
  const commitRes = await fetchImpl(commitUrl, { method: 'POST', headers });
  if (!commitRes.ok) {
    const body = await commitRes.text();
    const err = new Error(`Commit edit failed (${commitRes.status}): ${body}`);
    err.status = commitRes.status;
    err.body = body;
    throw err;
  }
  log(`Committed Google Play edit ${editId} (changesNotSentForReview=${changesNotSentForReview})`);
}

/**
 * Gesamtlauf. Gibt den Exit-Code zurück (0 = erfolgreich). Prüft erst alle
 * Dateien, holt dann das Token und synchronisiert; verlangt der Commit
 * `changesNotSentForReview=true`, läuft alles in einem neuen Edit noch einmal.
 */
export async function run({
  serviceAccountJson,
  metadataRoot = METADATA_ROOT,
  fetchImpl = fetch,
  log = console.log,
  warn = console.warn,
  error = console.error,
  getToken = getAccessToken,
}) {
  const plan = buildPlan(metadataRoot);
  const sa = JSON.parse(serviceAccountJson);
  const token = await getToken(sa, fetchImpl);
  try {
    await syncListings({ token, plan, changesNotSentForReview: false, fetchImpl, log });
  } catch (err) {
    if (err.status === 400 && err.body && err.body.includes('changesNotSentForReview')) {
      warn('Standard commit requires changesNotSentForReview=true, retrying...');
      await syncListings({ token, plan, changesNotSentForReview: true, fetchImpl, log });
    } else if (err.status === 403) {
      error(
        `::error::Google Play API 403 PERMISSION_DENIED beim Speichern der Store-Texte. ` +
          `Dem Service-Account (${sa.client_email}) fehlt in der Google Play Console unter ` +
          `"Nutzer und Berechtigungen -> App-Berechtigungen" der Haken bei ` +
          `"Präsenz im Play Store verwalten" (Manage store presence).`,
      );
      error(`API-Antwort: ${err.body}`);
      return 1;
    } else {
      throw err;
    }
  }
  return 0;
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  run({ serviceAccountJson: process.env.PLAY_STORE_JSON_KEY })
    .then((code) => process.exit(code))
    .catch((err) => {
      if (err.validation) {
        console.error(`::error::${err.message.split('\n')[0]}`);
        console.error(err.message);
      } else {
        console.error(err);
      }
      process.exit(1);
    });
}
