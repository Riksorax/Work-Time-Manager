// Rendert ein Video: `npm run render -- <id> [--sprache de]` (Beschreibung: README.md).
//
// Ablauf: Videobeschreibung prüfen → Stimme je Satz (tts/synth.py) → Zeitplan aus den
// Satzlängen → Tonspur (ffmpeg) → Bild (Remotion) → beides zu out/<id>.mp4 verbinden.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { bundle } from '@remotion/bundler';
import { renderMedia, renderStill, selectComposition } from '@remotion/renderer';
import YAML from 'yaml';
import { LOGO, SCHRIFT_DATEIEN, ladeMarke } from './lib/marke.mjs';
import { BeschreibungsFehler, pruefeBeschreibung, pruefeDauern } from './lib/schema.mjs';
import { baueTonspur, messeLautheit, verbinde } from './lib/ton.mjs';
import { berechneZeitplan } from './lib/zeit.mjs';
import { aufLeinwand, istFrei, szenenKamera } from './src/layout.mjs';
import { TEXTE } from './src/texte.mjs';

const HIER = import.meta.dirname;
const VORINSTALLIERT = '/opt/pw-browsers/chromium'; // Cloud-Umgebung (Playwright)

class Abbruch extends Error {}

function argumente(argv) {
  const ergebnis = { sprache: 'de', platzhalter: false, id: undefined };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--sprache' && argv[i + 1]) ergebnis.sprache = argv[++i];
    else if (argv[i] === '--platzhalter') ergebnis.platzhalter = true;
    else if (!argv[i].startsWith('-') && ergebnis.id === undefined) ergebnis.id = argv[i];
    else throw new Abbruch(`Unbekanntes Argument „${argv[i]}“`);
  }
  if (!ergebnis.platzhalter && !ergebnis.id) throw new Abbruch('Aufruf: npm run render -- <id> [--sprache de]');
  return ergebnis;
}

/** Breite und Höhe aus dem Kopf einer PNG-Datei. */
function pngMass(datei) {
  const kopf = Buffer.alloc(24);
  const fd = fs.openSync(datei, 'r');
  fs.readSync(fd, kopf, 0, 24, 0);
  fs.closeSync(fd);
  if (kopf.toString('latin1', 1, 4) !== 'PNG') throw new Abbruch(`${datei} ist keine PNG-Datei`);
  return { breite: kopf.readUInt32BE(16), hoehe: kopf.readUInt32BE(20) };
}

/** Breite und Höhe einer Bildfolge (MP4) über ffprobe. */
function videoMass(datei) {
  const text = execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', datei], { encoding: 'utf8' });
  const [breite, hoehe] = text.trim().split(',').map(Number);
  if (!(breite > 0 && hoehe > 0)) throw new Abbruch(`${datei}: Maße nicht lesbar (ffprobe)`);
  return { breite, hoehe };
}

/** Begleitdatei einer Bildfolge; `undefined`, wenn MP4 oder JSON fehlen oder das JSON nicht lesbar ist. */
function liesFolge(ordner, name) {
  try {
    if (!fs.existsSync(path.join(ordner, `${name}.mp4`))) return undefined;
    return JSON.parse(fs.readFileSync(path.join(ordner, `${name}.json`), 'utf8'));
  } catch {
    return undefined;
  }
}

/** Hinweis, wenn Tipp oder Hervorhebung am Ende der Kamerafahrt in einer Schutzzone liegen. */
function pruefeSchutzzonen(plan, masse) {
  plan.szenen.forEach((szene, i) => {
    if (szene.art !== 'app') return;
    const lage = szenenKamera(szene, masse[szene.quelle]);
    for (const feld of ['tipp', 'hervorhebung']) {
      if (szene[feld] && !istFrei(aufLeinwand(lage, masse[szene.quelle], szene[feld].rechteck))) {
        console.warn(`Hinweis: Szene ${i + 1}: Der Ausschnitt „${szene[feld].auf}“ (${feld}) liegt in einer Schutzzone. Mit „zoom“ auf diesen Ausschnitt rückt er in die freie Fläche.`);
      }
    }
  });
}

