// Tonspur mit ffmpeg: Sätze an ihre Startzeit legen, optional Musik darunter, Lautheit einstellen.
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const starte = promisify(execFile);
const FFMPEG = process.env.SHORTS_FFMPEG || 'ffmpeg';

async function ffmpeg(args) {
  try {
    return await starte(FFMPEG, ['-hide_banner', '-nostdin', '-y', ...args], { maxBuffer: 64 * 1024 * 1024 });
  } catch (fehler) {
    throw new Error(`ffmpeg ist gescheitert:\n${String(fehler.stderr ?? fehler.message).trim().split('\n').slice(-8).join('\n')}`);
  }
}

/** Filtergraph der Rohmischung (ohne Lautheitskorrektur). Reine Funktion. */
export function mischFilter(saetze, sekunden, { musik = false, musikDb = -20 } = {}) {
  const teile = [];
  const namen = [];
  saetze.forEach((satz, i) => {
    const ms = Math.round(satz.tonStart * 1000);
    teile.push(`[${i}:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,adelay=${ms}:all=1[s${i}]`);
    namen.push(`[s${i}]`);
  });
  if (musik) {
    const aus = Math.max(0, sekunden - 1).toFixed(3);
    teile.push(
      `[${saetze.length}:a]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,volume=${musikDb}dB,afade=t=out:st=${aus}:d=1[m]`,
    );
    namen.push('[m]');
  }
  // Stille als Grundlage: legt die Gesamtlänge fest, auch wenn kein Satz gesprochen wird.
  const stille = `anullsrc=r=48000:cl=stereo,atrim=duration=${sekunden.toFixed(3)}[st]`;
  teile.push(stille);
  teile.push(`[st]${namen.join('')}amix=inputs=${namen.length + 1}:duration=first:normalize=0[aus]`);
  return teile.join(';');
}

/** Integrierte Lautheit (LUFS) und Spitzenpegel (dBTP) einer Datei, gemessen mit EBU R128. */
export async function messeLautheit(datei) {
  const { stderr } = await ffmpeg(['-i', datei, '-map', '0:a:0', '-af', 'loudnorm=print_format=json', '-f', 'null', '-']);
  const json = /\{[^{}]*"input_i"[^{}]*\}/.exec(stderr);
  if (!json) throw new Error(`Lautheit von ${datei} nicht messbar`);
  const werte = JSON.parse(json[0]);
  return { lufs: Number(werte.input_i), spitze: Number(werte.input_tp) };
}

/**
 * Schreibt die fertige Tonspur (WAV, 48 kHz, Stereo) in der Länge des Videos.
 *
 * Lautheit: Pegel der Rohmischung messen, anheben und begrenzen, nachmessen und die
 * Abweichung ausgleichen (der Begrenzer nimmt etwas Lautheit weg). Enthält die Mischung
 * keinen Ton, bleibt sie still.
 *
 * @param {{saetze: {datei: string, tonStart: number}[], sekunden: number, musik?: string,
 *   ziel: string, roh: string, lufs?: number, spitzeDb?: number, musikDb?: number}} auftrag
 * @returns {Promise<{lufs: number|null, spitze: number|null}>} Messwert der fertigen Spur
 */
export async function baueTonspur({ saetze, sekunden, musik, ziel, roh, lufs = -14, spitzeDb = -1.5, musikDb = -20 }) {
  const eingaben = saetze.flatMap((s) => ['-i', s.datei]);
  if (musik) eingaben.push('-stream_loop', '-1', '-i', musik);
  const filter = mischFilter(saetze, sekunden, { musik: Boolean(musik), musikDb });
  await ffmpeg([...eingaben, '-filter_complex', filter, '-map', '[aus]', '-t', sekunden.toFixed(3), '-c:a', 'pcm_f32le', roh]);

  const start = await messeLautheit(roh);
  const grenze = 10 ** (spitzeDb / 20);
  const schreibe = (db) =>
    ffmpeg(['-i', roh, '-af', `volume=${db.toFixed(2)}dB,alimiter=limit=${grenze.toFixed(4)}:level=false:attack=5:release=50,aresample=48000`, '-c:a', 'pcm_s16le', ziel]);
  if (!Number.isFinite(start.lufs)) {
    await schreibe(0);
    return { lufs: null, spitze: null };
  }
  let db = lufs - start.lufs;
  let messung;
  for (let runde = 0; runde < 4; runde++) {
    await schreibe(db);
    messung = await messeLautheit(ziel);
    if (Math.abs(messung.lufs - lufs) <= 0.2) break;
    db += lufs - messung.lufs;
  }
  return messung;
}

/** Bild (ohne Ton) und Tonspur zu einem MP4 verbinden: Bild unverändert, Ton AAC 48 kHz. */
export async function verbinde(bild, ton, ziel) {
  await ffmpeg(['-i', bild, '-i', ton, '-map', '0:v:0', '-map', '1:a:0', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-ar', '48000', '-movflags', '+faststart', ziel]);
}
