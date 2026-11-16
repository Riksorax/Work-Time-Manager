// Bausteine der Videos. Wichtiger Text bleibt außerhalb der Schutzzonen (oben 250 px,
// unten 420 px); nur das App-Bild darf hineinragen. Szenen wechseln mit hartem Schnitt, neue
// Inhalte kommen mit einer kurzen Bewegung herein, nichts blendet aus.
import React from 'react';
import { AbsoluteFill, Easing, Freeze, Img, OffthreadVideo, interpolate, staticFile, useCurrentFrame } from 'remotion';
import { folgeBild } from '../lib/zeit.mjs';
import { FREI, KARTE, SCHILD, SCHUTZ_OBEN, SCHUTZ_UNTEN, aufLeinwand, bildHoehe, kamera, kartenRechteck, mische, schildLage, szenenKamera, wertSchrift } from './layout.mjs';

const fest = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' };
const weich = Easing.inOut(Easing.cubic);
const aus = Easing.out(Easing.cubic);
const federnd = Easing.out(Easing.back(1.5));
const verlauf = (farben, winkel = 135) => `linear-gradient(${winkel}deg, ${farben[0]}, ${farben[1]})`;

/** Kurze Bewegung beim Schnitt auf eine neue Szene. Die erste Szene steht ab dem ersten Bild (Vorschaubild). */
function useHerein(erste, bilder = 5) {
  const bild = useCurrentFrame();
  return erste ? 1 : interpolate(bild, [0, bilder], [0, 1], { ...fest, easing: aus });
}

/** Fläche zwischen den Schutzzonen, Inhalt mittig. */
const Mitte = ({ children, style }) => (
  <AbsoluteFill
    style={{ top: SCHUTZ_OBEN, bottom: SCHUTZ_UNTEN, height: 'auto', padding: '0 80px', alignItems: 'center', justifyContent: 'center', textAlign: 'center', ...style }}
  >
    {children}
  </AbsoluteFill>
);

const Marke = ({ farben }) => <div style={{ width: 160, height: 16, borderRadius: 8, background: verlauf(farben, 90), marginBottom: 56 }} />;

const grossSchrift = (text) => (text.length <= 28 ? 124 : text.length <= 48 ? 108 : 88);

/** Aufhänger-Karte: eine Frage oder ein Problem in großer Schrift, ohne App-Bild. */
export const Aufhaenger = ({ szene, erste, marke }) => {
  const herein = useHerein(erste, 8);
  return (
    <Mitte style={{ opacity: herein, transform: `scale(${1.06 - 0.06 * herein})` }}>
      <Marke farben={marke.akzent} />
      <div style={{ fontSize: grossSchrift(szene.text), fontWeight: 700, lineHeight: 1.14 }}>{szene.text}</div>
    </Mitte>
  );
};

/** Teaser-Karte „Kommt bald“: nur Schrift, keine Oberfläche einer Funktion, die es noch nicht gibt. */
export const Teaser = ({ szene, erste, marke, texte }) => {
  const bild = useCurrentFrame();
  const herein = useHerein(erste);
  const schild = interpolate(bild, [2, 12], [0, 1], { ...fest, easing: federnd });
  return (
    <Mitte style={{ opacity: herein }}>
      <div
        style={{ background: verlauf(marke.akzent), borderRadius: 999, padding: '18px 52px', fontSize: 54, fontWeight: 700, marginBottom: 64, transform: `scale(${schild})`, boxShadow: '0 16px 40px rgba(0,0,0,.3)' }}
      >
        {texte.kommtBald}
      </div>
      <div style={{ fontSize: grossSchrift(szene.text), fontWeight: 700, lineHeight: 1.14 }}>{szene.text}</div>
    </Mitte>
  );
};

/**
 * Schlusskarte: Logo auf weißem Träger, Name, Handlungsaufruf und Adresse. Logo und Knopf
 * kommen mit einer kurzen Bewegung herein, der Knopf zieht danach einmal die Aufmerksamkeit.
 */
