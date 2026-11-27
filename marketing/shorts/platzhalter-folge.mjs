// Platzhalter-Bildfolge für Probevideo und Tests: `node platzhalter-folge.mjs [--sprache de]`.
// Baut aus zwei App-Bildern (vor und nach dem Start) eine Folge im Format der echten Folgen aus
// `mobile/tool/` (H.264, 30 Bilder/s, ohne Ton, dazu <name>.json): 1 s vorher, kurze Überblendung
// beim Tipp, danach steht das zweite Bild. Echte Bewegung (laufender Timer) hat sie nicht.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const sprache = process.argv[2] === '--sprache' && process.argv[3] ? process.argv[3] : 'de';
const ordner = path.join(import.meta.dirname, 'frames', sprache);
const FPS = 30;
const TIPP = 30; // Bild des Tipps
const BLENDE = 6; // Bilder der Überblendung
const BILDER = 150;
const sek = (bilder) => (bilder / FPS).toFixed(4);

const ziel = path.join(ordner, 'platzhalter_folge.mp4');
execFileSync(
  process.env.SHORTS_FFMPEG || 'ffmpeg',
  [
    '-hide_banner', '-loglevel', 'error', '-nostdin', '-y',
    '-loop', '1', '-framerate', String(FPS), '-t', sek(TIPP + BLENDE), '-i', path.join(ordner, 'dashboard_vor_start.png'),
    '-loop', '1', '-framerate', String(FPS), '-t', sek(BILDER - TIPP), '-i', path.join(ordner, 'dashboard_gestartet.png'),
    '-filter_complex', `[0:v][1:v]xfade=transition=fade:duration=${sek(BLENDE)}:offset=${sek(TIPP)},format=yuv420p[v]`,
    '-map', '[v]', '-frames:v', String(BILDER), '-r', String(FPS), '-an',
    '-c:v', 'libx264', '-crf', '14', '-preset', 'slow', '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-movflags', '+faststart',
    ziel,
  ],
  { stdio: 'inherit' },
);
const beschreibung = {
  fps: FPS,
  bilder: BILDER,
  marken: { tipp: TIPP, gestartet: TIPP + BLENDE },
  ausschnitte: {
    timer: { x: 0.2, y: 0.095, breite: 0.6, hoehe: 0.085 },
    start_knopf: { x: 0.08, y: 0.86, breite: 0.84, hoehe: 0.06 },
    feierabend_zeile: { x: 0.18, y: 0.458, breite: 0.64, hoehe: 0.034 },
  },
};
fs.writeFileSync(path.join(ordner, 'platzhalter_folge.json'), `${JSON.stringify(beschreibung, null, 2)}\n`);
console.log(`Fertig: ${path.relative(import.meta.dirname, ziel)} (${BILDER} Bilder) und platzhalter_folge.json`);