/** Browser für Remotion: vorgegeben, vorinstalliert oder (ohne beides) Remotions eigener Download. */
function browser() {
  const pfad = process.env.SHORTS_CHROMIUM || (fs.existsSync(VORINSTALLIERT) ? VORINSTALLIERT : undefined);
  return pfad ? { browserExecutable: pfad, chromeMode: 'chrome-for-testing' } : {};
}

function python() {
  if (process.env.SHORTS_PYTHON) return process.env.SHORTS_PYTHON;
  for (const name of ['.venv-omnivoice', '.venv-piper']) {
    const kandidat = path.join(HIER, 'tts', name, 'bin', 'python');
    if (fs.existsSync(kandidat)) return kandidat;
  }
  return 'python3';
}

/** Ordner mit allem, was die Komposition lädt: Schrift und Logo aus dem Repo, App-Bilder und Bildfolgen. */
function stelleBereit(ordner, bilder) {
  fs.rmSync(ordner, { recursive: true, force: true });
  fs.mkdirSync(path.join(ordner, 'fonts'), { recursive: true });
  fs.mkdirSync(path.join(ordner, 'frames'));
  for (const [gewicht, datei] of Object.entries(SCHRIFT_DATEIEN)) fs.copyFileSync(datei, path.join(ordner, 'fonts', `${gewicht}.ttf`));
  fs.copyFileSync(LOGO, path.join(ordner, 'logo.svg'));
  for (const [name, datei] of bilder) fs.copyFileSync(datei, path.join(ordner, 'frames', name));
}

async function rendereVideo({ id, sprache }, einstellungen) {
  const texte = TEXTE[sprache];
  if (!texte) throw new Abbruch(`Sprache „${sprache}“ kennt src/texte.mjs nicht`);
  const datei = path.join(HIER, 'videos', sprache, `${id}.yaml`);
  if (!fs.existsSync(datei)) throw new Abbruch(`Videobeschreibung ${path.relative(HIER, datei)} fehlt`);
  const bildPfad = (name) => path.join(HIER, 'frames', sprache, name);
  const beschreibung = pruefeBeschreibung(YAML.parse(fs.readFileSync(datei, 'utf8')), {
    id,
    bildVorhanden: (name) => fs.existsSync(bildPfad(name)),
    folge: (name) => liesFolge(path.join(HIER, 'frames', sprache), name),
    fps: einstellungen.fps ?? 30,
  });

  const aus = path.join(HIER, 'out', id);
  const stimmen = path.join(aus, 'stimme');
  console.log('Stimme …');
  try {
    execFileSync(python(), [path.join(HIER, 'tts', 'synth.py'), datei, '--aus', stimmen], { stdio: 'inherit' });
  } catch {
    throw new Abbruch('Sprachsynthese gescheitert (tts/synth.py, siehe Meldung oben). Python mit der Engine aus einstellungen.yaml und pyyaml über SHORTS_PYTHON angeben.');
  }
  const dauerJson = JSON.parse(fs.readFileSync(path.join(stimmen, 'dauer.json'), 'utf8'));
  const dauern = pruefeDauern(beschreibung, dauerJson, (name) => fs.existsSync(path.join(stimmen, name)));
  for (const d of dauern.values()) d.datei = path.join(stimmen, d.datei);
  const plan = berechneZeitplan(beschreibung, dauern, einstellungen);
  console.log(`Zeitplan: ${plan.szenen.length} Szenen, ${plan.frames} Bilder, ${plan.sekunden.toFixed(2)} s`);

  let musik;
  if (beschreibung.musik) {
    musik = path.join(HIER, 'musik', beschreibung.musik);
    if (!fs.existsSync(musik)) {
      console.warn(`Hinweis: Musik „${beschreibung.musik}“ liegt nicht in musik/, das Video entsteht ohne Musik.`);
      musik = undefined;
    }
  }
  console.log('Tonspur …');
  const ton = path.join(aus, 'ton.wav');
  await baueTonspur({
    saetze: plan.szenen.flatMap((s) => s.saetze),
    sekunden: plan.sekunden,
    musik,
    ziel: ton,
    roh: path.join(aus, 'ton-roh.wav'),
    lufs: einstellungen.lautheit_lufs,
    spitzeDb: einstellungen.spitze_db,
    musikDb: einstellungen.musik_db,
    tipps: einstellungen.tipp_ton === false ? [] : plan.tipps,
    tippDb: einstellungen.tipp_ton_db,
  });

  const bilder = new Map(beschreibung.szenen.filter((s) => s.art === 'app').map((s) => [s.quelle, bildPfad(s.quelle)]));
  const masse = Object.fromEntries([...bilder].map(([name, pfad]) => [name, name.endsWith('.mp4') ? videoMass(pfad) : pngMass(pfad)]));
  pruefeSchutzzonen(plan, masse);
  const publicDir = path.join(aus, 'public');
  stelleBereit(publicDir, bilder);
  console.log('Bild …');
  const serveUrl = await bundle({ entryPoint: path.join(HIER, 'src', 'index.jsx'), publicDir, outDir: path.join(aus, 'bundle') });
  const inputProps = {
    breite: einstellungen.breite ?? 1080,
    hoehe: einstellungen.hoehe ?? 1920,
    plan,
    marke: ladeMarke(),
    texte,
    bilder: masse,
  };
  const optionen = { serveUrl, inputProps, logLevel: 'error', ...browser() };
  const composition = await selectComposition({ ...optionen, id: 'video' });
  const stumm = path.join(aus, 'bild.mp4');
  let gemeldet = -1;
  await renderMedia({
    ...optionen,
    composition,
    codec: 'h264',
    pixelFormat: 'yuv420p',
    colorSpace: 'bt709',
    imageFormat: 'jpeg',
    jpegQuality: 95,
    crf: 18,
    muted: true,
    outputLocation: stumm,
    onProgress: ({ progress }) => {
      const zehntel = Math.floor(progress * 10);
      if (zehntel > gemeldet) {
        gemeldet = zehntel;
        console.log(`  ${zehntel * 10} %`);
      }
    },
  });

  const ziel = path.join(HIER, 'out', `${id}.mp4`);
  await verbinde(stumm, ton, ziel);
  const lautheit = await messeLautheit(ziel);
  console.log(`Fertig: ${path.relative(HIER, ziel)} (${plan.sekunden.toFixed(2)} s, ${lautheit.lufs} LUFS, Spitze ${lautheit.spitze} dBTP)`);
  if (Number.isFinite(lautheit.lufs) && Math.abs(lautheit.lufs - einstellungen.lautheit_lufs) > 0.5) {
    console.warn(`Hinweis: Lautheit weicht um mehr als 0,5 LU vom Ziel ${einstellungen.lautheit_lufs} LUFS ab.`);
  }
}

