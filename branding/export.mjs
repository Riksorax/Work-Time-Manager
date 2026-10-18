#!/usr/bin/env node
// Erzeugt alle Branding-Assets aus branding/src/*.svg.
//   npm run export   schreibt die Dateien in mobile/, web/public/ und store/
//   npm run check    erzeugt neu und vergleicht mit dem Repo (Drift-Check, Exit 1 bei Abweichung)
import { checkAll, exportAll, PIXEL_TOLERANCE } from './lib/build.mjs';
import { TARGETS } from './lib/targets.mjs';

const args = process.argv.slice(2);
const known = new Set(['--check']);
const unknown = args.filter((a) => !known.has(a));
if (unknown.length > 0) {
  console.error(`Unbekannte Argumente: ${unknown.join(' ')}\nAufruf: node export.mjs [--check]`);
  process.exit(2);
}

if (args.includes('--check')) {
  const findings = checkAll();
  if (findings.length > 0) {
    console.error(`Branding-Drift in ${findings.length} von ${TARGETS.length} Dateien:`);
    for (const f of findings) console.error(`  - ${f}`);
    console.error('\nBehebung: im Ordner branding/ "npm run export" ausführen und die Dateien committen.');
    process.exit(1);
  }
  console.log(`Branding aktuell: ${TARGETS.length} Dateien (Pixeltoleranz ${PIXEL_TOLERANCE}).`);
} else {
  exportAll({ log: (line) => console.log(line) });
  console.log(`${TARGETS.length} Dateien erzeugt.`);
}
