import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseIco, packIco } from '../lib/ico.mjs';
import { readPngHeader, decodePng } from '../lib/png.mjs';
import { built } from './support.mjs';

test('favicon.ico enthält genau die Einträge 16, 32 und 48', () => {
  const entries = parseIco(built('web/public/favicon.ico'));
  assert.deepEqual(
    entries.map((e) => [e.width, e.height]),
    [[16, 16], [32, 32], [48, 48]],
  );
});

test('favicon.ico: jeder Eintrag ist ein gültiges PNG der angegebenen Größe', () => {
  const buf = built('web/public/favicon.ico');
  assert.equal(buf.readUInt16LE(0), 0, 'reserviert');
  assert.equal(buf.readUInt16LE(2), 1, 'Typ Icon');
  for (const e of parseIco(buf)) {
    const h = readPngHeader(e.data);
    assert.deepEqual([h.width, h.height], [e.width, e.height]);
    const img = decodePng(e.data);
    assert.ok(img.pixels.some((v, i) => i % 4 === 3 && v > 0), 'Eintrag ist leer');
  }
});

test('ICO-Packer: Verzeichnis zeigt auf die Daten, 256 px wird nicht akzeptiert', () => {
  const a = Buffer.from('aaaa');
  const b = Buffer.from('bbbbbb');
  const buf = packIco([{ size: 16, data: a }, { size: 32, data: b }]);
  const parsed = parseIco(buf);
  assert.equal(parsed[0].data.toString(), 'aaaa');
  assert.equal(parsed[1].data.toString(), 'bbbbbb');
  assert.throws(() => packIco([{ size: 256, data: a }]));
});