export const Schlusskarte = ({ marke, texte }) => {
  const bild = useCurrentFrame();
  const t = (ab, dauer = 10, easing = aus) => interpolate(bild, [ab, ab + dauer], [0, 1], { ...fest, easing });
  const hoch = (ab) => ({ opacity: t(ab, 6), transform: `translateY(${(1 - t(ab)) * 60}px)` });
  const logo = t(0, 12, federnd);
  const knopf = t(8, 12, federnd);
  const puls = interpolate(bild, [34, 40, 48], [1, 1.06, 1], { ...fest, easing: weich });
  return (
    <Mitte>
      <div
        style={{ width: 400, height: 400, borderRadius: '50%', background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 24px 60px rgba(0,0,0,.35)', opacity: t(0, 4), transform: `scale(${0.5 + 0.5 * logo}) rotate(${(1 - logo) * -20}deg)` }}
      >
        <Img src={staticFile('logo.svg')} style={{ width: 364, height: 364 }} />
      </div>
      <div style={{ fontSize: 88, fontWeight: 700, marginTop: 52, ...hoch(4) }}>{marke.name}</div>
      <div
        style={{ background: '#fff', color: marke.grund[1], borderRadius: 999, padding: '30px 64px', fontSize: 60, fontWeight: 700, marginTop: 80, whiteSpace: 'nowrap', boxShadow: '0 16px 40px rgba(0,0,0,.3)', opacity: t(8, 4), transform: `scale(${(0.6 + 0.4 * knopf) * puls})` }}
      >
        {texte.schlussAufruf}
      </div>
      <div style={{ fontSize: 54, fontWeight: 400, marginTop: 52, ...hoch(14) }}>{texte.schlussAdresse}</div>
    </Mitte>
  );
};

const Stern = () => (
  <svg width="34" height="34" viewBox="0 0 24 24" style={{ marginRight: 12 }}>
    <path fill="#fff" d="M12 2l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.2 5.9 20.6l1.4-6.8L2.2 9.1l6.9-.8z" />
  </svg>
);

/** Tipp-Markierung: Punkt mit Ring, der sich einmal ausbreitet. Liegt im Bild und wandert mit der Kamera. */
const Tipp = ({ x, y, ab, farbe }) => {
  const t = useCurrentFrame() - ab + 4; // der Punkt erscheint kurz vor dem Tipp
  if (t < 0 || t > 26) return null;
  const punkt = interpolate(t, [0, 4, 16, 24], [0, 1, 1, 0], fest);
  const druck = interpolate(t, [2, 4, 8], [1.15, 0.8, 1], fest);
  const ring = interpolate(t, [4, 24], [0.7, 2.6], { ...fest, easing: aus });
  const kreis = { position: 'absolute', left: x - 60, top: y - 60, width: 120, height: 120, borderRadius: '50%' };
  return (
    <>
      <div style={{ ...kreis, border: `8px solid ${farbe}`, transform: `scale(${ring})`, opacity: interpolate(t, [4, 24], [0.9, 0], fest) }} />
      <div style={{ ...kreis, background: 'rgba(13,71,161,.35)', border: '6px solid #fff', boxShadow: '0 6px 22px rgba(0,0,0,.45)', transform: `scale(${druck})`, opacity: punkt }} />
    </>
  );
};

/**
 * Hervorhebung der Kernaussage: Die Quelle im App-Bild bekommt einen Rahmen, daraus wächst ein
 * großes Schild (kleine Zeile, sehr große Zahl) mit einer Spitze, die auf die Quelle zeigt.
 */
const Hervorhebung = ({ hervorhebung, quelle, lage, marke }) => {
  const t = useCurrentFrame() - hervorhebung.abBild;
  if (t < -8) return null;
  const rahmen = interpolate(t, [-8, -2], [0, 1], { ...fest, easing: aus });
  const wachsen = interpolate(t, [0, 11], [0, 1], { ...fest, easing: federnd });
  const farbe = marke.akzent[0];
  const luft = 14;
  const spitze = SCHILD.abstand - luft - 4;
  const ursprungY = lage.unter ? -SCHILD.abstand : lage.hoehe + SCHILD.abstand;
  return (
    <>
      <div
        style={{ position: 'absolute', left: quelle.x - luft, top: quelle.y - luft, width: quelle.breite + 2 * luft, height: quelle.hoehe + 2 * luft, borderRadius: 22, border: `7px solid ${farbe}`, boxSizing: 'border-box', boxShadow: '0 0 0 3px rgba(255,255,255,.9), 0 8px 26px rgba(0,0,0,.25)', opacity: rahmen, transform: `scale(${1.25 - 0.25 * rahmen})` }}
      />
      <div
        style={{ position: 'absolute', left: lage.x, top: lage.y, width: lage.breite, height: lage.hoehe, transformOrigin: `${lage.spitzeX - lage.x}px ${ursprungY}px`, transform: `scale(${wachsen})`, opacity: interpolate(t, [0, 3], [0, 1], fest) }}
      >
        <div
          style={{ position: 'absolute', left: lage.spitzeX - lage.x - 34, width: 0, height: 0, borderLeft: '34px solid transparent', borderRight: '34px solid transparent', ...(lage.unter ? { top: -spitze, borderBottom: `${spitze + 2}px solid ${farbe}` } : { bottom: -spitze, borderTop: `${spitze + 2}px solid ${farbe}` }) }}
        />
        <div
          style={{ position: 'absolute', inset: 0, boxSizing: 'border-box', borderRadius: 48, border: `7px solid ${farbe}`, background: verlauf(marke.grund, 160), boxShadow: '0 30px 80px rgba(0,0,0,.5)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', whiteSpace: 'nowrap' }}
        >
          {hervorhebung.zeile && <div style={{ fontSize: SCHILD.zeile, fontWeight: 700, lineHeight: 1.25, opacity: 0.92 }}>{hervorhebung.zeile}</div>}
          <div style={{ fontSize: wertSchrift(hervorhebung.wert), fontWeight: 700, lineHeight: 1.12 }}>{hervorhebung.wert}</div>
        </div>
      </div>
    </>
  );
};

/**
 * Szene mit App-Bild oder Bildfolge: große Karte auf Markengrund, Kamerafahrt auf den benannten
 * Ausschnitt, optional Aufhänger über dem Bild, Tipp-Markierung, Hervorhebung, Texteinblendung
 * und Premium-Kennzeichen. Setzt die Szene die Quelle der Szene davor fort, gibt es keinen
 * Übergang: Die Kamera fährt von deren Lage weiter.
 */
export const AppSzene = ({ szene, vorher, erste, marke, texte, bilder }) => {
  const bild = useCurrentFrame();
  const mass = bilder[szene.quelle];
  const ziel = szenenKamera(szene, mass);
  const start = szene.fortsetzung ? szenenKamera(vorher, mass) : kamera(mass, undefined, 1, ziel.oben);
  const lage = mische(start, ziel, interpolate(bild, [0, szene.zoomBilder], [0, 1], { ...fest, easing: weich }));
  const karte = kartenRechteck(lage, mass);
  const hoehe = bildHoehe(mass);
  const herein = useHerein(erste || szene.fortsetzung);
  const text = interpolate(bild, [2, 10], [0, 1], { ...fest, easing: aus });

  const ende = szene.aufhaenger ? Math.min(szene.frames, szene.aufhaengerBis + 3) : 0;
  const frage = szene.aufhaenger ? interpolate(bild, [ende - 6, ende], [1, 0], fest) : 0;
  const frageHerein = erste ? 1 : interpolate(bild, [0, 8], [0, 1], { ...fest, easing: aus });
  const mitte = (r) => ({ x: (r.x + r.breite / 2) * KARTE.breite, y: (r.y + r.hoehe / 2) * hoehe });
  const tipp = szene.tipp && mitte(szene.tipp.rechteck);

  return (
    <AbsoluteFill>
      {szene.einblendung && (
        <div
          style={{ position: 'absolute', top: SCHUTZ_OBEN + 10, left: 70, right: 70, height: KARTE.obenMitEinblendung - SCHUTZ_OBEN - 40, display: 'flex', alignItems: 'center', justifyContent: 'center', textAlign: 'center', fontSize: 60, fontWeight: 700, lineHeight: 1.15, opacity: text, transform: `translateY(${(1 - text) * -24}px)` }}
        >
          {szene.einblendung}
        </div>
      )}
      <div
        style={{ position: 'absolute', left: karte.x, top: karte.y, width: karte.breite, height: karte.hoehe, borderRadius: KARTE.radius, overflow: 'hidden', background: '#fff', boxShadow: '0 30px 80px rgba(0,0,0,.45)', opacity: herein, transform: `scale(${0.96 + 0.04 * herein})` }}
      >
        <div
          style={{ position: 'absolute', left: lage.x - karte.x, top: lage.y - karte.y, width: KARTE.breite, height: hoehe, transformOrigin: '0 0', transform: `scale(${lage.skala})`, filter: frage > 0 ? `blur(${6 * frage}px)` : undefined }}
        >
          {szene.folge ? (
            <Freeze frame={folgeBild(szene, bild)}>
              <OffthreadVideo src={staticFile(`frames/${szene.quelle}`)} muted style={{ width: '100%', height: '100%', display: 'block' }} />
            </Freeze>
          ) : (
            <Img src={staticFile(`frames/${szene.quelle}`)} style={{ width: '100%', height: '100%', display: 'block' }} />
          )}
          {tipp && <Tipp x={tipp.x} y={tipp.y} ab={szene.tippBild} farbe={marke.akzent[0]} />}
        </div>
        {frage > 0 && <AbsoluteFill style={{ background: marke.grund[1], opacity: 0.8 * frage }} />}
      </div>
      {frage > 0 && (
        <Mitte style={{ opacity: frage * frageHerein, transform: `scale(${1.05 - 0.05 * frageHerein})` }}>
          <Marke farben={marke.akzent} />
          <div style={{ fontSize: grossSchrift(szene.aufhaenger), fontWeight: 700, lineHeight: 1.14, textShadow: '0 4px 24px rgba(0,0,0,.45)' }}>{szene.aufhaenger}</div>
        </Mitte>
      )}
      {szene.hervorhebung && (
        <Hervorhebung
          hervorhebung={szene.hervorhebung}
          quelle={aufLeinwand(lage, mass, szene.hervorhebung.rechteck)}
          lage={schildLage(aufLeinwand(ziel, mass, szene.hervorhebung.rechteck), szene.hervorhebung.wert)}
          marke={marke}
        />
      )}
      {szene.premium && (
        <div
          style={{ position: 'absolute', right: KARTE.links - 14, top: Math.max(karte.y - 14, FREI.oben + 10), height: 76, padding: '0 34px 0 26px', borderRadius: 38, display: 'flex', alignItems: 'center', background: verlauf(marke.akzent), fontSize: 42, fontWeight: 700, boxShadow: '0 10px 28px rgba(0,0,0,.35)', opacity: text, transform: `scale(${0.8 + 0.2 * text})` }}
        >
          <Stern />
          {texte.premium}
        </div>
      )}
    </AbsoluteFill>
  );
};
