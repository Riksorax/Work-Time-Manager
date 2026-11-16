import assert from 'node:assert/strict';
import test from 'node:test';
import { mischFilter } from '../lib/ton.mjs';

const saetze = [{ tonStart: 0.1 }, { tonStart: 2.5 }];

test('Sätze liegen an ihrer Startzeit, die Stille legt die Länge fest', () => {
  const filter = mischFilter(saetze, 6);
  assert.match(filter, /\[0:a\][^;]*adelay=100:all=1\[s0\]/);
  assert.match(filter, /\[1:a\][^;]*adelay=2500:all=1\[s1\]/);
  assert.match(filter, /atrim=duration=6\.000\[st\]/);
  assert.match(filter, /\[st\]\[s0\]\[s1\]amix=inputs=3:duration=first:normalize=0\[aus\]$/);
  assert.doesNotMatch(filter, /aevalsrc/);
});

test('je Tipp ein erzeugter Klick zum Zeitpunkt des Tipps, ohne Tondatei', () => {
  const filter = mischFilter(saetze, 6, { tipps: [3.2, 4], tippDb: -9 });
  assert.match(filter, /aevalsrc=[^;]*volume=-9dB,adelay=3200:all=1\[t0\]/);
  assert.match(filter, /adelay=4000:all=1\[t1\]/);
  assert.match(filter, /\[st\]\[s0\]\[s1\]\[t0\]\[t1\]amix=inputs=5:/);
});

test('Musik kommt als weitere Eingabe nach den Sätzen', () => {
  const filter = mischFilter(saetze, 6, { musik: true, musikDb: -18, tipps: [1] });
  assert.match(filter, /\[2:a\][^;]*volume=-18dB,afade=t=out:st=5\.000:d=1\[m\]/);
  assert.match(filter, /\[st\]\[s0\]\[s1\]\[m\]\[t0\]amix=inputs=5:/);
});
