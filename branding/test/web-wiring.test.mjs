// Verdrahtung der erzeugten Web-Assets (#437, PR 2): Manifest und index.html verweisen auf existierende,
// passend große Dateien. Liest die echten Dateien aus web/.
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { decodePng } from '../lib/png.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const pub = (f) => join(root, 'web', 'public', f);
const manifest = JSON.parse(readFileSync(pub('manifest.json'), 'utf8'));
const html = readFileSync(join(root, 'web', 'src', 'index.html'), 'utf8');
const bare = (src) => src.replace(/[?#].*$/, '');
const CACHE_BUST = '?v=170';

test('Manifest: jede icon-src existiert, PNG-Größen stimmen', () => {
  for (const icon of manifest.icons) {
    const file = pub(bare(icon.src));
    assert.ok(existsSync(file), `${icon.src} fehlt`);
    if (icon.type === 'image/png') {
      const img = decodePng(readFileSync(file));
      assert.equal(`${img.width}x${img.height}`, icon.sizes, icon.src);
    }
  }
});

test('Manifest: any und maskable nutzen nie dieselbe Datei, 192 und 512 je vorhanden', () => {
  const by = (p) => manifest.icons.filter((i) => (i.purpose ?? 'any') === p);
  const anySrc = by('any').map((i) => bare(i.src));
  const maskSrc = by('maskable').map((i) => bare(i.src));
  for (const s of maskSrc) assert.ok(!anySrc.includes(s), `${s} ist any und maskable`);
  for (const size of ['192x192', '512x512']) {
    assert.ok(by('any').some((i) => i.sizes === size), `any ${size}`);
    assert.ok(by('maskable').some((i) => i.sizes === size), `maskable ${size}`);
  }
  assert.ok(maskSrc.every((s) => s.includes('maskable')));
});

test('Manifest: kein Icon kombiniert Zwecke ("any maskable")', () => {
  for (const i of manifest.icons) assert.doesNotMatch(i.purpose ?? 'any', /\s/);
});

test('Manifest: theme_color bleibt #1565C0', () => {
  assert.equal(manifest.theme_color, '#1565C0');
});

test('index.html: favicon.svg steht vor allen anderen rel=icon-Links', () => {
  const icons = [...html.matchAll(/<link rel="icon"[^>]*>/g)].map((m) => m[0]);
  assert.match(icons[0], /favicon\.svg/);
  assert.match(icons[0], /image\/svg\+xml/);
});

test('index.html: alle lokalen Icon-/Bild-Verweise existieren und tragen ?v=170', () => {
  const refs = [...html.matchAll(/<link rel="(?:icon|apple-touch-icon|manifest)"[^>]*href="([^"]+)"/g)].map((m) => m[1]);
  refs.push(...[...html.matchAll(/(?:og:image"|twitter:image") content="([^"]+)"/g)].map((m) => m[1]));
  assert.ok(refs.length >= 8, `zu wenige Verweise: ${refs.length}`);
  for (const ref of refs) {
    const path = ref.replace(/^https:\/\/work-time-manager\.app\//, '');
    assert.ok(existsSync(pub(bare(path))), `${ref} fehlt in web/public`);
    assert.ok(path.endsWith(CACHE_BUST), `${ref} ohne ${CACHE_BUST}`);
  }
});

test('Manifest: lokale Icon-Verweise tragen ?v=170', () => {
  for (const i of manifest.icons) assert.ok(i.src.endsWith(CACHE_BUST), i.src);
});

test('nginx: Icon-Ausnahme steht vor der Bundle-Location und ist nicht immutable', () => {
  const conf = readFileSync(join(root, 'web', 'nginx.conf'), 'utf8');
  const exception = conf.indexOf('favicon');
  const bundle = conf.indexOf('immutable');
  assert.ok(exception > 0 && exception < bundle, 'Ausnahme muss vor der immutable-Location stehen');
  const block = conf.slice(exception, conf.indexOf('}', exception));
  assert.match(block, /no-cache/);
  assert.doesNotMatch(block, /immutable/);
});