/** Platzhalterbild für das Probevideo nach frames/<sprache>/platzhalter.png. */
async function renderePlatzhalter({ sprache }) {
  const aus = path.join(HIER, 'out', 'platzhalter');
  stelleBereit(path.join(aus, 'public'), new Map());
  const serveUrl = await bundle({ entryPoint: path.join(HIER, 'src', 'index.jsx'), publicDir: path.join(aus, 'public'), outDir: path.join(aus, 'bundle') });
  const optionen = { serveUrl, inputProps: { marke: ladeMarke() }, logLevel: 'error', ...browser() };
  const composition = await selectComposition({ ...optionen, id: 'platzhalter' });
  const ziel = path.join(HIER, 'frames', sprache, 'platzhalter.png');
  fs.mkdirSync(path.dirname(ziel), { recursive: true });
  await renderStill({ ...optionen, composition, output: ziel, imageFormat: 'png' });
  console.log(`Fertig: ${path.relative(HIER, ziel)}`);
}

try {
  const args = argumente(process.argv.slice(2));
  const einstellungen = YAML.parse(fs.readFileSync(path.join(HIER, 'einstellungen.yaml'), 'utf8'));
  await (args.platzhalter ? renderePlatzhalter(args) : rendereVideo(args, einstellungen));
} catch (fehler) {
  if (fehler instanceof Abbruch || fehler instanceof BeschreibungsFehler) {
    console.error(`Fehler: ${fehler.message}`);
    process.exit(1);
  }
  throw fehler;
}
