// Bausteine der Videos. Wichtiger Text bleibt außerhalb der Schutzzonen (oben 250 px,
// unten 420 px); nur das App-Bild darf hineinragen.
import React from 'react';
import { AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from 'remotion';
import { KARTE, SCHUTZ_OBEN, SCHUTZ_UNTEN, UNTERTITEL, bildLage } from './layout.mjs';

const fest = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' };
const weich = Easing.inOut(Easing.cubic);
const verlauf = (farben, winkel = 135) => `linear-gradient(${winkel}deg, ${farben[0]}, ${farben[1]})`;

/** Deckkraft einer Szene: weich ein und aus. Die erste Szene steht ab dem ersten Bild (Vorschaubild). */
function useBlende(erste, letzte = false) {
  const bild = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const ein = erste ? 1 : interpolate(bild, [0, 8], [0, 1], fest);
  const aus = letzte ? 1 : interpolate(bild, [durationInFrames - 6, durationInFrames], [1, 0], fest);
  return Math.min(ein, aus);
}

/** Fläche zwischen den Schutzzonen, Inhalt mittig. */
const Mitte = ({ children, style }) => (
  <AbsoluteFill
    style={{ top: SCHUTZ_OBEN, bottom: SCHUTZ_UNTEN, height: 'auto', padding: '0 90px', alignItems: 'center', justifyContent: 'center', textAlign: 'center', ...style }}
  >
    {children}
  </AbsoluteFill>
);

const Marke = ({ farben, breit = false }) => (
  <div style={{ width: breit ? 220 : 140, height: 14, borderRadius: 7, background: verlauf(farben, 90), marginBottom: 56 }} />
);

const grossSchrift = (text) => (text.length <= 28 ? 112 : text.length <= 48 ? 96 : 80);

/** Aufhänger-Karte: eine Frage oder ein Problem in großer Schrift. */
export const Aufhaenger = ({ szene, erste, marke }) => {
  const bild = useCurrentFrame();
  const skala = interpolate(bild, [0, 12], [1.05, 1], { ...fest, easing: Easing.out(Easing.cubic) });
  return (
    <Mitte style={{ opacity: useBlende(erste), transform: `scale(${skala})` }}>
      <Marke farben={marke.akzent} />
      <div style={{ fontSize: grossSchrift(szene.text), fontWeight: 700, lineHeight: 1.14 }}>{szene.text}</div>
    </Mitte>
  );
};

/** Teaser-Karte „Kommt bald“: nur Schrift, keine Oberfläche einer Funktion, die es noch nicht gibt. */
export const Teaser = ({ szene, erste, marke, texte }) => {
  const bild = useCurrentFrame();
  const schild = interpolate(bild, [4, 14], [0, 1], { ...fest, easing: Easing.out(Easing.back(1.6)) });
  return (
    <Mitte style={{ opacity: useBlende(erste) }}>
      <div
        style={{ background: verlauf(marke.akzent), borderRadius: 999, padding: '18px 52px', fontSize: 54, fontWeight: 700, marginBottom: 64, transform: `scale(${schild})`, boxShadow: '0 16px 40px rgba(0,0,0,.3)' }}
      >
        {texte.kommtBald}
      </div>
      <div style={{ fontSize: grossSchrift(szene.text), fontWeight: 700, lineHeight: 1.14 }}>{szene.text}</div>
    </Mitte>
  );
};

/** Schlusskarte: Logo, Name, Handlungsaufruf und Adresse. */
export const Schlusskarte = ({ erste, marke, texte }) => {
  const bild = useCurrentFrame();
  const stufe = (ab) => {
    const t = interpolate(bild, [ab, ab + 10], [0, 1], { ...fest, easing: Easing.out(Easing.cubic) });
    return { opacity: t, transform: `translateY(${(1 - t) * 30}px)` };
  };
  return (
    <Mitte style={{ opacity: useBlende(erste, true) }}>
      <Img src={staticFile('logo.svg')} style={{ width: 320, height: 320, ...stufe(0) }} />
      <div style={{ fontSize: 76, fontWeight: 700, marginTop: 44, ...stufe(4) }}>{marke.name}</div>
      <div
        style={{ background: '#fff', color: marke.grund[0], borderRadius: 999, padding: '26px 60px', fontSize: 54, fontWeight: 700, marginTop: 84, boxShadow: '0 16px 40px rgba(0,0,0,.3)', ...stufe(10) }}
      >
        {texte.schlussAufruf}
      </div>
      <div style={{ fontSize: 50, fontWeight: 400, marginTop: 48, ...stufe(14) }}>{texte.schlussAdresse}</div>
    </Mitte>
  );
};

const Stern = () => (
  <svg width="34" height="34" viewBox="0 0 24 24" style={{ marginRight: 12 }}>
    <path fill="#fff" d="M12 2l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.2 5.9 20.6l1.4-6.8L2.2 9.1l6.9-.8z" />
  </svg>
);

/** Tipp-Markierung: Punkt mit Ring, der sich einmal ausbreitet. Liegt im Bild und wandert beim Zoom mit. */
const Tipp = ({ x, y, ab }) => {
  const t = useCurrentFrame() - ab;
  if (t < 0 || t > 26) return null;
  const punkt = interpolate(t, [0, 5, 20, 26], [0, 1, 1, 0], fest);
  const ring = interpolate(t, [3, 24], [0.6, 2.4], fest);
  const kreis = { position: 'absolute', left: x - 55, top: y - 55, width: 110, height: 110, borderRadius: '50%' };
  return (
    <>
      <div style={{ ...kreis, border: '6px solid #fff', boxShadow: '0 0 0 2px rgba(0,0,0,.25)', transform: `scale(${ring})`, opacity: interpolate(t, [3, 24], [0.9, 0], fest) }} />
      <div style={{ ...kreis, background: 'rgba(255,255,255,.55)', border: '4px solid #fff', boxShadow: '0 4px 18px rgba(0,0,0,.4)', transform: `scale(${0.6 + 0.4 * punkt})`, opacity: punkt }} />
    </>
  );
};

/**
 * Szene mit App-Bild: Karte mit runden Ecken und Schatten auf Markengrund, langsamer Zoom auf
 * den benannten Ausschnitt, optional Tipp-Markierung, Texteinblendung und Premium-Kennzeichen.
 */
export const AppSzene = ({ szene, erste, marke, texte, ausschnitte, bilder }) => {
  const bild = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const oben = szene.einblendung ? KARTE.obenMitEinblendung : KARTE.oben;
  const kartenHoehe = KARTE.unten - oben;
  // Frei bleibt die Karte bis zur Oberkante eines zweizeiligen Untertitels.
  const freiHoehe = 1920 - UNTERTITEL.unten - 2 * UNTERTITEL.zeilenhoehe - 60 - oben;
  const fortschritt = interpolate(bild, [10, Math.max(11, durationInFrames - 8)], [0, 1], { ...fest, easing: weich });
  const lage = bildLage(bilder[szene.bild], ausschnitte[szene.zoom?.auf], szene.zoom?.faktor ?? 1, fortschritt, kartenHoehe, freiHoehe);
  const herein = interpolate(bild, [0, 12], [0, 1], { ...fest, easing: Easing.out(Easing.cubic) });
  const tipp = szene.tipp && ausschnitte[szene.tipp.auf];
  const text = interpolate(bild, [6, 16], [0, 1], { ...fest, easing: Easing.out(Easing.cubic) });

  return (
    <AbsoluteFill style={{ opacity: useBlende(erste) }}>
      {szene.einblendung && (
        <div
          style={{ position: 'absolute', top: SCHUTZ_OBEN + 10, left: 80, right: 80, height: KARTE.obenMitEinblendung - SCHUTZ_OBEN - 50, display: 'flex', alignItems: 'center', justifyContent: 'center', textAlign: 'center', fontSize: 56, fontWeight: 700, lineHeight: 1.15, opacity: text, transform: `translateY(${(1 - text) * -20}px)` }}
        >
          {szene.einblendung}
        </div>
      )}
      <div
        style={{ position: 'absolute', left: KARTE.links, top: oben, width: KARTE.breite, height: kartenHoehe, borderRadius: KARTE.radius, overflow: 'hidden', background: '#fff', boxShadow: '0 30px 80px rgba(0,0,0,.45)', opacity: erste ? 1 : herein, transform: `translateY(${(1 - herein) * 40}px)` }}
      >
        <div
          style={{ position: 'absolute', left: 0, top: 0, width: KARTE.breite, height: lage.bildHoehe, transformOrigin: '0 0', transform: `translate(${lage.x}px, ${lage.y}px) scale(${lage.skala})` }}
        >
          <Img src={staticFile(`frames/${szene.bild}`)} style={{ width: '100%', height: '100%', display: 'block' }} />
          {tipp && (
            <Tipp x={(tipp.x + tipp.breite / 2) * KARTE.breite} y={(tipp.y + tipp.hoehe / 2) * lage.bildHoehe} ab={Math.round(szene.tipp.bei * durationInFrames)} />
          )}
        </div>
      </div>
      {szene.premium && (
        <div
          style={{ position: 'absolute', right: KARTE.links - 22, top: oben - 14, height: 68, padding: '0 30px 0 24px', borderRadius: 34, display: 'flex', alignItems: 'center', background: verlauf(marke.akzent), fontSize: 38, fontWeight: 700, boxShadow: '0 10px 28px rgba(0,0,0,.35)', opacity: herein, transform: `scale(${0.8 + 0.2 * herein})` }}
        >
          <Stern />
          {texte.premium}
        </div>
      )}
    </AbsoluteFill>
  );
};

/** Untertitel: Originaltext des Satzes, höchstens zwei Zeilen, Unterkante an der unteren Schutzzone. */
export const Untertitel = ({ zeilen }) => (
  <AbsoluteFill style={{ top: 'auto', bottom: UNTERTITEL.unten, height: 'auto', alignItems: 'center' }}>
    <div
      style={{ background: 'rgba(0,0,0,.8)', borderRadius: 24, padding: '14px 34px', fontSize: UNTERTITEL.schrift, fontWeight: 700, lineHeight: `${UNTERTITEL.zeilenhoehe}px`, textAlign: 'center', whiteSpace: 'nowrap' }}
    >
      {zeilen.map((zeile, i) => (
        <div key={i}>{zeile}</div>
      ))}
    </div>
  </AbsoluteFill>
);
