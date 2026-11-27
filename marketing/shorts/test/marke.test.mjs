import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { LOGO, SCHRIFT_DATEIEN, ladeMarke, verlauf } from '../lib/marke.mjs';

test('Farben, Name und Schrift kommen aus branding/', () => {
  const marke = ladeMarke();
  assert.equal(marke.name, 'Work Time Manager');
  assert.equal(marke.schrift, 'Open Sans');
  for (const farbe of [...marke.grund, ...marke.akzent]) assert.match(farbe, /^#[0-9a-f]{6}$/);
  assert.equal(marke.grund.length, 2);
  assert.equal(marke.akzent.length, 2);
});

test('Logo und Schriftdateien liegen im Repo', () => {
  for (const datei of [LOGO, ...Object.values(SCHRIFT_DATEIEN)]) assert.ok(fs.existsSync(datei), datei);
});

test('fehlender Verlauf ist ein Fehler', () => {
  assert.throws(() => verlauf('<svg/>', 'bg'), /Verlauf „bg“ nicht gefunden/);
  assert.deepEqual(verlauf('<linearGradient id="a" x1="0"><stop stop-color="#AABBCC"/><stop stop-color="#000000"/></linearGradient>', 'a'), ['#aabbcc', '#000000']);
});
